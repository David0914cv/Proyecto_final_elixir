defmodule Emergencia.Persistencia do
  @moduledoc """
  Módulo compartido para guardar y recuperar información
  de los servidores del sistema de emergencias.
  """

  @doc """
  Guarda datos en un archivo.

  Crea la carpeta correspondiente si todavía no existe.
  """
  def guardar(ruta, datos) do
    directorio = Path.dirname(ruta)

    with :ok <- File.mkdir_p(directorio) do
      contenido = :erlang.term_to_binary(datos)

      File.write(ruta, contenido)
    end
  end

  @doc """
  Carga datos desde un archivo.

  Devuelve {:ok, datos} cuando la lectura es correcta.
  Si el archivo no existe o no puede interpretarse,
  devuelve {:error, motivo}.
  """
  def cargar(ruta) do
    case File.read(ruta) do
      {:ok, contenido} ->
        try do
          datos = :erlang.binary_to_term(contenido, [:safe])
          {:ok, datos}
        rescue
          _error ->
            {:error, :archivo_invalido}
        end

      {:error, motivo} ->
        {:error, motivo}
    end
  end
end
