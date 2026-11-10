defmodule Emergencia.Supervisor do
  @moduledoc "Supervisa los siete servidores con la estrategia :one_for_one."
  use Supervisor
  @doc "Inicia el supervisor principal."
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok) do
    children = [
      {Emergencia.UsuarioServer, name: Emergencia.UsuarioServer},
      {Emergencia.ZonaServer, name: Emergencia.ZonaServer},
      {Emergencia.NecesidadServer, name: Emergencia.NecesidadServer},
      {Emergencia.RecursoServer, name: Emergencia.RecursoServer},
      {Emergencia.PersonaServer, name: Emergencia.PersonaServer},
      {Emergencia.MascotaServer, name: Emergencia.MascotaServer},
      {Emergencia.AlbergueServer, name: Emergencia.AlbergueServer}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
