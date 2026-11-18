# 1. Descripción de la aplicación

## Qué es

Un sistema de reservas para una cadena de hoteles. Permite ver los hoteles y sus habitaciones,
consultar disponibilidad en un rango de fechas y crear, confirmar y cancelar reservas.

Tiene tres partes:

| Parte | Qué hace | Origen del dato |
|---|---|---|
| Base de datos | PostgreSQL 16 con 12 tablas. Guarda hoteles, habitaciones, huéspedes, reservas y tarifas | `sql/esquema/schema.sql` |
| API | Node.js con Express. Expone 8 rutas REST. Escribe en el nodo principal y lee de la réplica | `backend/src/server.js`, `backend/README.md` |
| Frontend | Una página web ("Red Hoteles Argentina") servida por Nginx, que llama a la API | `frontend/index.html`, `frontend/Dockerfile` (rama `develop`) |

## Funcionalidades

Sale de `backend/README.md` y `backend/src/server.js`.

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/health` | Estado de la API, del nodo principal y de la réplica |
| GET | `/api/hoteles` | Lista de hoteles |
| GET | `/api/habitaciones?hotel_id=1` | Habitaciones de un hotel |
| GET | `/api/disponibilidad?hotel_id=1&desde=...&hasta=...` | Habitaciones libres en un rango de fechas |
| GET | `/api/reservas?huesped_id=123` | Últimas 50 reservas de un huésped |
| POST | `/api/reservas` | Crea una reserva (queda `pendiente`) |
| PATCH | `/api/reservas/:id/confirmar` | Confirma una reserva pendiente |
| PATCH | `/api/reservas/:id/cancelar` | Cancela una reserva |

Desde el frontend (rama `develop`, `frontend/index.html`): elegir un hotel, ver sus habitaciones
como tarjetas, reservar cargando los datos del huésped y obtener un comprobante.

## Modelo de datos

12 tablas (`sql/esquema/schema.sql`):

| Grupo | Tablas |
|---|---|
| Hoteles | `hotel`, `hotel_contacto`, `punto_interes` |
| Habitaciones | `tipo_habitacion`, `habitacion`, `comodidad`, `habitacion_comodidad` |
| Huéspedes | `huesped`, `huesped_contacto`, `huesped_domicilio` |
| Reservas | `reserva`, `tarifa` |

La regla de negocio más importante está en la base y no en la API: **una habitación no puede
tener dos reservas activas que se superpongan**. Lo garantiza una restricción `EXCLUDE USING gist`
sobre `habitacion_id` y el rango de fechas, para las reservas que no están canceladas. Si se
intenta, PostgreSQL devuelve el error `23P01` y la API responde `409`.

Otras reglas del esquema: `fecha_fin > fecha_inicio`, estado dentro de
(`pendiente`, `confirmada`, `cancelada`), documento de huésped único, y la tarifa existe solo
cuando la reserva se confirma.

## Diagnóstico inicial y plan de mejoras (punto 1 de la consigna)

Responsable: Fede. El documento completo está en [`docs/diagnostico.md`](../diagnostico.md)
(integrado a `develop` el 17/11/2026, Pull Request #5).

Qué cubre, contra lo que pide la consigna:

| Entregable del punto 1 | Dónde está en `docs/diagnostico.md` |
|---|---|
| Descripción de la aplicación | Sección 1, con el volumen de datos por tabla |
| Lista de funcionalidades | Sección 2: los 8 endpoints, el nodo de base que usa cada uno y las reglas de negocio |
| Inventario del stack tecnológico | Sección 3, y la infraestructura (contenedores y puertos) en la sección 4 |
| Diagrama inicial de arquitectura | Sección 5 (diagrama Mermaid) |
| Componentes a contenerizar | Sección 6 |
| Diagnóstico técnico y plan de mejoras | Sección 7: fortalezas y 12 mejoras con área y prioridad |

Las mejoras de prioridad alta del plan son: autenticación en la API; CORS restringido, límite de
pedidos y registro de accesos; ruta relativa a la API en el frontend; publicar solo lo necesario;
usuarios de base separados (aplicación y monitoreo); verificar la restricción de no superposición;
pruebas y escaneo en el pipeline con etiqueta por commit y rollback; y probar la restauración de
backups con tiempos.

[PENDIENTE – Fede – el documento está marcado como "borrador para revisión del equipo" y tiene
ítems marcados "(confirmar)". También quedaron datos de antes del 17/11: la rama
`feature/publicacion-internet` (ya fue borrada) y n8n como pendiente (ya está hecho, punto 13).]
