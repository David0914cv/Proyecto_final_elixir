defmodule Emergencia.PersonaServer do
  @moduledoc "Proceso que mantendrá los datos de persona en memoria."
  use GenServer

  @doc "Inicia el servidor con opciones de GenServer, como :name."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    {:ok, %{personas: %{}, mensajes: %{}}}
  end
end
