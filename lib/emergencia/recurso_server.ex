defmodule Emergencia.RecursoServer do
  @moduledoc """
  Proceso (GenServer) que mantiene en memoria el inventario de recursos.

  Un GenServer atiende UN mensaje a la vez. Por eso, cuando dos solicitudes
  intentan sacar las últimas unidades de un recurso, la primera se procesa
  completa (verificar + descontar) antes de que empiece la segunda. Así la
  cantidad entregada nunca supera el inventario real.

  Las reglas del negocio (validaciones, historial) viven en Emergencia.Recurso;
  este módulo solo guarda el estado, serializa las solicitudes y persiste.
  """
  use GenServer
  require Logger

  alias Emergencia.{Persistencia, Recurso}

  @ruta_defecto "data/recursos.txt"

  # ------------------------------------------------------------------
  # API pública (se ejecuta en el proceso que llama)
  # ------------------------------------------------------------------

  @doc """
  Inicia el servidor.

  Opciones:
    * `:name`  - nombre registrado (por defecto, el nombre del módulo).
    * `:ruta`  - archivo de persistencia (por defecto "data/recursos.txt").
                 Con `ruta: nil` no se guarda nada en disco (útil en pruebas).
  """
  def start_link(opts \\ []) do
    {ruta, opts} = Keyword.pop(opts, :ruta, @ruta_defecto)
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, ruta, opts)
  end

  @doc "Registra un recurso nuevo. El código no puede repetirse."
  def registrar(servidor, codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    GenServer.call(servidor, {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion})
  end

  @doc "Devuelve {:ok, recurso} o {:error, :recurso_no_encontrado}."
  def obtener(servidor, codigo), do: GenServer.call(servidor, {:obtener, codigo})

  @doc """
  Lista recursos. Filtros opcionales: `categoria:` y `ubicacion:`.
  Ejemplo: `listar(servidor, categoria: "agua")`.
  """
  def listar(servidor, filtros \\ []), do: GenServer.call(servidor, {:listar, filtros})

  @doc "Suma unidades al inventario de un recurso."
  def entrada(servidor, codigo, cantidad, motivo) do
    GenServer.call(servidor, {:entrada, codigo, cantidad, motivo})
  end

  @doc """
  Resta unidades del inventario. Es la operación crítica de concurrencia:
  devuelve {:error, :inventario_insuficiente} si no alcanza.
  """
  def salida(servidor, codigo, cantidad, motivo) do
    GenServer.call(servidor, {:salida, codigo, cantidad, motivo})
  end

  @doc """
  Transfiere `cantidad` del recurso `codigo` desde el centro `origen`
  hacia el centro `destino`.
  """
  def transferir(servidor, codigo, origen, destino, cantidad) do
    GenServer.call(servidor, {:transferir, codigo, origen, destino, cantidad})
  end

  # ------------------------------------------------------------------
  # Callbacks (se ejecutan DENTRO del proceso del servidor)
  # ------------------------------------------------------------------

  @impl true
  def init(ruta) do
    {:ok, %{recursos: cargar(ruta), ruta: ruta}}
  end

  @impl true
  def handle_call({:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion}, _from, estado) do
    with {:ok, recurso} <- Recurso.nuevo(codigo, nombre, categoria, cantidad, unidad, ubicacion),
         :ok <- verificar_codigo_libre(estado, recurso.codigo) do
      {:reply, {:ok, recurso}, guardar_recurso(estado, recurso)}
    else
      {:error, _motivo} = error -> {:reply, error, estado}
    end
  end

  def handle_call({:obtener, codigo}, _from, estado) do
    {:reply, buscar(estado, codigo), estado}
  end

  def handle_call({:listar, filtros}, _from, estado) do
    recursos =
      estado.recursos
      |> Map.values()
      |> filtrar(filtros)
      |> Enum.sort_by(& &1.codigo)

    {:reply, recursos, estado}
  end

  def handle_call({:entrada, codigo, cantidad, motivo}, _from, estado) do
    modificar(estado, codigo, &Recurso.entrada(&1, cantidad, motivo))
  end

  def handle_call({:salida, codigo, cantidad, motivo}, _from, estado) do
    modificar(estado, codigo, &Recurso.salida(&1, cantidad, motivo))
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad}, _from, estado) do
    # Todo el "with" trabaja sobre copias inmutables: si cualquier paso falla,
    # el estado real no se toca (la transferencia es todo o nada).
    with {:ok, recurso_origen} <- buscar(estado, codigo),
         :ok <- verificar_origen(recurso_origen, origen, destino),
         {:ok, origen_actualizado} <-
           Recurso.salida(recurso_origen, cantidad, "transferencia a #{destino}"),
         {:ok, destino_actualizado} <- recibir(estado, recurso_origen, destino, cantidad) do
      nuevo_estado =
        estado
        |> guardar_recurso(origen_actualizado)
        |> guardar_recurso(destino_actualizado)

      {:reply, {:ok, %{origen: origen_actualizado, destino: destino_actualizado}}, nuevo_estado}
    else
      {:error, _motivo} = error -> {:reply, error, estado}
    end
  end

  # ------------------------------------------------------------------
  # Funciones privadas
  # ------------------------------------------------------------------

  # Aplica una operación pura de Recurso a un recurso existente.
  defp modificar(estado, codigo, operacion) do
    with {:ok, recurso} <- buscar(estado, codigo),
         {:ok, actualizado} <- operacion.(recurso) do
      {:reply, {:ok, actualizado}, guardar_recurso(estado, actualizado)}
    else
      {:error, _motivo} = error -> {:reply, error, estado}
    end
  end

  defp buscar(estado, codigo) do
    case Map.fetch(estado.recursos, codigo) do
      {:ok, recurso} -> {:ok, recurso}
      :error -> {:error, :recurso_no_encontrado}
    end
  end

  defp verificar_codigo_libre(estado, codigo) do
    if Map.has_key?(estado.recursos, codigo), do: {:error, :codigo_duplicado}, else: :ok
  end

  defp verificar_origen(%Recurso{ubicacion: ubicacion}, origen, destino) do
    cond do
      ubicacion != origen -> {:error, :origen_incorrecto}
      origen == destino -> {:error, :mismo_centro}
      true -> :ok
    end
  end

  # Busca en el destino un recurso equivalente (mismo nombre, categoría y
  # unidad) y le suma la cantidad; si no existe, lo crea con código
  # "<codigo>@<destino>".
  defp recibir(estado, base, destino, cantidad) do
    equivalente =
      estado.recursos
      |> Map.values()
      |> Enum.find(fn r ->
        r.ubicacion == destino and r.categoria == base.categoria and
          r.nombre == base.nombre and r.unidad == base.unidad
      end)

    case equivalente do
      nil ->
        codigo = "#{base.codigo}@#{destino}"

        with :ok <- verificar_codigo_libre(estado, codigo) do
          Recurso.nuevo(codigo, base.nombre, base.categoria, cantidad, base.unidad, destino)
        end

      existente ->
        Recurso.entrada(existente, cantidad, "transferencia desde #{base.ubicacion}")
    end
  end

  defp filtrar(recursos, filtros) do
    Enum.filter(recursos, fn recurso ->
      Enum.all?(filtros, fn {campo, valor} ->
        normalizar(Map.get(recurso, campo)) == normalizar(valor)
      end)
    end)
  end

  defp normalizar(valor), do: valor |> to_string() |> String.trim() |> String.downcase()

  # Actualiza el estado en memoria y guarda en disco.
  defp guardar_recurso(estado, recurso) do
    nuevo_estado = %{estado | recursos: Map.put(estado.recursos, recurso.codigo, recurso)}
    persistir(nuevo_estado)
    nuevo_estado
  end

  defp persistir(%{ruta: nil}), do: :ok

  defp persistir(%{ruta: ruta, recursos: recursos}) do
    case Persistencia.guardar(ruta, recursos) do
      :ok -> :ok
      {:error, motivo} -> Logger.warning("No se pudo guardar #{ruta}: #{inspect(motivo)}")
    end
  end

  defp cargar(nil), do: %{}

  defp cargar(ruta) do
    case Persistencia.cargar(ruta) do
      {:ok, %{} = recursos} ->
        recursos

      {:error, :enoent} ->
        %{}

      {:error, motivo} ->
        Logger.warning("No se pudo cargar #{ruta}: #{inspect(motivo)}")
        %{}
    end
  end
end
