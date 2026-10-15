SHOW enable_partition_pruning;

EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM reserva_part
 WHERE fecha_inicio BETWEEN '2020-01-01' AND '2020-12-31';
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM reserva
 WHERE fecha_inicio BETWEEN '2020-01-01' AND '2020-12-31';

CREATE INDEX idx_rp_huesped ON reserva_part (huesped_id);
ANALYZE reserva_part;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM reserva_part WHERE huesped_id = 12345;

EXPLAIN SELECT count(*) FROM reserva_part WHERE EXTRACT(YEAR FROM fecha_inicio) = 2020;

SET enable_partition_pruning = off;
EXPLAIN SELECT count(*) FROM reserva_part
 WHERE fecha_inicio BETWEEN '2020-01-01' AND '2020-12-31';
RESET enable_partition_pruning;
