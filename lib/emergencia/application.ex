defmodule Emergencia.Application do
  @moduledoc "Punto de inicio de la aplicación OTP."
  use Application
  @impl true
  def start(_type, _args) do
    Emergencia.Supervisor.start_link([])
  end
end
