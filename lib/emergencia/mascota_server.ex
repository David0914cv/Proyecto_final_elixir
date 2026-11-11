defmodule Emergencia.MascotaServer do
  @moduledoc """
  Servidor que administra los reportes de mascotas perdidas
  y encontradas, y busca posibles coincidencias.
  """

  use GenServer

  alias Emergencia.Mascota
  alias Emergencia.Persistencia

  @archivo "data/mascotas.dat"

  # --------------------------------------------------
  # INICIO DEL SERVIDOR
  # --------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    mascotas =
      case Persistencia.cargar(@archivo) do
        {:ok, datos} when is_map(datos) -> datos
        _ -> %{}
      end

    {:ok, mascotas}
  end

  # --------------------------------------------------
  # FUNCIONES PUBLICAS
  # --------------------------------------------------

  def registrar(mascota, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:registrar, mascota})
  end

  def consultar(id, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:consultar, id})
  end

  def listar(servidor \\ __MODULE__) do
    GenServer.call(servidor, :listar)
  end

  def buscar_coincidencias(servidor \\ __MODULE__) do
    GenServer.call(servidor, :buscar_coincidencias)
  end

  def cerrar_reporte(id, servidor \\ __MODULE__) do
    GenServer.call(servidor, {:cerrar_reporte, id})
  end

  # --------------------------------------------------
  # REGISTRO DE MASCOTAS
  # --------------------------------------------------

  @impl true
  def handle_call({:registrar, %Mascota{} = mascota}, _from, estado) do
    cond do
      not validar_mascota(mascota) ->
        {:reply, {:error, "Los datos del reporte están incompletos o son inválidos"}, estado}

      Map.has_key?(estado, mascota.id) ->
        {:reply, {:error, "Ya existe un reporte con ese ID"}, estado}

      true ->
        mascotas = Map.put(estado, mascota.id, mascota)

        guardar_mascotas(mascotas, estado)
    end
  end

  def handle_call({:registrar, _mascota}, _from, estado) do
    {:reply, {:error, "Se debe enviar una estructura Emergencia.Mascota"}, estado}
  end

  # --------------------------------------------------
  # CONSULTAS
  # --------------------------------------------------

  def handle_call({:consultar, id}, _from, estado) do
    case Map.get(estado, id) do
      nil ->
        {:reply, {:error, "Reporte no encontrado"}, estado}

      mascota ->
        {:reply, {:ok, mascota}, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    {:reply, Map.values(estado), estado}
  end

  # --------------------------------------------------
  # BUSQUEDA DE COINCIDENCIAS
  # --------------------------------------------------

  def handle_call(:buscar_coincidencias, _from, estado) do
    mascotas = Map.values(estado)

    perdidas =
      Enum.filter(mascotas, fn mascota ->
        mascota.tipo_reporte == :perdida and mascota.estado == :activa
      end)

    encontradas =
      Enum.filter(mascotas, fn mascota ->
        mascota.tipo_reporte == :encontrada and mascota.estado == :activa
      end)

    coincidencias = comparar_listas(perdidas, encontradas)

    {:reply, coincidencias, estado}
  end

  # --------------------------------------------------
  # CIERRE DE REPORTES
  # --------------------------------------------------

  def handle_call({:cerrar_reporte, id}, _from, estado) do
    case Map.get(estado, id) do
      nil ->
        {:reply, {:error, "Reporte no encontrado"}, estado}

      mascota ->
        mascota_actualizada = %{mascota | estado: :cerrada}

        mascotas = Map.put(
          estado,
          id,
          mascota_actualizada
        )

        guardar_mascotas(mascotas, estado)
    end
  end

  # --------------------------------------------------
  # COMPARACION RECURSIVA
  # --------------------------------------------------

  # Compara cada mascota perdida con todas las encontradas.
  defp comparar_listas(perdidas, encontradas) do
    comparar_perdidas(perdidas, encontradas, [])
  end

  defp comparar_perdidas([], _encontradas, resultado) do
    Enum.reverse(resultado)
  end

  defp comparar_perdidas([perdida | restantes], encontradas, resultado) do
    nuevas = comparar_encontradas(perdida, encontradas, resultado)

    comparar_perdidas(restantes, encontradas, nuevas)
  end

  defp comparar_encontradas(_perdida, [], resultado) do
    resultado
  end

  defp comparar_encontradas(perdida, [encontrada | restantes], resultado) do
    puntaje = calcular_similitud(perdida, encontrada)

    nuevo_resultado =
      if puntaje >= 5 do
        [
          %{
            perdida: perdida,
            encontrada: encontrada,
            puntaje: puntaje
          }
          | resultado
        ]
      else
        resultado
      end

    comparar_encontradas(perdida, restantes, nuevo_resultado)
  end

  # --------------------------------------------------
  # CALCULO DE SIMILITUD
  # --------------------------------------------------

  defp calcular_similitud(perdida, encontrada) do
    puntos_especie =
      if comparar_texto(perdida.especie, encontrada.especie), do: 3, else: 0

    puntos_color =
      if comparar_texto(perdida.color, encontrada.color), do: 2, else: 0

    puntos_tamano =
      if comparar_texto(perdida.tamano, encontrada.tamano), do: 1, else: 0

    puntos_zona =
      if comparar_texto(perdida.zona, encontrada.zona), do: 2, else: 0

    puntos_especie + puntos_color + puntos_tamano + puntos_zona
  end

  defp comparar_texto(a, b) when is_binary(a) and is_binary(b) do
    normalizar(a) == normalizar(b)
  end

  defp comparar_texto(_, _), do: false

  defp normalizar(texto) do
    texto
    |> String.trim()
    |> String.downcase()
  end

  # --------------------------------------------------
  # VALIDACION
  # --------------------------------------------------

  defp validar_mascota(%Mascota{} = mascota) do
    texto_valido?(mascota.id) and
      texto_valido?(mascota.especie) and
      texto_valido?(mascota.zona) and
      texto_valido?(mascota.contacto) and
      tipo_valido?(mascota.tipo_reporte)
  end

  defp validar_mascota(_), do: false

  defp texto_valido?(valor) do
    is_binary(valor) and String.trim(valor) != ""
  end

  defp tipo_valido?(tipo) do
    tipo in [:perdida, :encontrada]
  end

  # --------------------------------------------------
  # PERSISTENCIA
  # --------------------------------------------------

  defp guardar_mascotas(nuevas_mascotas, estado_anterior) do
    case Persistencia.guardar(@archivo, nuevas_mascotas) do
      :ok ->
        {:reply, {:ok, :operacion_exitosa}, nuevas_mascotas}

      {:error, motivo} ->
        {:reply, {:error, {:error_al_guardar, motivo}}, estado_anterior}
    end
  end
end
