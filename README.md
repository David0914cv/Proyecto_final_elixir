# Emergencia

Proyecto final de Programación III en Elixir para tres estudiantes.
Sistema de coordinación y gestión de emergencias después de un terremoto.

## Etapa actual

Base con Mix, structs, siete GenServers y Supervisor, sin dependencias externas.
No hay todavía operaciones de negocio, validaciones, menú interactivo ni
lectura/escritura de datos. Los archivos de data/ están vacíos.
Los servidores comienzan con mapas vacíos. PersonaServer separa personas y
mensajes. Albergue usa MapSet para evitar identificadores de personas repetidos.
Los campos usan nombres sin tildes para facilitar su escritura en consola.
Los structs representan datos; sus valores todavía no se validan.

## Ejecución

Requiere Elixir 1.14 o posterior de la serie 1.x y Erlang/OTP compatible.

```sh
mix test
iex -S mix
```

Dentro de IEx:

```elixir
Emergencia.CLI.iniciar()
%Emergencia.Usuario{username: "ana", nombre: "Ana"}
```

En Windows PowerShell, si la política bloquea mix.ps1, usar mix.bat test,
mix.bat format y iex.bat -S mix. No hace falta cambiar la política del sistema.

Mix inicia Application, que inicia Emergencia.Supervisor. Usa :one_for_one e
inicia UsuarioServer, ZonaServer, NecesidadServer, RecursoServer, PersonaServer,
MascotaServer y AlbergueServer. Cada servidor tiene start_link/1 e init/1;
la API de negocio se construirá módulo por módulo.

## Responsabilidades

| Persona | Rama propuesta | Archivos de lib/emergencia/ |
| --- | --- | --- |
| 1 (integración) | feature/usuarios-zonas | usuario.ex, usuario_server.ex, zona.ex, zona_server.ex, application.ex, supervisor.ex, cli.ex |
| 2 | feature/necesidades-recursos | necesidad.ex, necesidad_server.ex, recurso.ex, recurso_server.ex |
| 3 | feature/personas-mascotas-albergues | persona.ex (incluye Mensaje), persona_server.ex, mascota.ex, mascota_server.ex, albergue.ex, albergue_server.ex, persistencia.ex |

Cada persona añadirá las pruebas de sus módulos. La persona 2 implementará
la prueba de concurrencia. La persona 1 mantiene la prueba de inicio y coordina
mix.exs, emergencia.ex, README.md y reportes.ex con el equipo.
Las ramas están propuestas; no se crearon ramas ni commits en esta etapa.
Evitar modificar archivos de otro integrante: usar su API pública y acordar
los cambios compartidos con quien integra.

## Siguientes etapas

Implementar y revisar módulo por módulo: validaciones, cuatro funciones recursivas,
prioridades de necesidades, inventario concurrente (50 litros frente a solicitudes
de 30 y 25), mensajes, coincidencias de mascotas, cupos de albergues,
persistencia guardar/2 y cargar/1, reportes y menú de consola.
Las pruebas actuales verifican solamente inicio y estado inicial OTP.
