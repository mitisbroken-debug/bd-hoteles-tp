\timing on
\echo '=== Q10 ANTES x2 (con JOIN a hotel)'
SELECT c.nombre, count(DISTINCT hab.id) FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado='confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01' GROUP BY c.nombre;
SELECT c.nombre, count(DISTINCT hab.id) FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado='confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01' GROUP BY c.nombre;
\echo '=== Q10 DESPUES x2 (sin JOIN a hotel)'
SELECT c.nombre, count(DISTINCT hab.id) FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id
WHERE r.estado='confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01' GROUP BY c.nombre;
SELECT c.nombre, count(DISTINCT hab.id) FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id
WHERE r.estado='confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01' GROUP BY c.nombre;

\echo '=== Q3 ANTES x2 (LEFT JOIN)'
SELECT count(*) FROM huesped hu LEFT JOIN reserva r ON r.huesped_id = hu.id WHERE r.id IS NULL;
SELECT count(*) FROM huesped hu LEFT JOIN reserva r ON r.huesped_id = hu.id WHERE r.id IS NULL;
\echo '=== Q3 DESPUES x2 (NOT EXISTS)'
SELECT count(*) FROM huesped hu WHERE NOT EXISTS (SELECT 1 FROM reserva r WHERE r.huesped_id = hu.id);
SELECT count(*) FROM huesped hu WHERE NOT EXISTS (SELECT 1 FROM reserva r WHERE r.huesped_id = hu.id);

\echo '=== Q8 con work_mem alto (evitar derrame a disco)'
SHOW work_mem;
SET work_mem = '256MB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT hu.apellido, hu.nombre, x.reservas, x.gastado
FROM (SELECT r.huesped_id, count(*) AS reservas, sum(tf.monto) AS gastado
      FROM reserva r JOIN tarifa tf ON tf.reserva_id = r.id
      GROUP BY r.huesped_id ORDER BY gastado DESC LIMIT 10) x
JOIN huesped hu ON hu.id = x.huesped_id ORDER BY x.gastado DESC;

\echo '=== Q7 con work_mem alto'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.nombre, t.nombre AS tipo, sum(tf.monto) AS ingresos FROM tarifa tf
JOIN reserva r ON r.id = tf.reserva_id JOIN habitacion hab ON hab.id = r.habitacion_id
JOIN hotel h ON h.id = hab.hotel_id JOIN tipo_habitacion t ON t.id = hab.tipo_habitacion_id
GROUP BY h.nombre, t.nombre ORDER BY ingresos DESC LIMIT 15;

\echo '=== Q6 pre-agregada por habitacion (reduce filas del JOIN de 1.2M a 10.000)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.nombre, h.ciudad, sum(x.n) AS reservas
FROM (SELECT habitacion_id, count(*) AS n FROM reserva WHERE estado='confirmada' GROUP BY habitacion_id) x
JOIN habitacion hab ON hab.id = x.habitacion_id JOIN hotel h ON h.id = hab.hotel_id
GROUP BY h.id, h.nombre, h.ciudad ORDER BY reservas DESC LIMIT 10;
RESET work_mem;

\echo '=== Costo de INSERT: 10.000 filas CON todos los indices (x2), luego sin los redundantes. Todo con ROLLBACK'
BEGIN;
INSERT INTO reserva (habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado)
SELECT g, 1, DATE '2030-01-01', DATE '2030-01-03', 'confirmada' FROM generate_series(1,10000) g;
ROLLBACK;
BEGIN;
INSERT INTO reserva (habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado)
SELECT g, 1, DATE '2030-01-01', DATE '2030-01-03', 'confirmada' FROM generate_series(1,10000) g;
ROLLBACK;
\echo '--- sin idx_reserva_anio, idx_reserva_cobertura, idx_reserva_huesped_cob'
BEGIN;
DROP INDEX idx_reserva_anio;
DROP INDEX idx_reserva_cobertura;
DROP INDEX idx_reserva_huesped_cob;
INSERT INTO reserva (habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado)
SELECT g, 1, DATE '2030-01-01', DATE '2030-01-03', 'confirmada' FROM generate_series(1,10000) g;
ROLLBACK;
SELECT count(*) AS indices_reserva_tras_rollback FROM pg_indexes WHERE tablename='reserva';