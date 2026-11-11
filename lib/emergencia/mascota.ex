defmodule Emergencia.Mascota do
  @moduledoc """
  Estructura que representa un reporte de mascota perdida
  o encontrada durante la emergencia.
  """

  defstruct id: nil,
            tipo_reporte: nil,
            especie: nil,
            nombre: nil,
            color: nil,
            tamano: nil,
            caracteristicas: nil,
            zona: nil,
            contacto: nil,
            estado: :activa
end
