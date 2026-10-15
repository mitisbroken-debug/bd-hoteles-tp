\timing on
\echo '--- Indices nuevos (FK sin indice: reserva.huesped_id)'
CREATE INDEX IF NOT EXISTS idx_reserva_huesped ON reserva (huesped_id);
ANALYZE reserva;
SELECT pg_size_pretty(pg_relation_size('idx_reserva_huesped')) AS tamano_idx_huesped;

\echo '--- Q16 despues: solo columnas necesarias (2 veces)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, habitacion_id FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT id, habitacion_id FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';

\echo '--- Q17 despues: keyset en vez de OFFSET (2 veces)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, fecha_inicio FROM reserva WHERE id > 3000000 ORDER BY id LIMIT 20;
EXPLAIN (ANALYZE, BUFFERS) SELECT id, fecha_inicio FROM reserva WHERE id > 3000000 ORDER BY id LIMIT 20;

\echo '--- Q3 despues: NOT EXISTS con indice en huesped_id'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM huesped hu WHERE NOT EXISTS (SELECT 1 FROM reserva r WHERE r.huesped_id = hu.id);

\echo '--- Q6 despues: sin el JOIN de sobra a tipo_habitacion'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.nombre, h.ciudad, count(*) AS reservas FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado = 'confirmada' GROUP BY h.id, h.nombre, h.ciudad ORDER BY reservas DESC LIMIT 10;

\echo '--- Q7 despues: agrupar por IDs y traducir nombres al final'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.nombre, t.nombre AS tipo, x.ingresos
FROM (SELECT hab.hotel_id, hab.tipo_habitacion_id, sum(tf.monto) AS ingresos
      FROM tarifa tf JOIN reserva r ON r.id = tf.reserva_id JOIN habitacion hab ON hab.id = r.habitacion_id
      GROUP BY hab.hotel_id, hab.tipo_habitacion_id) x
JOIN hotel h ON h.id = x.hotel_id JOIN tipo_habitacion t ON t.id = x.tipo_habitacion_id
ORDER BY x.ingresos DESC LIMIT 15;

\echo '--- Q8 despues: agregar por huesped_id y unir huesped solo con el top 10'
EXPLAIN (ANALYZE, BUFFERS)
SELECT hu.apellido, hu.nombre, x.reservas, x.gastado
FROM (SELECT r.huesped_id, count(*) AS reservas, sum(tf.monto) AS gastado
      FROM reserva r JOIN tarifa tf ON tf.reserva_id = r.id
      GROUP BY r.huesped_id ORDER BY gastado DESC LIMIT 10) x
JOIN huesped hu ON hu.id = x.huesped_id ORDER BY x.gastado DESC;

\echo '--- Q10 despues: sin el JOIN de sobra a hotel'
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, count(DISTINCT hab.id) AS habitaciones FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id
WHERE r.estado = 'confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01'
GROUP BY c.nombre ORDER BY habitaciones DESC;