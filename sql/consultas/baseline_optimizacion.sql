\timing on
\echo '--- Rango de fechas de los datos'
SELECT min(fecha_inicio) AS desde, max(fecha_fin) AS hasta FROM reserva;

\echo '--- Indices actuales'
SELECT tablename, indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) AS tamano
FROM pg_indexes WHERE schemaname='public' AND tablename IN ('reserva','habitacion','huesped','tarifa')
ORDER BY tablename, indexname;

\echo '--- Q11 con fechas de 2022 (disponibilidad real)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT hab.id, hab.numero FROM habitacion hab
WHERE hab.hotel_id = 1 AND NOT EXISTS (
  SELECT 1 FROM reserva r WHERE r.habitacion_id = hab.id AND r.estado <> 'cancelada'
    AND r.fecha_inicio < DATE '2022-07-10' AND r.fecha_fin > DATE '2022-07-01')
ORDER BY hab.numero;

\echo '--- Q12 con fechas de 2022 (operador &&)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT hab.id, hab.numero FROM habitacion hab
WHERE hab.hotel_id = 1 AND NOT EXISTS (
  SELECT 1 FROM reserva r WHERE r.habitacion_id = hab.id AND r.estado <> 'cancelada'
    AND daterange(r.fecha_inicio, r.fecha_fin,'[)') && daterange('2022-07-01','2022-07-10','[)'))
ORDER BY hab.numero;

\echo '--- Q16 SELECT * (2 veces)'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';
\echo '--- Q16 solo 2 columnas (2 veces)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, habitacion_id FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT id, habitacion_id FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';

\echo '--- Q3 LEFT JOIN huespedes sin reservas'
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM huesped hu LEFT JOIN reserva r ON r.huesped_id = hu.id WHERE r.id IS NULL;

\echo '--- Q6 top hoteles (tiene un JOIN de sobra a tipo_habitacion)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.nombre, h.ciudad, count(*) AS reservas FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN hotel h ON h.id = hab.hotel_id
JOIN tipo_habitacion t ON t.id = hab.tipo_habitacion_id
WHERE r.estado = 'confirmada' GROUP BY h.id, h.nombre, h.ciudad ORDER BY reservas DESC LIMIT 10;

\echo '--- Q7 ingresos por hotel y tipo'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.nombre, t.nombre AS tipo, sum(tf.monto) AS ingresos FROM tarifa tf
JOIN reserva r ON r.id = tf.reserva_id JOIN habitacion hab ON hab.id = r.habitacion_id
JOIN hotel h ON h.id = hab.hotel_id JOIN tipo_habitacion t ON t.id = hab.tipo_habitacion_id
GROUP BY h.nombre, t.nombre ORDER BY ingresos DESC LIMIT 15;

\echo '--- Q8 top huespedes por gasto'
EXPLAIN (ANALYZE, BUFFERS)
SELECT hu.apellido, hu.nombre, count(*) AS reservas, sum(tf.monto) AS gastado
FROM huesped hu JOIN reserva r ON r.huesped_id = hu.id JOIN tarifa tf ON tf.reserva_id = r.id
JOIN habitacion hab ON hab.id = r.habitacion_id
GROUP BY hu.id, hu.apellido, hu.nombre ORDER BY gastado DESC LIMIT 10;

\echo '--- Q10 comodidades 2022'
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, count(DISTINCT hab.id) AS habitaciones FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado = 'confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01'
GROUP BY c.nombre ORDER BY habitaciones DESC;