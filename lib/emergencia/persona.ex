defmodule Emergencia.Persona do
  @moduledoc """
  Estructura que representa a una persona afectada por la emergencia.

  Almacena sus datos básicos, su estado de atención y un historial
  de cambios relacionados con su situación.
  """

  defstruct id: nil,
            nombre: nil,
            documento: nil,
            edad: nil,
            zona: nil,
            estado: :sin_informacion,
            historial: []
end

defmodule Emergencia.Mensaje do
  @moduledoc """
  Estructura que representa un mensaje enviado entre familiares
  o personas registradas en el sistema.
  """

  defstruct id: nil,
            remitente: nil,
            destinatario: nil,
            contenido: nil,
            entregado: false
end
