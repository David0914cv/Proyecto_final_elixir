defmodule Emergencia.Zona do
  @moduledoc "Datos básicos de zona. Las validaciones se implementarán después."
  defstruct codigo: nil, nombre: nil, nivel_afectacion: :bajo, cantidad_afectados: 0, sectores: []
end
