defmodule Emergencia.PersonaServer do
  @moduledoc """
  Servidor encargado de registrar, consultar y actualizar personas,
  además de administrar los mensajes entre familiares.

  Utiliza GenServer para mantener un estado centralizado.
  """

  use GenServer

  alias Emergencia.Persona
  alias Emergencia.Mensaje
  alias Emergencia.Persistencia

  @archivo "data/personas.dat"

  # --------------------------------------------------
  # INICIO DEL SERVIDOR
  # --------------------------------------------------

  @doc """
  Inicia el servidor de personas.

  Permite recibir opciones adicionales de GenServer,
  por ejemplo, un nombre para registrar el proceso.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    datos =
      case Persistencia.cargar(@archivo) do
        {:ok, %{personas: personas, mensajes: mensajes}}
        when is_map(personas) and is_map(mensajes) ->
          %{personas: personas, mensajes: mensajes}

        _ ->
          %{personas: %{}, mensajes: %{}}
      end

    {:ok, datos}
  end

  # --------------------------------------------------
  # FUNCIONES PUBLICAS
  # --------------------------------------------------

  @doc "Registra una persona en el sistema."
  def registrar(persona, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:registrar, persona})
  end

  @doc "Consulta una persona mediante su documento."
  def consultar(documento, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:consultar, documento})
  end

  @doc "Devuelve todas las personas registradas."
  def listar(servidor \\ __MODULE__) do
    GenServer.call(servidor, :listar)
  end

  @doc "Actualiza el estado de una persona."
  def actualizar_estado(documento, nuevo_estado, servidor \\ __MODULE__) do
    GenServer.call(
      servidor,
      {:actualizar_estado, documento, nuevo_estado}
    )
  end

  @doc "Envía un mensaje entre dos personas registradas."
  def enviar_mensaje(remitente, destinatario, contenido, servidor \\ __MODULE__) do
    GenServer.call(
      servidor,
      {:enviar_mensaje, remitente, destinatario, contenido}
    )
  end

  @doc "Consulta los mensajes enviados o recibidos por una persona."
  def mensajes_de(documento, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:mensajes_de, documento})
  end

  @doc "Marca un mensaje como entregado."
  def marcar_entregado(id_mensaje, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:marcar_entregado, id_mensaje})
  end

  # --------------------------------------------------
  # REGISTRO DE PERSONAS
  # --------------------------------------------------

  @impl true
  def handle_call({:registrar, %Persona{} = persona}, _from, estado) do
    documento = normalizar_documento(persona.documento)

    cond do
      not validar_persona(persona) ->
        {:reply, {:error, "Los datos de la persona están incompletos"}, estado}

      Map.has_key?(estado.personas, documento) ->
        {:reply, {:error, "Ya existe una persona con ese documento"}, estado}

      true ->
        persona = %{persona | documento: documento}

        personas = Map.put(
          estado.personas,
          documento,
          persona
        )

        nuevo_estado = %{estado | personas: personas}

        guardar_estado(nuevo_estado, estado)
    end
  end

  def handle_call({:registrar, _persona}, _from, estado) do
    {:reply, {:error, "Se debe enviar una estructura Emergencia.Persona"}, estado}
  end

  # --------------------------------------------------
  # CONSULTA DE PERSONAS
  # --------------------------------------------------

  def handle_call({:consultar, documento}, _from, estado) do
    documento = normalizar_documento(documento)

    case Map.get(estado.personas, documento) do
      nil ->
        {:reply, {:error, "Persona no encontrada"}, estado}

      persona ->
        {:reply, {:ok, persona}, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    {:reply, Map.values(estado.personas), estado}
  end

  # --------------------------------------------------
  # ACTUALIZACION DEL ESTADO
  # --------------------------------------------------

  def handle_call(
        {:actualizar_estado, documento, nuevo_estado},
        _from,
        estado
      ) do

    documento = normalizar_documento(documento)

    case Map.get(estado.personas, documento) do
      nil ->
        {:reply, {:error, "Persona no encontrada"}, estado}

      persona ->
        if estado_valido?(nuevo_estado) do
          cambio = %{
            estado_anterior: persona.estado,
            estado_nuevo: nuevo_estado
          }

          persona_actualizada = %{
            persona |
            estado: nuevo_estado,
            historial: [cambio | persona.historial]
          }

          personas = Map.put(
            estado.personas,
            documento,
            persona_actualizada
          )

          nuevo_estado_servidor = %{
            estado |
            personas: personas
          }

          guardar_estado(nuevo_estado_servidor, estado)
        else
          {:reply, {:error, "El estado indicado no es válido"}, estado}
        end
    end
  end

  # --------------------------------------------------
  # MENSAJES FAMILIARES
  # --------------------------------------------------

  def handle_call(
        {:enviar_mensaje, remitente, destinatario, contenido},
        _from,
        estado
      ) do

    remitente = normalizar_documento(remitente)
    destinatario = normalizar_documento(destinatario)

    cond do
      not Map.has_key?(estado.personas, remitente) ->
        {:reply, {:error, "El remitente no está registrado"}, estado}

      not Map.has_key?(estado.personas, destinatario) ->
        {:reply, {:error, "El destinatario no está registrado"}, estado}

      not is_binary(contenido) or String.trim(contenido) == "" ->
        {:reply, {:error, "El contenido del mensaje no puede estar vacío"}, estado}

      true ->
        mensaje = %Mensaje{
          id: System.unique_integer([:positive]),
          remitente: remitente,
          destinatario: destinatario,
          contenido: String.trim(contenido),
          entregado: false
        }

        mensajes = Map.put(
          estado.mensajes,
          mensaje.id,
          mensaje
        )

        nuevo_estado = %{estado | mensajes: mensajes}

        guardar_estado(nuevo_estado, estado)
    end
  end

  def handle_call({:mensajes_de, documento}, _from, estado) do
    documento = normalizar_documento(documento)

    mensajes =
      estado.mensajes
      |> Map.values()
      |> Enum.filter(fn mensaje ->
        mensaje.remitente == documento or
        mensaje.destinatario == documento
      end)

    {:reply, mensajes, estado}
  end

  def handle_call({:marcar_entregado, id_mensaje}, _from, estado) do
    case Map.get(estado.mensajes, id_mensaje) do
      nil ->
        {:reply, {:error, "Mensaje no encontrado"}, estado}

      mensaje ->
        actualizado = %{mensaje | entregado: true}

        mensajes = Map.put(
          estado.mensajes,
          id_mensaje,
          actualizado
        )

        nuevo_estado = %{estado | mensajes: mensajes}

        guardar_estado(nuevo_estado, estado)
    end
  end

  # --------------------------------------------------
  # FUNCIONES AUXILIARES
  # --------------------------------------------------

  defp validar_persona(%Persona{} = persona) do
    texto_valido?(persona.documento) and
      texto_valido?(persona.nombre) and
      texto_valido?(persona.zona) and
      edad_valida?(persona.edad)
  end

  defp texto_valido?(valor) do
    is_binary(valor) and String.trim(valor) != ""
  end

  defp edad_valida?(nil), do: true
  defp edad_valida?(edad), do: is_integer(edad) and edad >= 0

  defp estado_valido?(estado) do
    estado in [
      :sin_informacion,
      :busqueda,
      :localizada,
      :atendida
    ]
  end

  defp normalizar_documento(documento) when is_binary(documento) do
    String.trim(documento)
  end

  defp normalizar_documento(documento), do: documento

  # Guarda el nuevo estado.
  # Si ocurre un error al guardar, conserva el estado anterior.
  defp guardar_estado(nuevo_estado, estado_anterior) do
    case Persistencia.guardar(@archivo, nuevo_estado) do
      :ok ->
        {:reply, {:ok, :operacion_exitosa}, nuevo_estado}

      {:error, motivo} ->
        {:reply, {:error, {:error_al_guardar, motivo}}, estado_anterior}
    end
  end
end
