\timing on

\echo '--- ANTES (1ra corrida, caché fría): índice simple por huésped'
EXPLAIN (ANALYZE, BUFFERS)
SELECT fecha_inicio, fecha_fin, estado FROM reserva WHERE huesped_id = 12345;

\echo '--- ANTES (2da corrida, caché caliente)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT fecha_inicio, fecha_fin, estado FROM reserva WHERE huesped_id = 12345;

CREATE INDEX idx_reserva_huesped_cob ON reserva (huesped_id) INCLUDE (fecha_inicio, fecha_fin, estado);
ANALYZE reserva;

\echo '--- DESPUES (1ra corrida)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT fecha_inicio, fecha_fin, estado FROM reserva WHERE huesped_id = 12345;

\echo '--- DESPUES (2da corrida, caché caliente)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT fecha_inicio, fecha_fin, estado FROM reserva WHERE huesped_id = 12345;

SELECT indexrelname AS indice, pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE relname = 'reserva'
ORDER BY pg_relation_size(indexrelid) DESC;