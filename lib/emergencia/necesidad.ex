defmodule Emergencia.Necesidad do
  @moduledoc "Datos básicos de necesidad. Las validaciones se implementarán después."
  defstruct id: nil,
            tipo: nil,
            descripcion: nil,
            cantidad: 0,
            zona: nil,
            prioridad: :media,
            responsable: nil,
            estado: :pendiente
end
