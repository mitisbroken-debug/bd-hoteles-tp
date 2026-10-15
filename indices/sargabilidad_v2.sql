\timing on
DROP INDEX IF EXISTS idx_reserva_anio;
ANALYZE reserva;

\echo '--- A) NO sargable, sin indice funcional (corrida 1: fria)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;
\echo '--- A) NO sargable (corrida 2: caliente)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;

\echo '--- B) Sargable por rango (corrida 2: caliente)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';

\echo '--- C) Indice funcional'
CREATE INDEX idx_reserva_anio ON reserva ((EXTRACT(YEAR FROM fecha_inicio)));
ANALYZE reserva;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;
SELECT pg_size_pretty(pg_relation_size('idx_reserva_anio')) AS tamano_idx_funcional;