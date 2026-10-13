\timing on

-- ===== PUNTO 14: índice compuesto y regla del prefijo izquierdo =====
CREATE INDEX idx_reserva_hab_fecha ON reserva (habitacion_id, fecha_inicio);
ANALYZE reserva;

\echo '--- A) usa las dos columnas'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM reserva
WHERE habitacion_id = 500 AND fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';

\echo '--- B) solo la primera columna (prefijo izquierdo)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM reserva WHERE habitacion_id = 500;

\echo '--- C) solo la segunda columna, sin el índice simple de fecha (ROLLBACK lo restaura)'
BEGIN;
DROP INDEX idx_reserva_fecha_inicio;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE fecha_inicio BETWEEN '2020-01-01' AND '2020-01-31';
ROLLBACK;

-- ===== PUNTO 15: índice de cobertura =====
\echo '--- D) consulta que necesita fecha_fin y estado, con el compuesto normal'
EXPLAIN (ANALYZE, BUFFERS)
SELECT fecha_inicio, fecha_fin, estado FROM reserva
WHERE habitacion_id = 500 AND fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';

CREATE INDEX idx_reserva_cobertura ON reserva (habitacion_id, fecha_inicio) INCLUDE (fecha_fin, estado);
ANALYZE reserva;

\echo '--- D) la misma consulta con el índice de cobertura'
EXPLAIN (ANALYZE, BUFFERS)
SELECT fecha_inicio, fecha_fin, estado FROM reserva
WHERE habitacion_id = 500 AND fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';

-- ===== PUNTO 17: cardinalidad según el optimizador =====
\echo '--- cardinalidad (n_distinct negativo = fracción de las filas)'
SELECT attname AS columna, n_distinct
FROM pg_stats
WHERE tablename = 'reserva' AND attname IN ('habitacion_id','huesped_id','fecha_inicio','estado');

-- ===== Tamaño de todos los índices =====
SELECT indexrelname AS indice, pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE relname = 'reserva'
ORDER BY pg_relation_size(indexrelid) DESC;