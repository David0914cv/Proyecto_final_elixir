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
            asignaciones: []

    # Lo que escribe el usuario (texto) se traduce a átomos usando estas listas
    # cerradas. Así nunca creamos átomos a partir de entradas arbitrarias.
    @tipos %{
      "agua" => :agua,
      "alimentos" => :alimentos,
      "medicamentos" => :medicamentos,
      "primeros_auxilios" => :primeros_auxilios,
      "refugio" => :refugio,
      "transporte" => :transporte,
      "rescate" => :rescate,
      "otra" => :otra
    }

    @prioridades %{
      "critica" => :critica,
      "alta" => :alta,
      "media" => :media,
      "baja" => :baja
    }

    # Cuanto menor el peso, más urgente.
    @peso_prioridad %{critica: 0, alta: 1, media: 2, baja: 3}

     # Para cada estado, a cuáles se puede pasar.
    # (:asignada no aparece como destino: se alcanza solo al completar
    # las asignaciones, ver asignar/3.)
    @transiciones %{
      pendiente: [:cancelada],
      asignada: [:en_atencion, :cancelada],
      en_atencion: [:atendida, :cancelada],
      atendida: [],
      cancelada: []
    }

     @doc "Crea una necesidad validando todos los datos. El id lo entrega el servidor."
  def nueva(id, tipo, descripcion, cantidad, zona, prioridad, responsable) do
    with :ok <- validar_texto(id, :id_invalido),
         {:ok, tipo} <- convertir(tipo, @tipos, :tipo_invalido),
         :ok <- validar_texto(descripcion, :descripcion_invalida),
         :ok <- validar_cantidad(cantidad),
         :ok <- validar_texto(zona, :zona_invalida),
         {:ok, prioridad} <- convertir(prioridad, @prioridades, :prioridad_invalida),
         :ok <- validar_texto(responsable, :responsable_invalido) do
      {:ok,
       %__MODULE__{
         id: String.trim(id),
         tipo: tipo,
         descripcion: String.trim(descripcion),
         cantidad: cantidad,
         zona: String.trim(zona),
         prioridad: prioridad,
         responsable: String.trim(responsable)
       }}
    end
  end

  @doc """
  Registra una asignación de recurso. Solo se puede mientras la necesidad
  esté :pendiente y sin superar la cantidad requerida. Al cubrir el total,
  pasa automáticamente a :asignada.
  """
  def asignar(%__MODULE__{estado: estado}, _codigo, _cantidad)
      when estado in [:atendida, :cancelada],
      do: {:error, :necesidad_cerrada}

  def asignar(%__MODULE__{estado: estado}, _codigo, _cantidad) when estado != :pendiente,
    do: {:error, :estado_invalido}

  def asignar(%__MODULE__{} = necesidad, codigo_recurso, cantidad)
      when is_binary(codigo_recurso) and is_integer(cantidad) and cantidad > 0 do
    if cantidad_asignada(necesidad) + cantidad > necesidad.cantidad do
      {:error, :excede_cantidad_requerida}
    else
      asignacion = %{recurso: codigo_recurso, cantidad: cantidad}
      necesidad = %{necesidad | asignaciones: [asignacion | necesidad.asignaciones]}
      {:ok, actualizar_estado(necesidad)}
    end
  end

   def asignar(_necesidad, _codigo, _cantidad), do: {:error, :cantidad_invalida}

  @doc "Cambia el estado solo si la transición es válida."
  def cambiar_estado(%__MODULE__{estado: actual} = necesidad, nuevo) do
    cond do
      actual in [:atendida, :cancelada] -> {:error, :necesidad_cerrada}
      nuevo in Map.fetch!(@transiciones, actual) -> {:ok, %{necesidad | estado: nuevo}}
      true -> {:error, :transicion_invalida}
    end
  end

  @doc "Suma lo asignado hasta ahora (función recursiva)."
  def cantidad_asignada(%__MODULE__{asignaciones: asignaciones}), do: sumar(asignaciones, 0)

  @doc "Ordena de más urgente a menos urgente (y por id en caso de empate)."
  def ordenar_por_prioridad(necesidades) do
    Enum.sort_by(necesidades, fn n -> {Map.fetch!(@peso_prioridad, n.prioridad), n.id} end)
  end

  # Funciones privadas
   defp sumar([], acumulado), do: acumulado
  defp sumar([%{cantidad: c} | resto], acumulado), do: sumar(resto, acumulado + c)

  defp actualizar_estado(%__MODULE__{} = n) do
    if cantidad_asignada(n) == n.cantidad, do: %{n | estado: :asignada}, else: n
  end

  defp convertir(valor, mapa, error) when is_binary(valor) do
    clave = valor |> String.trim() |> String.downcase() |> String.replace(" ", "_")

    case Map.fetch(mapa, clave) do
      {:ok, atomo} -> {:ok, atomo}
      :error -> {:error, error}
    end
  end

  defp convertir(_valor, _mapa, error), do: {:error, error}

  defp validar_texto(valor, error) when is_binary(valor) do
    if String.trim(valor) == "", do: {:error, error}, else: :ok
  end

  defp validar_texto(_valor, error), do: {:error, error}

  defp validar_cantidad(c) when is_integer(c) and c > 0, do: :ok
  defp validar_cantidad(_c), do: {:error, :cantidad_invalida}
end

end
