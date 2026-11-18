# 12. Gestión de incidencias

Responsable: Seba.

**[PENDIENTE – Seba – la herramienta (Mantis o GLPI) todavía no está desplegada. Al 17/11/2026
no hay nada de este punto en el repositorio.]**

## Qué tiene que tener esta sección (según la consigna, punto 11)

| Entregable | Estado |
|---|---|
| Herramienta funcionando (cómo levantarla, dirección, usuarios) | [PENDIENTE – Seba] |
| Categorías, prioridades y responsables definidos | [PENDIENTE – Seba] |
| Registro de al menos 10 incidencias reales o reproducibles, una de rendimiento y una de seguridad | [PENDIENTE – Seba] |
| Pasos para reproducir, solución aplicada y verificación de cada una | [PENDIENTE – Seba] |
| Vínculo de las incidencias con tareas y cambios de código | [PENDIENTE – Seba] |
| Evidencias de asignación, seguimiento e historial de resolución | [PENDIENTE – Seba] |

## Lo que ya está hecho del lado de la automatización

El flujo 1 de n8n (sección 13) crea las incidencias solo, a partir de las alertas de Prometheus.
Está listo y probado contra un simulador de la API de Mantis. Cuando Mantis exista, se conecta
completando cuatro datos en `n8n/.env`:

| Variable | Qué es |
|---|---|
| `MANTIS_URL` | Dirección de Mantis vista desde n8n (por ejemplo `http://host.docker.internal:8989`) |
| `MANTIS_TOKEN` | Token de API de un usuario con permiso para reportar (no de un administrador) |
| `MANTIS_PROYECTO` | Nombre del proyecto |
| `MANTIS_CATEGORIA` | Nombre de una categoría existente |

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
| 1 | El backup no se genera después de reiniciar la PC | Disponibilidad | `docker logs db-backup` muestra "Connection refused" y "ERROR, se borra el archivo incompleto" |
| 2 | Dos servicios publican el puerto 3001 | Configuración | En `develop`, `backend-hoteles` y `api-hoteles` usan el 3001 |
| 3 | El frontend llama a `localhost:3001` | Configuración | Abrir la página desde otro dispositivo: no carga datos |
| 4 | La primera ejecución del pipeline falló | CI/CD | Pestaña Actions, ejecución #1 |
| 5 | La API no pide autenticación y acepta cualquier origen | **Seguridad** | `curl.exe http://localhost:3001/api/hoteles` responde sin credenciales; `CORS_ORIGIN` vale `*` |
| 6 | Búsqueda de reservas por huésped sin índice | **Rendimiento** | `rendimiento_y_concurrencia/salida_47_slowlog.txt`: una consulta por huésped tardó más de 4 s antes de crear `idx_reserva_huesped` |
| 7 | El documento de diagnóstico se integró vacío (PR #4, 15/11) | Proceso | Ver `docs/diagnostico.md` en el commit `dfd9b6d`: 0 bytes. **Ya resuelta**: el PR #5 (17/11) agregó el contenido. Sirve como ejemplo de incidencia cerrada con evidencia |
| 8 | La evidencia de carga muestra errores | Datos | `salida_carga.txt` |

[PENDIENTE – Seba – registrarlas en la herramienta con responsable, solución y cierre, y completar hasta 10.]
