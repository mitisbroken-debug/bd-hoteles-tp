\timing on

\echo '--- 1) NO sargable: funcion aplicada sobre la columna'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;

\echo '--- 2) Sargable: mismo filtro expresado como rango'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';

\echo '--- 3) Verificar que ambas devuelven lo mismo'
SELECT
  (SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020) AS con_funcion,
  (SELECT count(*) FROM reserva WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01') AS con_rango;

\echo '--- 4) Indice funcional (punto 16)'
CREATE INDEX idx_reserva_anio ON reserva ((EXTRACT(YEAR FROM fecha_inicio)));
ANALYZE reserva;

\echo '--- 5) La consulta del punto 1, ahora con indice funcional'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM reserva WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;

\echo '--- tamano del indice funcional'
SELECT pg_size_pretty(pg_relation_size('idx_reserva_anio')) AS tamano;