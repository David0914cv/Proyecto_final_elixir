
defmodule Emergencia.Persistencia do
  @moduledoc """
  Módulo compartido para guardar y recuperar información
  de los servidores del sistema de emergencias mediante
  archivos de texto plano.
  """

  @doc """
  Guarda datos en un archivo de texto plano.

  Crea la carpeta correspondiente si todavía no existe.
  Los datos se convierten a texto mediante inspect/2.
  """
  def guardar(ruta, datos) do
    directorio = Path.dirname(ruta)

    with :ok <- File.mkdir_p(directorio) do
      contenido =
        inspect(datos,
          limit: :infinity,
          printable_limit: :infinity
        )

      File.write(ruta, contenido <> "\n")
    end
  end

  @doc """
  Carga datos desde un archivo de texto plano.

  Lee el contenido y lo convierte nuevamente en datos
  de Elixir mediante Code.eval_string/1.

  Devuelve {:ok, datos} cuando la lectura es correcta.
  Si el archivo no existe o su contenido no es válido,
  devuelve {:error, motivo}.
  """
  def cargar(ruta) do
    case File.read(ruta) do
      {:ok, contenido} ->
        try do
          {datos, _binding} = Code.eval_string(contenido)
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
