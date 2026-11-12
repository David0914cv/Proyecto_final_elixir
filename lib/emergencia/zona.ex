defmodule Emergencia.Zona do
  @moduledoc "Datos básicos de zona y funciones relacionadas."

  defstruct codigo: nil,
            nombre: nil,
            nivel_afectacion: :bajo,
            cantidad_afectados: 0,
            sectores: []

  def niveles_validos do
    [:critico, :alto, :medio, :bajo]
  end

  def nivel_valido?(nivel) do
    nivel in niveles_validos()
  end

  def crear(codigo, nombre, nivel_afectacion, cantidad_afectados) do
    cond do
      codigo == nil or codigo == "" ->
        {:error, :codigo_vacio}

      nombre == nil or nombre == "" ->
        {:error, :nombre_vacio}

      not nivel_valido?(nivel_afectacion) ->
        {:error, :nivel_invalido}

      not is_integer(cantidad_afectados) or cantidad_afectados < 0 ->
        {:error, :cantidad_afectados_invalida}

      true ->
        zona = %Emergencia.Zona{
          codigo: codigo,
          nombre: nombre,
          nivel_afectacion: nivel_afectacion,
          cantidad_afectados: cantidad_afectados,
          sectores: []
        }

        {:ok, zona}
    end
  end

  def agregar_sector(zona, nombre_sector) do
    cond do
      nombre_sector == nil or nombre_sector == "" ->
        {:error, :nombre_sector_vacio}

      existe_sector?(zona.sectores, nombre_sector) ->
        {:error, :sector_ya_existe}

      true ->
        sector = %{
          nombre: nombre_sector,
          puntos: []
        }

        zona_actualizada = %{
          zona
          | sectores: zona.sectores ++ [sector]
        }

        {:ok, zona_actualizada}
    end
  end

  def agregar_punto(zona, nombre_sector, nombre_punto) do
    if nombre_punto == nil or nombre_punto == "" do
      {:error, :nombre_punto_vacio}
    else
      case agregar_punto_sector(
             zona.sectores,
             nombre_sector,
             nombre_punto
           ) do
        {:ok, sectores_actualizados} ->
          zona_actualizada = %{
            zona
            | sectores: sectores_actualizados
          }

          {:ok, zona_actualizada}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  def contar_puntos(zona) do
    contar_puntos_sectores(zona.sectores)
  end

  defp existe_sector?(sectores, nombre_sector) do
    Enum.any?(sectores, fn sector ->
      sector.nombre == nombre_sector
    end)
  end

  defp agregar_punto_sector([], _nombre_sector, _nombre_punto) do
    {:error, :sector_no_encontrado}
  end

  defp agregar_punto_sector(
         [sector | resto],
         nombre_sector,
         nombre_punto
       ) do
    if sector.nombre == nombre_sector do
      if existe_punto?(sector.puntos, nombre_punto) do
        {:error, :punto_ya_existe}
      else
        punto = %{
          nombre: nombre_punto
        }

        sector_actualizado = %{
          sector
          | puntos: sector.puntos ++ [punto]
        }

        {:ok, [sector_actualizado | resto]}
      end
    else
      case agregar_punto_sector(
             resto,
             nombre_sector,
             nombre_punto
           ) do
        {:ok, resto_actualizado} ->
          {:ok, [sector | resto_actualizado]}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  defp existe_punto?(puntos, nombre_punto) do
    Enum.any?(puntos, fn punto ->
      punto.nombre == nombre_punto
    end)
  end

  defp contar_puntos_sectores([]) do
    0
  end

  defp contar_puntos_sectores([sector | resto]) do
    contar_lista_puntos(sector.puntos) +
      contar_puntos_sectores(resto)
  end

  defp contar_lista_puntos([]) do
    0
  end

  defp contar_lista_puntos([_punto | resto]) do
    1 + contar_lista_puntos(resto)
  end
end
