-- consultas_complejas.sql  (puntos 24-28)
\timing on

\echo '=== Q1 (basica) Reservas confirmadas de 2020, con LIMIT'
SELECT id, habitacion_id, fecha_inicio, fecha_fin
FROM reserva
WHERE estado = 'confirmada' AND fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01'
ORDER BY fecha_inicio LIMIT 20;

\echo '=== Q2 (INNER JOIN, 2 tablas) Habitaciones por hotel'
SELECT h.nombre, count(*) AS habitaciones
FROM hotel h JOIN habitacion hab ON hab.hotel_id = h.id
GROUP BY h.id, h.nombre ORDER BY habitaciones DESC LIMIT 10;

\echo '=== Q3 (LEFT JOIN) Huespedes sin ninguna reserva'
SELECT count(*) FROM huesped hu
LEFT JOIN reserva r ON r.huesped_id = hu.id
WHERE r.id IS NULL;

\echo '=== Q4 (EXISTS) Huespedes con al menos una reserva cancelada'
SELECT count(*) FROM huesped hu
WHERE EXISTS (SELECT 1 FROM reserva r WHERE r.huesped_id = hu.id AND r.estado = 'cancelada');

\echo '=== Q5 (CASE WHEN) Reservas por estado y duracion'
SELECT estado,
       count(*) AS total,
       count(*) FILTER (WHERE fecha_fin - fecha_inicio <= 2) AS cortas,
       count(*) FILTER (WHERE fecha_fin - fecha_inicio BETWEEN 3 AND 7) AS medias,
       count(*) FILTER (WHERE fecha_fin - fecha_inicio > 7) AS largas
FROM reserva GROUP BY estado;

\echo '=== Q6 (4 tablas) Top 10 hoteles por reservas confirmadas'
SELECT h.nombre, h.ciudad, count(*) AS reservas
FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id
JOIN hotel h ON h.id = hab.hotel_id
JOIN tipo_habitacion t ON t.id = hab.tipo_habitacion_id
WHERE r.estado = 'confirmada'
GROUP BY h.id, h.nombre, h.ciudad
ORDER BY reservas DESC LIMIT 10;

\echo '=== Q7 (5 tablas) Ingresos por hotel y tipo de habitacion'
SELECT h.nombre, t.nombre AS tipo, sum(tf.monto) AS ingresos
FROM tarifa tf
JOIN reserva r ON r.id = tf.reserva_id
JOIN habitacion hab ON hab.id = r.habitacion_id
JOIN hotel h ON h.id = hab.hotel_id
JOIN tipo_habitacion t ON t.id = hab.tipo_habitacion_id
GROUP BY h.nombre, t.nombre
ORDER BY ingresos DESC LIMIT 15;

\echo '=== Q8 (4 tablas) Top 10 huespedes por gasto total'
SELECT hu.apellido, hu.nombre, count(*) AS reservas, sum(tf.monto) AS gastado
FROM huesped hu
JOIN reserva r ON r.huesped_id = hu.id
JOIN tarifa tf ON tf.reserva_id = r.id
JOIN habitacion hab ON hab.id = r.habitacion_id
GROUP BY hu.id, hu.apellido, hu.nombre
ORDER BY gastado DESC LIMIT 10;

\echo '=== Q9 (4 tablas) Puntos de interes cercanos (<2km) a los 5 hoteles mas reservados'
SELECT h.nombre, p.nombre AS punto, p.tipo, p.distancia_km, x.reservas
FROM (
  SELECT hab.hotel_id, count(*) AS reservas
  FROM reserva r JOIN habitacion hab ON hab.id = r.habitacion_id
  GROUP BY hab.hotel_id ORDER BY reservas DESC LIMIT 5
) x
JOIN hotel h ON h.id = x.hotel_id
JOIN punto_interes p ON p.hotel_id = h.id
WHERE p.distancia_km < 2
ORDER BY x.reservas DESC, p.distancia_km;

\echo '=== Q10 (5 tablas) Comodidades en habitaciones con reservas confirmadas en 2022'
SELECT c.nombre, count(DISTINCT hab.id) AS habitaciones
FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id
JOIN habitacion_comodidad hc ON hc.habitacion_id = hab.id
JOIN comodidad c ON c.id = hc.comodidad_id
JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado = 'confirmada' AND r.fecha_inicio >= '2022-01-01' AND r.fecha_inicio < '2023-01-01'
GROUP BY c.nombre ORDER BY habitaciones DESC;

\echo '=== Q11 (disponibilidad) Habitaciones libres del hotel 1 entre 2025-07-01 y 2025-07-10'
SELECT hab.id, hab.numero
FROM habitacion hab
WHERE hab.hotel_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM reserva r
    WHERE r.habitacion_id = hab.id
      AND r.estado <> 'cancelada'
      AND r.fecha_inicio < DATE '2025-07-10'
      AND r.fecha_fin    > DATE '2025-07-01'
  )
ORDER BY hab.numero;

\echo '=== Q12 (disponibilidad con operador de rango, usa el GiST)'
SELECT hab.id, hab.numero
FROM habitacion hab
WHERE hab.hotel_id = 1
  AND NOT EXISTS (
    SELECT 1 FROM reserva r
    WHERE r.habitacion_id = hab.id
      AND r.estado <> 'cancelada'
      AND daterange(r.fecha_inicio, r.fecha_fin, '[)') && daterange('2025-07-01','2025-07-10','[)')
  )
ORDER BY hab.numero;

\echo '=== Q13 (temporal) Reservas por mes en 2023'
SELECT date_trunc('month', fecha_inicio)::date AS mes, count(*) AS reservas
FROM reserva
WHERE fecha_inicio >= '2023-01-01' AND fecha_inicio < '2024-01-01'
GROUP BY 1 ORDER BY 1;

\echo '=== Q14 (ocupacion) Noches ocupadas y % por hotel en 2023'
SELECT h.nombre,
       sum(LEAST(r.fecha_fin, DATE '2024-01-01') - GREATEST(r.fecha_inicio, DATE '2023-01-01')) AS noches_ocupadas,
       round(100.0 * sum(LEAST(r.fecha_fin, DATE '2024-01-01') - GREATEST(r.fecha_inicio, DATE '2023-01-01'))
             / (count(DISTINCT hab.id) * 365), 2) AS pct_ocupacion
FROM reserva r
JOIN habitacion hab ON hab.id = r.habitacion_id
JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado <> 'cancelada'
  AND r.fecha_inicio < '2024-01-01' AND r.fecha_fin > '2023-01-01'
GROUP BY h.id, h.nombre
ORDER BY pct_ocupacion DESC LIMIT 10;

\echo '=== Q15 (ranking con ventana) Top 3 hoteles por ciudad segun reservas'
SELECT ciudad, nombre, reservas, rk FROM (
  SELECT h.ciudad, h.nombre, count(*) AS reservas,
         rank() OVER (PARTITION BY h.ciudad ORDER BY count(*) DESC) AS rk
  FROM reserva r
  JOIN habitacion hab ON hab.id = r.habitacion_id
  JOIN hotel h ON h.id = hab.hotel_id
  GROUP BY h.id, h.ciudad, h.nombre
) t WHERE rk <= 3 ORDER BY ciudad, rk;

\echo '=== Q16 (transporte) SELECT * vs columnas necesarias'
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT id, habitacion_id FROM reserva WHERE fecha_inicio >= '2022-01-01' AND fecha_inicio < '2022-07-01';

\echo '=== Q17 (paginacion) OFFSET profundo vs keyset'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, fecha_inicio FROM reserva ORDER BY id LIMIT 20 OFFSET 3000000;
EXPLAIN (ANALYZE, BUFFERS) SELECT id, fecha_inicio FROM reserva WHERE id > 3000000 ORDER BY id LIMIT 20;