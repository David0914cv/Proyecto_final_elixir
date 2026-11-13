defmodule Emergencia.AlbergueServer do
  @moduledoc """
  Servidor encargado de administrar los albergues,
  controlar su capacidad y registrar ingresos y salidas.
  """

  use GenServer

  alias Emergencia.Albergue
  alias Emergencia.Persistencia

  @archivo "data/albergues.txt"

  # --------------------------------------------------
  # INICIO DEL SERVIDOR
  # --------------------------------------------------

  @doc "Inicia el servidor de albergues."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    albergues =
      case Persistencia.cargar(@archivo) do
        {:ok, datos} when is_map(datos) -> datos
        _ -> %{}
      end

    {:ok, albergues}
  end

  # --------------------------------------------------
  # FUNCIONES PUBLICAS
  # --------------------------------------------------

  @doc "Registra un nuevo albergue."
  def registrar(albergue, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:registrar, albergue})
  end

  @doc "Consulta un albergue mediante su código."
  def consultar(codigo, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:consultar, codigo})
  end

  @doc "Devuelve todos los albergues."
  def listar(servidor \\ __MODULE__) do
    GenServer.call(servidor, :listar)
  end

  @doc "Registra el ingreso de una persona a un albergue."
  def ingresar(codigo, documento, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:ingresar, codigo, documento})
  end

  @doc "Registra la salida de una persona de un albergue."
  def registrar_salida(codigo, documento, servidor \\ __MODULE__) do
    GenServer.call(
      servidor,
      {:registrar_salida, codigo, documento}
    )
  end

  @doc "Consulta la ocupación y los cupos disponibles."
  def disponibilidad(codigo, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:disponibilidad, codigo})
  end

  # --------------------------------------------------
  # REGISTRO DE ALBERGUES
  # --------------------------------------------------

  @impl true
  def handle_call({:registrar, %Albergue{} = albergue}, _from, estado) do
    cond do
      not validar_albergue(albergue) ->
        {:reply, {:error, "Los datos del albergue son inválidos"}, estado}

      true ->
        albergue = %{albergue | codigo: String.trim(albergue.codigo)}

        if Map.has_key?(estado, albergue.codigo) do
          {:reply, {:error, "Ya existe un albergue con ese código"}, estado}
        else
          # Se calcula la ocupación a partir del conjunto de personas.
          albergue = %{
            albergue |
            ocupacion: MapSet.size(albergue.personas)
          }

          albergues = Map.put(
            estado,
            albergue.codigo,
            albergue
          )

          guardar_albergues(albergues, estado)
        end
    end
  end

  def handle_call({:registrar, _albergue}, _from, estado) do
    {:reply, {:error, "Se debe enviar una estructura Emergencia.Albergue"}, estado}
  end

  # --------------------------------------------------
  # CONSULTAS
  # --------------------------------------------------

  def handle_call({:consultar, codigo}, _from, estado) do
    codigo = normalizar_texto(codigo)

    case Map.get(estado, codigo) do
      nil ->
        {:reply, {:error, "Albergue no encontrado"}, estado}

      albergue ->
        {:reply, {:ok, albergue}, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    {:reply, Map.values(estado), estado}
  end

  # --------------------------------------------------
  # INGRESO DE PERSONAS
  # --------------------------------------------------

  def handle_call({:ingresar, codigo, documento}, _from, estado) do
    codigo = normalizar_texto(codigo)
    documento = normalizar_texto(documento)

    case Map.get(estado, codigo) do
      nil ->
        {:reply, {:error, "Albergue no encontrado"}, estado}

      albergue ->
        cond do
          not texto_valido?(documento) ->
            {:reply, {:error, "El documento no es válido"}, estado}

          persona_alojada?(estado, documento) ->
            {:reply, {:error, "La persona ya está alojada en un albergue"}, estado}

          MapSet.size(albergue.personas) >= albergue.capacidad_maxima ->
            {:reply, {:error, "El albergue no tiene cupos disponibles"}, estado}

          true ->
            personas = MapSet.put(albergue.personas, documento)

            actualizado = %{
              albergue |
              personas: personas,
              ocupacion: MapSet.size(personas)
            }

            albergues = Map.put(
              estado,
              codigo,
              actualizado
            )

            guardar_albergues(albergues, estado)
        end
    end
  end

  # --------------------------------------------------
  # SALIDA DE PERSONAS
  # --------------------------------------------------

  def handle_call(
        {:registrar_salida, codigo, documento},
        _from,
        estado
      ) do
    codigo = normalizar_texto(codigo)
    documento = normalizar_texto(documento)

    case Map.get(estado, codigo) do
      nil ->
        {:reply, {:error, "Albergue no encontrado"}, estado}

      albergue ->
        cond do
          not texto_valido?(documento) ->
            {:reply, {:error, "El documento no es válido"}, estado}

          not MapSet.member?(albergue.personas, documento) ->
            {:reply, {:error, "La persona no está registrada en este albergue"}, estado}

          true ->
            personas = MapSet.delete(albergue.personas, documento)

            actualizado = %{
              albergue |
              personas: personas,
              ocupacion: MapSet.size(personas)
            }

            albergues = Map.put(
              estado,
              codigo,
              actualizado
            )

            guardar_albergues(albergues, estado)
        end
    end
  end

  # --------------------------------------------------
  # DISPONIBILIDAD
  # --------------------------------------------------

  def handle_call({:disponibilidad, codigo}, _from, estado) do
    codigo = normalizar_texto(codigo)

    case Map.get(estado, codigo) do
      nil ->
        {:reply, {:error, "Albergue no encontrado"}, estado}

      albergue ->
        ocupacion = MapSet.size(albergue.personas)
        disponibles = albergue.capacidad_maxima - ocupacion

        resultado = %{
          codigo: albergue.codigo,
          nombre: albergue.nombre,
          capacidad_maxima: albergue.capacidad_maxima,
          ocupacion: ocupacion,
          disponibles: disponibles
        }

        {:reply, {:ok, resultado}, estado}
    end
  end

  # --------------------------------------------------
  # FUNCIONES AUXILIARES
  # --------------------------------------------------

  defp validar_albergue(%Albergue{} = albergue) do
    texto_valido?(albergue.codigo) and
      texto_valido?(albergue.nombre) and
      texto_valido?(albergue.zona) and
      is_integer(albergue.capacidad_maxima) and
      albergue.capacidad_maxima > 0 and
      match?(%MapSet{}, albergue.personas) and
      MapSet.size(albergue.personas) <= albergue.capacidad_maxima
  end

  defp validar_albergue(_), do: false

  defp texto_valido?(valor) do
    is_binary(valor) and String.trim(valor) != ""
  end

  defp normalizar_texto(valor) when is_binary(valor) do
    String.trim(valor)
  end

  defp normalizar_texto(valor), do: valor

  # Comprueba si un documento ya aparece en algún albergue.
  defp persona_alojada?(albergues, documento) do
    Enum.any?(Map.values(albergues), fn albergue ->
      MapSet.member?(albergue.personas, documento)
    end)
  end

  # --------------------------------------------------
  # PERSISTENCIA
  # --------------------------------------------------

  defp guardar_albergues(nuevos_albergues, estado_anterior) do
    case Persistencia.guardar(@archivo, nuevos_albergues) do
      :ok ->
        {:reply, {:ok, :operacion_exitosa}, nuevos_albergues}

      {:error, motivo} ->
        {:reply, {:error, {:error_al_guardar, motivo}}, estado_anterior}
    end
  end
end
