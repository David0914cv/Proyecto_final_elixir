defmodule Emergencia.UsuarioServer do
  @moduledoc "Proceso que mantiene los datos de usuario en memoria."

  use GenServer

  @doc "Inicia el servidor de usuarios."
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @doc "Registra un nuevo usuario."
  def registrar(username, contrasena, nombre, rol, zona) do
    GenServer.call(
      __MODULE__,
      {:registrar, username, contrasena, nombre, rol, zona}
    )
  end

  @doc "Busca un usuario por su username."
  def buscar(username) do
    GenServer.call(__MODULE__, {:buscar, username})
  end

  @doc "Conecta un usuario si existe y la contraseña es correcta."
  def conectar(username, contrasena) do
    GenServer.call(__MODULE__, {:conectar, username, contrasena})
  end

  @doc "Desconecta un usuario si existe."
  def desconectar(username) do
    GenServer.call(__MODULE__, {:desconectar, username})
  end

  @doc "Lista todos los usuarios registrados."
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  @impl true
  def handle_call(
        {:registrar, username, contrasena, nombre, rol, zona},
        _from,
        usuarios
      ) do
    if Map.has_key?(usuarios, username) do
      {:reply, {:error, :usuario_ya_existe}, usuarios}
    else
      case Emergencia.Usuario.crear(username, contrasena, nombre, rol, zona) do
        {:ok, usuario} ->
          nuevos_usuarios = Map.put(usuarios, username, usuario)

          {:reply, {:ok, usuario}, nuevos_usuarios}

        {:error, motivo} ->
          {:reply, {:error, motivo}, usuarios}
      end
    end
  end

  @impl true
  def handle_call({:buscar, username}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        {:reply, {:error, :usuario_no_encontrado}, usuarios}

      usuario ->
        {:reply, {:ok, usuario}, usuarios}
    end
  end

  @impl true
  def handle_call({:conectar, username, contrasena}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        {:reply, {:error, :usuario_no_encontrado}, usuarios}

      usuario ->
        if usuario.contrasena == contrasena do
          usuario_conectado = %{usuario | conectado: true}

          nuevos_usuarios =
            Map.put(usuarios, username, usuario_conectado)

          {:reply, {:ok, usuario_conectado}, nuevos_usuarios}
        else
          {:reply, {:error, :contrasena_incorrecta}, usuarios}
        end
    end
  end

  @impl true
  def handle_call({:desconectar, username}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        {:reply, {:error, :usuario_no_encontrado}, usuarios}

      usuario ->
        usuario_desconectado = %{usuario | conectado: false}

        nuevos_usuarios =
          Map.put(usuarios, username, usuario_desconectado)

        {:reply, {:ok, usuario_desconectado}, nuevos_usuarios}
    end
  end

  @impl true
  def handle_call(:listar, _from, usuarios) do
    lista_usuarios = Map.values(usuarios)

    {:reply, lista_usuarios, usuarios}
  end
end
