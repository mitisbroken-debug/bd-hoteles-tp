# 14. Informe de seguridad

Responsable: Fede.

**[PENDIENTE – Fede – el informe de seguridad del punto 14 todavía no está en el repositorio.]**

Esta sección reúne los **controles de seguridad que ya existen** en el proyecto, cada uno con el
archivo donde se puede comprobar, y los **hallazgos** detectados al revisar el repositorio. Sirve
de base para el informe, pero no lo reemplaza.

## Entregables de la consigna

| Entregable | Estado |
|---|---|
| Matriz de amenazas | [PENDIENTE – Fede] |
| Informe de vulnerabilidades | [PENDIENTE – Fede]. Abajo hay hallazgos para incluir |
| Evidencias de escaneo y corrección | [PENDIENTE – Fede] |
| Resultados de pruebas controladas | [PENDIENTE – Fede]. Las de n8n ya están hechas (sección 13) |
| Configuración de controles de seguridad | Parcial: abajo están los que ya existen |
| Procedimiento de respuesta y recuperación | [PENDIENTE – Fede]. La recuperación de la base está en las secciones 8 y 15 |
| Evidencias del flujo de incidentes integrado con n8n | Hecho: flujo 1 de n8n (sección 13 y `n8n/README.md`) |

La consigna pide considerar: ransomware, DDoS, robo de credenciales, vulnerabilidades de
dependencias, ataques a la cadena de suministro, inyección SQL, fallas de autorización, abuso de
API y webhooks, y riesgos de sistemas de IA.

## Controles que ya existen

### Aplicación

Origen: `backend/src/server.js` y `backend/README.md`.

| Amenaza | Control |
|---|---|
| Inyección SQL | Todas las consultas usan parámetros (`$1`, `$2`). No se arma SQL con texto del usuario |
| Datos inválidos | Se validan antes de llegar a la base: enteros positivos y fechas reales con formato `AAAA-MM-DD` |
| Pedidos gigantes | Límite de 10 KB por pedido (`express.json({ limit: '10kb' })`) |
| Consultas que no terminan | Límite de 10 s por consulta (`statement_timeout`) |
| Fuga de información en errores | Los errores internos devuelven "Error interno", sin detalles |
| Identificación del servidor | Se quita la cabecera `X-Powered-By` |
| Reservas superpuestas | Lo impide la base con una restricción `EXCLUDE`, no depende de la API |

### Docker e infraestructura

| Amenaza | Control | Origen |
|---|---|---|
| Robo de credenciales desde el repo | Claves solo en archivos `.env`, ignorados por git. En el repo hay `.env.example` sin valores | `.gitignore`, `monitoreo/.gitignore`, `n8n/.gitignore` |
| Contenedor de la API comprometido | Corre con el usuario `node`, no como administrador, y solo con dependencias de producción | `backend/Dockerfile` |
| Acceso a herramientas de administración | Prometheus, Grafana, Alertmanager y n8n se publican solo en `127.0.0.1`. Grafana sin acceso anónimo ni registro | `monitoreo/docker-compose.yml`, `n8n/docker-compose.yml` |
| Recarga o apagado remoto de Prometheus | No se activa `--web.enable-lifecycle` | `monitoreo/README.md` |
| Imágenes que cambian sin aviso | Versiones fijas en monitoreo y n8n | `monitoreo/docker-compose.yml`, `n8n/docker-compose.yml` |
| Contenedores con privilegios | En n8n se descartó el *sandbox* del instalador, que usa `privileged: true` | `n8n/README.md` |
| Pérdida de datos (falla o ransomware) | Backups automáticos con verificación y restauración de prueba; réplica en otro contenedor | Secciones 8 y 15 |
| Conexión de réplica sin clave | La replicación entre contenedores pide clave (`scram-sha-256`) | `docker-compose.yml` |

### Automatizaciones (n8n)

Origen: `n8n/README.md`, "Requisitos de seguridad" y "Análisis de riesgos".

| Amenaza | Control |
|---|---|
| Abuso de webhooks | Token obligatorio (403 sin él), validación de datos, tope de alertas por aviso |
| Credenciales con demasiado permiso | Usuario de base sin borrado ni administración; token de Mantis de un usuario que solo reporta |
| Acciones automáticas peligrosas | Ningún flujo detiene ni reinicia servicios. La restauración pide aprobación humana |
| Riesgos de IA | La IA no decide números ni estados; recibe solo métricas de infraestructura, sin datos personales; el informe sale aunque falle |

### CI/CD y cadena de suministro

| Amenaza | Control | Origen |
|---|---|---|
| Fuga de credenciales del pipeline | Usuario y clave de Docker Hub en GitHub Secrets | `.github/workflows/docker-ci-cd.yml` (rama `develop`) |
| Publicar un cambio que no compila | Si el `docker build` falla, no se publica; en Pull Requests no se publica | Ídem |
| Dependencias vulnerables | `backend/README.md` indica que `npm audit` no informa vulnerabilidades. Las versiones están fijas en `package.json` y `package-lock.json` | `backend/` |

## Hallazgos detectados en la revisión del 16 y 17/11/2026

Para incluir en el informe de vulnerabilidades, con su corrección o su justificación.

| # | Hallazgo | Dónde | Riesgo |
|---|---|---|---|
| 1 | La API no tiene autenticación ni control de roles | `backend/src/server.js` | Cualquiera que llegue a la API puede crear y cancelar reservas. Se agrava al publicarla en Internet |
| 2 | CORS acepta cualquier origen (`CORS_ORIGIN` vale `*` por defecto) | `backend/docker-compose.yml` | Cualquier página web puede llamar a la API desde el navegador de un usuario |
| 3 | La API no limita la cantidad de pedidos | `backend/README.md` lo menciona como mejora | Abuso de API, DDoS a nivel de aplicación |
| 4 | Los puertos de la base (5440, 5442) y de pgAdmin (5050) se publican en todas las interfaces | `docker-compose.yml` | Se ven desde cualquier máquina de la misma red. La consigna pide no exponer la base ni las interfaces administrativas |
| 5 | `pgadmin4:latest` y `nginx:alpine` no tienen versión fija | `docker-compose.yml`, `frontend/Dockerfile` | La imagen puede cambiar entre un despliegue y otro (cadena de suministro) |
| 6 | El pipeline no escanea imágenes ni dependencias | `.github/workflows/docker-ci-cd.yml` | Una dependencia vulnerable llegaría a publicarse |
| 7 | Los exportadores de monitoreo usan el mismo usuario de la aplicación | `monitoreo/.env.example` (está anotado como pendiente) | Más permiso del necesario. Debería ser un usuario de solo lectura con el rol `pg_monitor` |
| 8 | El historial tiene commits directos a `develop` sin revisión | Historial de Git | Un cambio sin revisar puede llegar a la rama de integración |
| 9 | Dentro de la red de Docker, las conexiones locales al principal usan `trust` | `docker-compose.yml` (`pg_hba.conf`) | Solo aplica a conexiones desde el propio contenedor. Las conexiones por red sí piden clave |

## Lo que falta

- [PENDIENTE – Fede – matriz de amenazas con probabilidad, impacto y control para cada una de las
  amenazas que nombra la consigna.]
- [PENDIENTE – Fede – evidencia de escaneo (dependencias e imágenes) y de la corrección de lo encontrado.]
- [PENDIENTE – Fede – pruebas controladas sobre la aplicación (por ejemplo, intento de inyección
  SQL contra la API, pedidos masivos, acceso a puertos administrativos desde otra máquina).]
- [PENDIENTE – Fede – procedimiento de respuesta ante incidentes: detección, contención,
  recuperación y registro.]
- [PENDIENTE – Seba – HTTPS y control de acceso de la publicación en Internet (punto 9).]
