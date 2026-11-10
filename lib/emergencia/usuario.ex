defmodule Emergencia.Usuario do
  @moduledoc "Datos básicos de usuario. Las validaciones se implementarán después."
  defstruct username: nil,
            contrasena: nil,
            nombre: nil,
            rol: :ciudadano,
            zona: nil,
            conectado: false
end
