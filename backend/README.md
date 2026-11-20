# API de reservas (backend)

API minima en Node.js (Express) sobre la base de hoteles. Sirve de backend para el frontend y demuestra
que la aplicacion usa la arquitectura de replicacion (punto 6.5 del TP).

## Como se conecta a la base
- **Escrituras** (crear, confirmar y cancelar reservas) van al nodo principal `db-hoteles`.
- **Lecturas** (listados y disponibilidad) van a la replica `db-replica`.
- Si la replica no responde, la lectura se hace en el principal. La respuesta trae el header `X-DB-Node`
  (`replica`, `principal` o `principal (respaldo)`) para ver a que nodo fue.
- Como la replicacion es asincrona, una reserva recien creada puede tardar unos milisegundos en verse en las lecturas.

## Como levantarla
Desde la **raiz del repo**, con la base ya levantada (`docker compose up -d`):
```
docker compose -f backend/docker-compose.yml --env-file .env up -d --build
docker compose -f backend/docker-compose.yml ps
```
Queda en `http://localhost:3001`. Usa las credenciales del `.env` de la raiz (no hay claves en el codigo).

## Endpoints

| Metodo | Ruta | Que hace |
|---|---|---|
| GET | `/health` | Estado de la API, del principal y de la replica |
| GET | `/api/hoteles` | Lista de hoteles |
| GET | `/api/habitaciones?hotel_id=1` | Habitaciones de un hotel |
| GET | `/api/disponibilidad?hotel_id=1&desde=2027-01-10&hasta=2027-01-15` | Habitaciones libres en un rango |
| GET | `/api/reservas?huesped_id=123` | Ultimas 50 reservas de un huesped |
| POST | `/api/reservas` | Crea una reserva (queda `pendiente`) |
| PATCH | `/api/reservas/:id/confirmar` | Confirma una reserva pendiente |
| PATCH | `/api/reservas/:id/cancelar` | Cancela una reserva |

Cuerpo de `POST /api/reservas` (JSON):
```
{"habitacion_id": 1, "huesped_id": 1, "fecha_inicio": "2027-03-01", "fecha_fin": "2027-03-05"}
```
Errores: `400` datos invalidos, `404` reserva inexistente, `409` la habitacion ya esta reservada en esas fechas
(lo decide la restriccion EXCLUDE de la base, no la API).

## Pruebas rapidas (PowerShell)
```
curl.exe -i http://localhost:3001/health
curl.exe -i http://localhost:3001/api/hoteles
curl.exe -i "http://localhost:3001/api/disponibilidad?hotel_id=1&desde=2027-03-01&hasta=2027-03-05"
Invoke-RestMethod -Method Post -Uri http://localhost:3001/api/reservas -ContentType "application/json" -Body '{"habitacion_id":1,"huesped_id":1,"fecha_inicio":"2027-03-01","fecha_fin":"2027-03-05"}'
```
Repetir el ultimo comando da `409` (ya esta reservada). Confirmar: `Invoke-RestMethod -Method Patch -Uri http://localhost:3001/api/reservas/ID/confirmar`
(con el id devuelto al crearla). La tarifa se asigna al confirmar.

## Seguridad
- Todas las consultas usan parametros (`$1`, `$2`): no hay SQL armado con texto del usuario.
- Los parametros se validan antes de llegar a la base (numeros enteros y fechas reales).
- Limite de tamano del cuerpo (10 KB) y timeout de 10 s por consulta.
- Los errores internos no muestran detalles al cliente.
- Dependencias sin vulnerabilidades conocidas (`npm audit`). Falta, como mejora futura: autenticacion, limite de pedidos y HTTPS (lo resuelve el proxy o el tunel).
