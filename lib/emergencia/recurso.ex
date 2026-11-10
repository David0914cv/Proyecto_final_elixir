defmodule Emergencia.Recurso do
  @moduledoc "Datos básicos de recurso. Las validaciones se implementarán después."
  defstruct codigo: nil,
            nombre: nil,
            categoria: nil,
            cantidad: 0,
            unidad: nil,
            ubicacion: nil,
            historial: []
end
