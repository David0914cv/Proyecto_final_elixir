defmodule Emergencia.Main do
  def main do
    IO.puts("\n==========================================")
    IO.puts("   SISTEMA DE GESTIÓN DE EMERGENCIAS")
    IO.puts("==========================================")

    menu_principal()
  end

  defp menu_principal do
    IO.puts("""

    MENÚ PRINCIPAL

    1. Usuarios
    2. Zonas
    3. Necesidades
    4. Recursos
    5. Personas
    6. Mascotas
    7. Albergues
    0. Salir
    """)

    opcion =
      IO.gets("Seleccione una opción: ")
      |> String.trim()

    procesar_opcion(opcion)
  end

  defp procesar_opcion("1") do
    menu_usuarios()
  end

  defp procesar_opcion("2") do
    menu_zonas()
  end

  defp procesar_opcion("3") do
    IO.puts("\nMódulo de necesidades en desarrollo.")
    menu_principal()
  end

  defp procesar_opcion("4") do
    IO.puts("\nMódulo de recursos en desarrollo.")
    menu_principal()
  end

  defp procesar_opcion("5") do
    IO.puts("\nMódulo de personas en desarrollo.")
    menu_principal()
  end

  defp procesar_opcion("6") do
    IO.puts("\nMódulo de mascotas en desarrollo.")
    menu_principal()
  end

  defp procesar_opcion("7") do
    IO.puts("\nMódulo de albergues en desarrollo.")
    menu_principal()
  end

  defp procesar_opcion("0") do
    IO.puts("\nSaliendo del sistema...")
  end

  defp procesar_opcion(_) do
    IO.puts("\nOpción inválida.")
    menu_principal()
  end

  # ============================
  # USUARIOS
  # ============================

  defp menu_usuarios do
    IO.puts("""

    MENÚ DE USUARIOS

    1. Registrar usuario
    2. Conectar usuario
    3. Desconectar usuario
    4. Buscar usuario
    5. Listar usuarios
    0. Volver
    """)

    opcion =
      IO.gets("Seleccione una opción: ")
      |> String.trim()

    procesar_usuario(opcion)
  end

  defp procesar_usuario("1") do
    registrar_usuario()
    menu_usuarios()
  end

  defp procesar_usuario("2") do
    conectar_usuario()
    menu_usuarios()
  end

  defp procesar_usuario("3") do
    desconectar_usuario()
    menu_usuarios()
  end

  defp procesar_usuario("4") do
    buscar_usuario()
    menu_usuarios()
  end

  defp procesar_usuario("5") do
    listar_usuarios()
    menu_usuarios()
  end

  defp procesar_usuario("0") do
    menu_principal()
  end

  defp procesar_usuario(_) do
    IO.puts("\nOpción inválida.")
    menu_usuarios()
  end

  defp registrar_usuario do
    username =
      IO.gets("Username: ")
      |> String.trim()

    contrasena =
      IO.gets("Contraseña: ")
      |> String.trim()

    nombre =
      IO.gets("Nombre completo: ")
      |> String.trim()

    IO.puts("""
    Roles disponibles:
    1. Ciudadano
    2. Voluntario
    3. Coordinador
    4. Administrador
    """)

    rol =
      IO.gets("Seleccione el rol: ")
      |> String.trim()
      |> convertir_rol()

    zona =
      IO.gets("Zona principal: ")
      |> String.trim()

    case Emergencia.UsuarioServer.registrar(
           username,
           contrasena,
           nombre,
           rol,
           zona
         ) do
      {:ok, usuario} ->
        IO.puts("\nUsuario registrado correctamente.")
        IO.inspect(usuario)

      {:error, motivo} ->
        IO.puts("\nNo se pudo registrar el usuario.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp conectar_usuario do
    username =
      IO.gets("Username: ")
      |> String.trim()

    contrasena =
      IO.gets("Contraseña: ")
      |> String.trim()

    case Emergencia.UsuarioServer.conectar(username, contrasena) do
      {:ok, usuario} ->
        IO.puts("\nUsuario conectado correctamente.")
        IO.inspect(usuario)

      {:error, motivo} ->
        IO.puts("\nNo se pudo conectar el usuario.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp desconectar_usuario do
    username =
      IO.gets("Username: ")
      |> String.trim()

    case Emergencia.UsuarioServer.desconectar(username) do
      {:ok, usuario} ->
        IO.puts("\nUsuario desconectado correctamente.")
        IO.inspect(usuario)

      {:error, motivo} ->
        IO.puts("\nNo se pudo desconectar el usuario.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp buscar_usuario do
    username =
      IO.gets("Username: ")
      |> String.trim()

    case Emergencia.UsuarioServer.buscar(username) do
      {:ok, usuario} ->
        IO.puts("\nUsuario encontrado:")
        IO.inspect(usuario)

      {:error, motivo} ->
        IO.puts("\nNo se encontró el usuario.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp listar_usuarios do
    usuarios = Emergencia.UsuarioServer.listar()

    if usuarios == [] do
      IO.puts("\nNo hay usuarios registrados.")
    else
      IO.puts("\nUsuarios registrados:")

      Enum.each(usuarios, fn usuario ->
        IO.puts(
          "#{usuario.username} - #{usuario.nombre} - #{usuario.rol} - #{usuario.zona}"
        )
      end)
    end
  end

  defp convertir_rol("1"), do: :ciudadano
  defp convertir_rol("2"), do: :voluntario
  defp convertir_rol("3"), do: :coordinador
  defp convertir_rol("4"), do: :administrador
  defp convertir_rol(_), do: :invalido

  # ============================
  # ZONAS
  # ============================

  defp menu_zonas do
    IO.puts("""

    MENÚ DE ZONAS

    1. Registrar zona
    2. Buscar zona
    3. Listar zonas
    4. Agregar sector
    5. Agregar punto de atención
    6. Contar puntos de atención
    0. Volver
    """)

    opcion =
      IO.gets("Seleccione una opción: ")
      |> String.trim()

    procesar_zona(opcion)
  end

  defp procesar_zona("1") do
    registrar_zona()
    menu_zonas()
  end

  defp procesar_zona("2") do
    buscar_zona()
    menu_zonas()
  end

  defp procesar_zona("3") do
    listar_zonas()
    menu_zonas()
  end

  defp procesar_zona("4") do
    agregar_sector()
    menu_zonas()
  end

  defp procesar_zona("5") do
    agregar_punto()
    menu_zonas()
  end

  defp procesar_zona("6") do
    contar_puntos()
    menu_zonas()
  end

  defp procesar_zona("0") do
    menu_principal()
  end

  defp procesar_zona(_) do
    IO.puts("\nOpción inválida.")
    menu_zonas()
  end

  defp registrar_zona do
    codigo =
      IO.gets("Código de la zona: ")
      |> String.trim()

    nombre =
      IO.gets("Nombre de la zona: ")
      |> String.trim()

    IO.puts("""
    Nivel de afectación:
    1. Crítico
    2. Alto
    3. Medio
    4. Bajo
    """)

    nivel =
      IO.gets("Seleccione el nivel: ")
      |> String.trim()
      |> convertir_nivel()

    cantidad_afectados =
      IO.gets("Cantidad de afectados: ")
      |> String.trim()

    case Integer.parse(cantidad_afectados) do
      {cantidad, ""} ->
        case Emergencia.ZonaServer.registrar(
               codigo,
               nombre,
               nivel,
               cantidad
             ) do
          {:ok, zona} ->
            IO.puts("\nZona registrada correctamente.")
            IO.inspect(zona)

          {:error, motivo} ->
            IO.puts("\nNo se pudo registrar la zona.")
            IO.puts("Motivo: #{motivo}")
        end

      _ ->
        IO.puts("\nLa cantidad de afectados debe ser un número entero.")
    end
  end

  defp buscar_zona do
    codigo =
      IO.gets("Código de la zona: ")
      |> String.trim()

    case Emergencia.ZonaServer.buscar(codigo) do
      {:ok, zona} ->
        IO.puts("\nZona encontrada:")
        IO.inspect(zona)

      {:error, motivo} ->
        IO.puts("\nNo se encontró la zona.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp listar_zonas do
    zonas = Emergencia.ZonaServer.listar()

    if zonas == [] do
      IO.puts("\nNo hay zonas registradas.")
    else
      IO.puts("\nZonas registradas:")

      Enum.each(zonas, fn zona ->
        IO.puts(
          "#{zona.codigo} - #{zona.nombre} - #{zona.nivel_afectacion} - Afectados: #{zona.cantidad_afectados}"
        )
      end)
    end
  end

  defp agregar_sector do
    codigo =
      IO.gets("Código de la zona: ")
      |> String.trim()

    sector =
      IO.gets("Nombre del sector: ")
      |> String.trim()

    case Emergencia.ZonaServer.agregar_sector(codigo, sector) do
      {:ok, _zona} ->
        IO.puts("\nSector agregado correctamente.")

      {:error, motivo} ->
        IO.puts("\nNo se pudo agregar el sector.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp agregar_punto do
    codigo =
      IO.gets("Código de la zona: ")
      |> String.trim()

    sector =
      IO.gets("Nombre del sector: ")
      |> String.trim()

    punto =
      IO.gets("Nombre del punto de atención: ")
      |> String.trim()

    case Emergencia.ZonaServer.agregar_punto(
           codigo,
           sector,
           punto
         ) do
      {:ok, _zona} ->
        IO.puts("\nPunto de atención agregado correctamente.")

      {:error, motivo} ->
        IO.puts("\nNo se pudo agregar el punto.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp contar_puntos do
    codigo =
      IO.gets("Código de la zona: ")
      |> String.trim()

    case Emergencia.ZonaServer.contar_puntos(codigo) do
      {:ok, cantidad} ->
        IO.puts("\nCantidad de puntos de atención: #{cantidad}")

      {:error, motivo} ->
        IO.puts("\nNo se pudo realizar el conteo.")
        IO.puts("Motivo: #{motivo}")
    end
  end

  defp convertir_nivel("1"), do: :critico
  defp convertir_nivel("2"), do: :alto
  defp convertir_nivel("3"), do: :medio
  defp convertir_nivel("4"), do: :bajo
  defp convertir_nivel(_), do: :invalido
end

Emergencia.Main.main()
