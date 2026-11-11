defmodule Emergencia.Albergue do
  @moduledoc """
  Estructura que representa un albergue disponible durante
  una emergencia y permite almacenar las personas alojadas.
  """

  defstruct codigo: nil,
            nombre: nil,
            zona: nil,
            capacidad_maxima: 0,
            ocupacion: 0,
            personas: MapSet.new()
end
