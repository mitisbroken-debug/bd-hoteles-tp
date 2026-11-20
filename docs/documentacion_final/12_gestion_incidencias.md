# 12. Gestión de incidencias

Responsable: Seba.

Mantis está en `develop` desde el 18/11/2026: carpeta `mantis/` (compose, README, respaldo de la
base `mantis_final.sql` y `documentacion_incidencias_mantis.docx`).

## Qué tiene que tener esta sección (según la consigna, punto 11)

| Entregable | Estado |
|---|---|
| Herramienta funcionando | MantisBT con MariaDB en Docker, http://localhost:9081 (`mantis/docker-compose.yml`) |
| Categorías, prioridades y responsables | Proyecto "BD Hoteles TP" con 8 categorías: Base de datos, Backend/API, Rendimiento, Seguridad, Concurrencia, Índices, Infraestructura, Documentación (`mantis/README.md`) |
| Al menos 10 incidencias, una de rendimiento y una de seguridad | 10 incidencias en el `.docx`: rendimiento (0000003) y seguridad (0000001 y 0000007) |
| Pasos para reproducir, solución y verificación | Las soluciones están en el `.docx`. [PENDIENTE – Seba – ver la nota de abajo] |
| Vínculo con tareas y cambios de código | Tabla de trazabilidad en el `.docx`. [PENDIENTE – Seba – ver la nota de abajo] |
| Evidencias de asignación, seguimiento e historial | En Mantis (respaldo `mantis_final.sql`) |

El 20/11/2026 se corrigieron en el `.docx` las incidencias 0000003 a 0000007: ahora citan commits
que existen (`5c94a8d`, `247b468`, `21b3126`, `fe69faf`).
[PENDIENTE – Seba – la 0000010 sigue describiendo la resolución de un conflicto de fusión; conviene
que cite el commit que quitó el backend duplicado (`247b468`).]

Prueba real del 20/11/2026: una alerta de prueba enviada a Alertmanager creó en Mantis la
incidencia 11 ("[PruebaMantisReal] …", proyecto BD Hoteles TP, categoría Infraestructura),
reportada por el usuario `n8n` (informador) con su token de API.

## Lo que ya está hecho del lado de la automatización

El flujo 1 de n8n (sección 13) crea las incidencias solo, a partir de las alertas de Prometheus.
Está probado contra un simulador de la API de Mantis; falta repetir la prueba contra el Mantis
real. Se conecta completando cuatro datos en `n8n/.env`:

| Variable | Qué es |
|---|---|
| `MANTIS_URL` | `http://host.docker.internal:9081` (Mantis vista desde n8n) |
| `MANTIS_TOKEN` | Token de API de un usuario con permiso para reportar, no de un administrador (Mi cuenta → Tokens de API) |
| `MANTIS_PROYECTO` | `BD Hoteles TP` |
| `MANTIS_CATEGORIA` | `Infraestructura` |

Mientras tanto, las incidencias quedan en la tabla `incidencias_alertas` de la base de control
de n8n y se avisan por mail.

### Qué manda n8n a Mantis

Origen: `n8n/flujos/01_alertas_infraestructura.json`.

- **Al crear** (`POST /api/rest/issues`): resumen con el nombre de la alerta, descripción con
  instancia, severidad, impacto, urgencia, hora de inicio y dónde mirar; proyecto, categoría y prioridad.
- **Al resolverse** (`POST /api/rest/issues/{id}/notes`): una nota avisando que la alerta se
  resolvió. **No cierra la incidencia**: el cierre lo hace una persona, con evidencia.

### Cómo se calcula la prioridad

Con impacto y urgencia, como en la unidad de Gestión de Incidentes de la materia.

| Impacto \ Urgencia | alta | media | baja |
|---|---|---|---|
| alto | urgente (`urgent`) | alta (`high`) | normal |
| medio | alta (`high`) | normal | baja (`low`) |
| bajo | normal | baja (`low`) | baja (`low`) |

El impacto depende de qué se rompe (si el usuario no puede reservar, es alto) y la urgencia, de
la severidad de la regla de Prometheus. Entre paréntesis, el nombre de la prioridad en Mantis.

### Cómo se evitan los duplicados

Si ya hay una incidencia abierta para la misma alerta en la misma instancia, no se crea otra: se
suma una repetición. Es el paso "comprobar que el incidente aún no ha sido registrado" del
proceso de registro.

## Incidencias reales del proyecto que se pueden registrar

Detectadas durante la revisión del 16 y 17/11/2026. Sirven como parte de las 10 que pide la consigna:

| # | Incidencia | Tipo | Cómo reproducirla |
|---|---|---|---|
| 1 | El backup no se generaba después de reiniciar la PC | Disponibilidad | Lo detectó el flujo 2 de n8n (backup de 95 h). **Resuelta** el 20/11: `db-backup` espera con `pg_isready` |
| 2 | Dos servicios publicaban el puerto 3001 | Configuración | **Resuelta** en `247b468` (19/11): queda solo `api-hoteles` |
| 3 | El frontend llamaba a `localhost:3001` | Configuración | **Resuelta** el 20/11: Nginx reenvía `/api` y la página usa una ruta relativa |
| 4 | La primera ejecución del pipeline falló | CI/CD | Pestaña Actions, ejecución #1 |
| 5 | La API no pedía autenticación y aceptaba cualquier origen | **Seguridad** | **Resuelta** el 20/11: las rutas de reservas piden token (`/api/auth/login`) y `CORS_ORIGIN` es `http://localhost:8090` por defecto |
| 6 | Búsqueda de reservas por huésped sin índice | **Rendimiento** | `rendimiento_y_concurrencia/salida_47_slowlog.txt`: una consulta por huésped tardó más de 4 s antes de crear `idx_reserva_huesped` |
| 7 | El documento de diagnóstico se integró vacío (PR #4, 15/11) | Proceso | Ver `docs/diagnostico.md` en el commit `dfd9b6d`: 0 bytes. **Ya resuelta**: el PR #5 (17/11) agregó el contenido. Sirve como ejemplo de incidencia cerrada con evidencia |
| 8 | La evidencia de carga muestra errores | Datos | `salida_carga.txt` |

[PENDIENTE – Seba – registrarlas en la herramienta con responsable, solución y cierre, y completar hasta 10.]
