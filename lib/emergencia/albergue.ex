defmodule Emergencia.Albergue do
  @moduledoc "Datos básicos de albergue. Las validaciones se implementarán después."
  defstruct codigo: nil,
            nombre: nil,
            zona: nil,
            capacidad_maxima: 0,
            ocupacion: 0,
            personas: MapSet.new()
end
