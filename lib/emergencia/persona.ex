defmodule Emergencia.Persona do
  @moduledoc "Datos básicos de persona. Las validaciones se implementarán después."
  defstruct id: nil,
            nombre: nil,
            documento: nil,
            edad: nil,
            zona: nil,
            estado: :sin_informacion,
            historial: []
end

defmodule Emergencia.Mensaje do
  @moduledoc "Mensaje familiar administrado por PersonaServer en una siguiente etapa."
  defstruct id: nil, remitente: nil, destinatario: nil, contenido: nil, entregado: false
end
