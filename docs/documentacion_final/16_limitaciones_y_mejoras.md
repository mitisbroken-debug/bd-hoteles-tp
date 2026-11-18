# 16. Limitaciones conocidas y mejoras futuras

Junta las limitaciones que cada parte ya tiene documentadas y las que aparecieron al revisar el
proyecto completo. Estado al 17/11/2026.

## Lo que falta hacer

| Punto | Qué falta | Responsable |
|---|---|---|
| 2 | Tablero de Scrum, backlog, sprints y evidencias | Seba |
| 9 | Publicación en Internet | Seba |
| 11 | Herramienta de incidencias y las 10 incidencias | Seba |
| 12 | Nextcloud, estructura y matriz de permisos | Fede |
| 14 | Informe de seguridad | Fede |

## Limitaciones por componente

### Base de datos y réplica

Origen: `docs/rol2_base_de_datos.md`, sección 6.

| Limitación | Mejora posible |
|---|---|
| No hay failover automático: la promoción de la réplica es manual | Patroni o repmgr, con detección de falla y protección contra dos principales |
| Replicación asíncrona: se pueden perder las últimas transacciones si cae el principal | Replicación síncrona para las operaciones críticas, aceptando escrituras más lentas |
| Si la réplica se atrasa más de 1 GB de WAL hay que clonarla de nuevo | Slot de replicación con un límite, o archivado de WAL |
| Clonar y restaurar 6M de reservas lleva minutos (índice de no superposición) | Particionar `reserva` por fecha (hay una prueba en `rendimiento_y_concurrencia/`) |
| El servidor está en UTC | Fijar la zona horaria `America/Argentina/Jujuy` |
| El backup no se genera al reiniciar la PC | Ver sección 15 |
| Backups en la misma PC, uno por día, sin cifrar | Copia a otro lugar, archivado de WAL, cifrado |

### Aplicación

Origen: `backend/README.md`, sección "Seguridad", y revisión de `develop`.

| Limitación | Mejora posible |
|---|---|
| La API no tiene autenticación ni roles | Login con tokens y permisos por rol |
| No limita la cantidad de pedidos | Límite por IP en la API o en el proxy |
| CORS abierto a cualquier origen | Definir `CORS_ORIGIN` con la dirección del frontend |
| El frontend tiene fija la dirección `localhost:3001` | Que el Nginx del frontend reenvíe `/api` a la API, o configurar la dirección |
| Dos definiciones de la misma API en el puerto 3001 (en `develop`) | Dejar una sola |
| Una sola configuración para desarrollo y despliegue | Archivos de compose separados por entorno |

### CI/CD

| Limitación | Mejora posible |
|---|---|
| El pipeline solo comprueba que la imagen se construya | Pasos de revisión de código, pruebas y `npm audit` |
| Solo se publica la etiqueta `latest` | Etiquetar con el hash del commit para poder volver atrás |
| No hay despliegue automático | Watchtower, como en el material de la cátedra |
| Ramas sin protección; hubo commits directos a `develop` | Exigir Pull Request con revisión |

### Monitoreo

Origen: `monitoreo/README.md`, "Limitaciones conocidas".

| Limitación | Mejora posible |
|---|---|
| Las métricas del sistema son de la máquina virtual de Docker Desktop, no de Windows | En un servidor Linux, node-exporter mide el equipo real |
| No se miden consultas SQL individuales | `pg_stat_statements` con un exportador que lo publique |
| Los exportadores usan el usuario de la aplicación | Usuario de solo lectura con el rol `pg_monitor` |
| No se monitorea la URL pública | Agregar una sonda de blackbox cuando exista |
| Nadie vigila a n8n | Agregarlo como target de Prometheus |
| Las reglas de inhibición no se probaron | Probarlas deteniendo la réplica y el principal |

### Automatización con n8n

Origen: `n8n/README.md`, "Limitaciones conocidas" y "Análisis de riesgos".

| Limitación | Mejora posible |
|---|---|
| Mantis y Nextcloud se probaron solo con un simulador | Repetir las pruebas cuando existan |
| Mail y Gemini reales sin probar | Cargar las claves y probar |
| Un solo token para los 3 webhooks | Un token por webhook |
| La aprobación es por enlace, sin login propio | Aprobación desde el editor de n8n o con usuario y clave |
| Los flujos pueden leer variables de entorno de n8n | Mover esa configuración a un almacén de variables con permisos |
| Historial de ejecuciones en SQLite, 14 días | Base PostgreSQL para n8n y más retención |

## Limitaciones generales

- **Todo corre en una sola PC.** Principal, réplica, backups, monitoreo y automatización
  comparten disco, memoria y corriente. La réplica protege de la caída de un contenedor, no de la
  caída de la máquina. En producción cada pieza iría en equipos distintos.
- **No hay pruebas automáticas** de la aplicación.
- **Es un entorno de práctica**: los datos son sintéticos y las claves de ejemplo se cambian en cada instalación.

## Mejoras futuras, por prioridad

1. Autenticación y roles en la API, antes de dejarla publicada en Internet.
2. Corregir el servicio de backup y copiar los backups fuera de la PC.
3. Pipeline con verificaciones, etiquetas por versión y despliegue automático.
4. Failover automático de la base.
5. Protección de ramas y revisión obligatoria de los Pull Requests.
6. Monitoreo de la URL pública y de n8n.
