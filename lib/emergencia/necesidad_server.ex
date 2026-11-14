defmodule Emergencia.NecesidadServer do
  @moduledoc """
  Proceso (GenServer) que mantiene en memoria las necesidades puntuales.

  Responsabilidades:
    * Generar identificadores únicos (N001, N002...). Al ser un único proceso
      quien los genera, dos solicitudes simultáneas nunca reciben el mismo id.
    * Guardar las necesidades y responder consultas (con filtros y prioridad).
    * Coordinar con Emergencia.RecursoServer la asignación de recursos.

  Las reglas (validaciones, estados, transiciones) viven en Emergencia.Necesidad.
  """
  use GenServer
  require Logger

  alias Emergencia.{Necesidad, Persistencia, RecursoServer}

  @ruta_defecto "data/necesidades.txt"

  # ------------------------------------------------------------------
  # API pública (se ejecuta en el proceso que llama)
  # ------------------------------------------------------------------

  @doc """
  Inicia el servidor.

  Opciones:
    * `:name`           - nombre registrado (por defecto, el nombre del módulo).
    * `:ruta`           - archivo de persistencia (por defecto "data/necesidades.txt").
                          Con `ruta: nil` no se guarda en disco.
    * `:recurso_server` - servidor de recursos con el que coordina
                          (por defecto Emergencia.RecursoServer).
  """
  def start_link(opts \\ []) do
    {ruta, opts} = Keyword.pop(opts, :ruta, @ruta_defecto)
    {recurso_server, opts} = Keyword.pop(opts, :recurso_server, RecursoServer)
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, {ruta, recurso_server}, opts)
  end

  @doc "Registra una necesidad. El servidor le asigna el id."
  def registrar(servidor, tipo, cantidad, prioridad, zona, descripcion, responsable) do
    GenServer.call(servidor, {:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable})
  end

  @doc "Devuelve {:ok, necesidad} o {:error, :necesidad_no_encontrada}."
  def obtener(servidor, id), do: GenServer.call(servidor, {:obtener, id})

  @doc """
  Lista necesidades ordenadas por prioridad (la más urgente primero).
  Filtros opcionales: `zona:`, `tipo:`, `prioridad:` y `estado:`.
  Ejemplo: `listar(servidor, zona: "centro", prioridad: "critica")`.
  """
  def listar(servidor, filtros \\ []), do: GenServer.call(servidor, {:listar, filtros})

  @doc "Necesidades pendientes, de la más urgente a la menos urgente."
  def pendientes(servidor), do: listar(servidor, estado: :pendiente)

  @doc """
  Asigna `cantidad` del recurso `codigo_recurso` a la necesidad `id`.
  Descuenta el inventario en el RecursoServer y registra la asignación.
  """
  def asignar_recurso(servidor, id, codigo_recurso, cantidad) do
    GenServer.call(servidor, {:asignar_recurso, id, codigo_recurso, cantidad})
  end

  @doc """
  Cambia el estado (:en_atencion, :atendida, :cancelada) si la transición es
  válida. Al cancelar, los recursos asignados se devuelven al inventario.
  """
  def cambiar_estado(servidor, id, nuevo_estado) do
    GenServer.call(servidor, {:cambiar_estado, id, nuevo_estado})
  end

  # ------------------------------------------------------------------
  # Callbacks (se ejecutan DENTRO del proceso del servidor)
  # ------------------------------------------------------------------

  @impl true
  def init({ruta, recurso_server}) do
    %{necesidades: necesidades, contador: contador} = cargar(ruta)

    {:ok,
     %{
       necesidades: necesidades,
       contador: contador,
       ruta: ruta,
       recurso_server: recurso_server
     }}
  end

  @impl true
  def handle_call({:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable}, _from, estado) do
    id = generar_id(estado.contador + 1)

    case Necesidad.nueva(id, tipo, descripcion, cantidad, zona, prioridad, responsable) do
      {:ok, necesidad} ->
        nuevo_estado = %{
          estado
          | necesidades: Map.put(estado.necesidades, id, necesidad),
            contador: estado.contador + 1
        }

        persistir(nuevo_estado)
        {:reply, {:ok, necesidad}, nuevo_estado}

      {:error, _motivo} = error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:obtener, id}, _from, estado) do
    {:reply, buscar(estado, id), estado}
  end

  def handle_call({:listar, filtros}, _from, estado) do
    necesidades =
      estado.necesidades
      |> Map.values()
      |> filtrar(filtros)
      |> Necesidad.ordenar_por_prioridad()

    {:reply, necesidades, estado}
  end

  def handle_call({:asignar_recurso, id, codigo_recurso, cantidad}, _from, estado) do
    # Orden deliberado:
    #   1) Necesidad.asignar/3 valida la regla de la necesidad SIN tocar nada
    #      (estado, cantidad pedida). Si falla, no se descuenta inventario.
    #   2) RecursoServer.salida/4 descuenta de forma atómica. Si no alcanza,
    #      devuelve error y la necesidad no cambia.
    #   3) Solo si ambos pasos salieron bien se guarda la asignación.
    # Mientras este handle_call corre, el servidor no atiende otros mensajes,
    # así que nadie más puede modificar esta necesidad a la mitad del proceso.
    with {:ok, necesidad} <- buscar(estado, id),
         {:ok, actualizada} <- Necesidad.asignar(necesidad, codigo_recurso, cantidad),
         {:ok, _recurso} <-
           RecursoServer.salida(estado.recurso_server, codigo_recurso, cantidad, "necesidad #{id}") do
      {:reply, {:ok, actualizada}, guardar_necesidad(estado, actualizada)}
    else
      {:error, _motivo} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:cambiar_estado, id, nuevo_estado}, _from, estado) do
    with {:ok, necesidad} <- buscar(estado, id),
         {:ok, actualizada} <- Necesidad.cambiar_estado(necesidad, nuevo_estado) do
      if nuevo_estado == :cancelada, do: devolver_recursos(estado, actualizada)
      {:reply, {:ok, actualizada}, guardar_necesidad(estado, actualizada)}
    else
      {:error, _motivo} = error -> {:reply, error, estado}
    end
  end

  # ------------------------------------------------------------------
  # Funciones privadas
  # ------------------------------------------------------------------

  defp generar_id(numero) do
    "N" <> String.pad_leading(Integer.to_string(numero), 3, "0")
  end

  defp buscar(estado, id) do
    case Map.fetch(estado.necesidades, id) do
      {:ok, necesidad} -> {:ok, necesidad}
      :error -> {:error, :necesidad_no_encontrada}
    end
  end

  # Al cancelar, cada asignación vuelve al inventario como una entrada.
  # Solo se llega aquí una vez: después de cancelada, la necesidad queda
  # cerrada y Necesidad.cambiar_estado/2 rechaza cualquier otro cambio.
  defp devolver_recursos(estado, necesidad) do
    Enum.each(necesidad.asignaciones, fn %{recurso: codigo, cantidad: cantidad} ->
      RecursoServer.entrada(
        estado.recurso_server,
        codigo,
        cantidad,
        "devolución por cancelación de #{necesidad.id}"
      )
    end)
  end

  defp filtrar(necesidades, filtros) do
    Enum.filter(necesidades, fn necesidad ->
      Enum.all?(filtros, fn {campo, valor} ->
        normalizar(Map.get(necesidad, campo)) == normalizar(valor)
      end)
    end)
  end

  # Compara como texto para aceptar tanto :critica como "critica"
  # sin crear átomos a partir de lo que escribe el usuario.
  defp normalizar(valor), do: valor |> to_string() |> String.trim() |> String.downcase()

  defp guardar_necesidad(estado, necesidad) do
    nuevo_estado = %{estado | necesidades: Map.put(estado.necesidades, necesidad.id, necesidad)}
    persistir(nuevo_estado)
    nuevo_estado
  end

  defp persistir(%{ruta: nil}), do: :ok

  defp persistir(%{ruta: ruta, necesidades: necesidades, contador: contador}) do
    case Persistencia.guardar(ruta, %{necesidades: necesidades, contador: contador}) do
      :ok -> :ok
      {:error, motivo} -> Logger.warning("No se pudo guardar #{ruta}: #{inspect(motivo)}")
    end
  end

  defp cargar(nil), do: %{necesidades: %{}, contador: 0}

  defp cargar(ruta) do
    case Persistencia.cargar(ruta) do
      {:ok, %{necesidades: %{}, contador: contador} = datos} when is_integer(contador) ->
        datos

      {:error, :enoent} ->
        %{necesidades: %{}, contador: 0}

      {:error, motivo} ->
        Logger.warning("No se pudo cargar #{ruta}: #{inspect(motivo)}")
        %{necesidades: %{}, contador: 0}

      _otro ->
        Logger.warning("Formato inesperado en #{ruta}, se inicia vacío")
        %{necesidades: %{}, contador: 0}
    end
  end
end
