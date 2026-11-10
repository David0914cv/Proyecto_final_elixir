defmodule Emergencia.InicioTest do
  use ExUnit.Case, async: false

  test "la aplicación inicia los siete servidores supervisados y su estado inicial" do
    assert is_pid(Process.whereis(Emergencia.Supervisor))

    servidores = [
      Emergencia.UsuarioServer,
      Emergencia.ZonaServer,
      Emergencia.NecesidadServer,
      Emergencia.RecursoServer,
      Emergencia.PersonaServer,
      Emergencia.MascotaServer,
      Emergencia.AlbergueServer
    ]

    hijos = Supervisor.which_children(Emergencia.Supervisor)
    assert length(hijos) == 7

    for servidor <- servidores do
      pid = Process.whereis(servidor)
      assert is_pid(pid)
      assert Process.alive?(pid)

      assert Enum.any?(hijos, fn {id, hijo, tipo, _} ->
               id == servidor and hijo == pid and tipo == :worker
             end)

      esperado =
        if servidor == Emergencia.PersonaServer, do: %{personas: %{}, mensajes: %{}}, else: %{}

      assert :sys.get_state(pid) == esperado
    end
  end
end
