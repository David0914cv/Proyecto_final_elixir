defmodule Emergencia.Usuario do
  @moduledoc "Datos básicos de usuario y validaciones sencillas."
  defstruct username: nil,
            contrasena: nil,
            nombre: nil,
            rol: :ciudadano,
            zona: nil,
            conectado: false

  def roles_validos do
    [:ciudadano, :voluntario, :coordinador, :administrador]
  end

  def rol_valido?(rol) do
    rol in roles_validos()
  end

  def crear(username, contrasena, nombre, rol, zona) do
    cond do
      username == nil or username == "" ->
        {:error, :username_vacio}

      contrasena == nil or contrasena == "" ->
        {:error, :contrasena_vacia}

      nombre == nil or nombre == "" ->
        {:error, :nombre_vacio}

      not rol_valido?(rol) ->
        {:error, :rol_invalido}

      zona == nil or zona == "" ->
        {:error, :zona_vacia}

      true ->
        usuario = %Emergencia.Usuario{
          username: username,
          contrasena: contrasena,
          nombre: nombre,
          rol: rol,
          zona: zona,
          conectado: false
        }

        {:ok, usuario}
    end
  end
end
