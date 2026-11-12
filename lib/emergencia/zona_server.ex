defmodule Emergencia.ZonaServer do
  @moduledoc "Proceso que mantiene los datos de las zonas en memoria."

  use GenServer

  @doc "Inicia el servidor de zonas."
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @doc "Registra una nueva zona."
  def registrar(codigo, nombre, nivel_afectacion, cantidad_afectados) do
    GenServer.call(
      __MODULE__,
      {:registrar, codigo, nombre, nivel_afectacion, cantidad_afectados}
    )
  end

  @doc "Busca una zona por su código."
  def buscar(codigo) do
    GenServer.call(__MODULE__, {:buscar, codigo})
  end

  @doc "Lista todas las zonas registradas."
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  @doc "Agrega un sector a una zona."
  def agregar_sector(codigo, nombre_sector) do
    GenServer.call(
      __MODULE__,
      {:agregar_sector, codigo, nombre_sector}
    )
  end

  @doc "Agrega un punto de atención a un sector de una zona."
  def agregar_punto(codigo, nombre_sector, nombre_punto) do
    GenServer.call(
      __MODULE__,
      {:agregar_punto, codigo, nombre_sector, nombre_punto}
    )
  end

  @doc "Cuenta los puntos de atención de una zona."
  def contar_puntos(codigo) do
    GenServer.call(__MODULE__, {:contar_puntos, codigo})
  end

  @impl true
  def handle_call(
        {:registrar, codigo, nombre, nivel_afectacion, cantidad_afectados},
        _from,
        zonas
      ) do
    if Map.has_key?(zonas, codigo) do
      {:reply, {:error, :zona_ya_existe}, zonas}
    else
      case Emergencia.Zona.crear(
             codigo,
             nombre,
             nivel_afectacion,
             cantidad_afectados
           ) do
        {:ok, zona} ->
          nuevas_zonas = Map.put(zonas, codigo, zona)

          {:reply, {:ok, zona}, nuevas_zonas}

        {:error, motivo} ->
          {:reply, {:error, motivo}, zonas}
      end
    end
  end

  @impl true
  def handle_call({:buscar, codigo}, _from, zonas) do
    case Map.get(zonas, codigo) do
      nil ->
        {:reply, {:error, :zona_no_encontrada}, zonas}

      zona ->
        {:reply, {:ok, zona}, zonas}
    end
  end

  @impl true
  def handle_call(:listar, _from, zonas) do
    lista_zonas = Map.values(zonas)

    {:reply, lista_zonas, zonas}
  end

  @impl true
  def handle_call(
        {:agregar_sector, codigo, nombre_sector},
        _from,
        zonas
      ) do
    case Map.get(zonas, codigo) do
      nil ->
        {:reply, {:error, :zona_no_encontrada}, zonas}

      zona ->
        case Emergencia.Zona.agregar_sector(zona, nombre_sector) do
          {:ok, zona_actualizada} ->
            nuevas_zonas =
              Map.put(zonas, codigo, zona_actualizada)

            {:reply, {:ok, zona_actualizada}, nuevas_zonas}

          {:error, motivo} ->
            {:reply, {:error, motivo}, zonas}
        end
    end
  end

  @impl true
  def handle_call(
        {:agregar_punto, codigo, nombre_sector, nombre_punto},
        _from,
        zonas
      ) do
    case Map.get(zonas, codigo) do
      nil ->
        {:reply, {:error, :zona_no_encontrada}, zonas}

      zona ->
        case Emergencia.Zona.agregar_punto(
               zona,
               nombre_sector,
               nombre_punto
             ) do
          {:ok, zona_actualizada} ->
            nuevas_zonas =
              Map.put(zonas, codigo, zona_actualizada)

            {:reply, {:ok, zona_actualizada}, nuevas_zonas}

          {:error, motivo} ->
            {:reply, {:error, motivo}, zonas}
        end
    end
  end

  @impl true
  def handle_call(
        {:contar_puntos, codigo},
        _from,
        zonas
      ) do
    case Map.get(zonas, codigo) do
      nil ->
        {:reply, {:error, :zona_no_encontrada}, zonas}

      zona ->
        cantidad = Emergencia.Zona.contar_puntos(zona)

        {:reply, {:ok, cantidad}, zonas}
    end
  end
end
