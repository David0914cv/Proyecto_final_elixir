defmodule Emergencia.Recurso do
  @moduledoc "Datos básicos de recurso. Las validaciones se implementarán después."
  defstruct codigo: nil,
            nombre: nil,
            categoria: nil,
            cantidad: 0,
            unidad: nil,
            ubicacion: nil,
            historial: []

            @doc "Crea un recurso validando todos los datos de entrada."
  def nuevo(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    with :ok <- validar_texto(codigo, :codigo_invalido),
         :ok <- validar_texto(nombre, :nombre_invalido),
         :ok <- validar_texto(categoria, :categoria_invalida),
         :ok <- validar_texto(unidad, :unidad_invalida),
         :ok <- validar_texto(ubicacion, :ubicacion_invalida),
         :ok <- validar_cantidad(cantidad) do
      recurso = %__MODULE__{
        codigo: String.trim(codigo),
        nombre: String.trim(nombre),
        categoria: categoria |> String.trim() |> String.downcase(),
        unidad: String.trim(unidad),
        ubicacion: String.trim(ubicacion),
        cantidad: cantidad
      }

      {:ok, registrar_movimiento(recurso, :entrada, cantidad, "inventario inicial")}
    end
  end

  @doc "Suma unidades al inventario."
  def entrada(recurso, cantidad, motivo \\ "entrada")

  def entrada(%__MODULE__{} = recurso, cantidad, motivo)
      when is_integer(cantidad) and cantidad > 0 do
    nuevo_recurso = %{recurso | cantidad: recurso.cantidad + cantidad}
    {:ok, registrar_movimiento(nuevo_recurso, :entrada, cantidad, motivo)}
  end

  def entrada(_recurso, _cantidad, _motivo), do: {:error, :cantidad_invalida}

  @doc "Resta unidades del inventario. Nunca deja la cantidad en negativo."
  def salida(recurso, cantidad, motivo \\ "salida")

  def salida(%__MODULE__{cantidad: disponible}, cantidad, _motivo)
      when is_integer(cantidad) and cantidad > disponible do
    {:error, :inventario_insuficiente}
  end

  def salida(%__MODULE__{} = recurso, cantidad, motivo)
      when is_integer(cantidad) and cantidad > 0 do
    nuevo_recurso = %{recurso | cantidad: recurso.cantidad - cantidad}
    {:ok, registrar_movimiento(nuevo_recurso, :salida, cantidad, motivo)}
  end

  def salida(_recurso, _cantidad, _motivo), do: {:error, :cantidad_invalida}

  #Funciones privadas
   defp registrar_movimiento(recurso, tipo, cantidad, motivo) do
    movimiento = %{tipo: tipo, cantidad: cantidad, motivo: motivo, fecha: DateTime.utc_now()}
    %{recurso | movimientos: [movimiento | recurso.movimientos]}
  end

  defp validar_texto(valor, _error) when is_binary(valor) and byte_size(valor) > 0 do
    if String.trim(valor) == "", do: {:error, :texto_vacio}, else: :ok
  end

  defp validar_texto(_valor, error), do: {:error, error}

  defp validar_cantidad(cantidad) when is_integer(cantidad) and cantidad >= 0, do: :ok
  defp validar_cantidad(_cantidad), do: {:error, :cantidad_invalida}
end

end
