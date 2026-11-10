defmodule Emergencia.Mascota do
  @moduledoc "Datos básicos de mascota. Las validaciones se implementarán después."
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
