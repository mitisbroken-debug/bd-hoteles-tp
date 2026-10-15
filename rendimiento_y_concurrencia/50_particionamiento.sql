\timing on

CREATE TABLE reserva_part (LIKE reserva INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
  PARTITION BY RANGE (fecha_inicio);

DO $$
BEGIN
  FOR y IN 2015..2026 LOOP
    EXECUTE format('CREATE TABLE reserva_p%s PARTITION OF reserva_part FOR VALUES FROM (%L) TO (%L)',
                   y, y||'-01-01', (y+1)||'-01-01');
  END LOOP;
END $$;
CREATE TABLE reserva_p_default PARTITION OF reserva_part DEFAULT;

INSERT INTO reserva_part SELECT * FROM reserva;

ALTER TABLE reserva_part ADD PRIMARY KEY (id, fecha_inicio);
CREATE INDEX idx_rp_fecha ON reserva_part (fecha_inicio);
ANALYZE reserva_part;

SELECT 'reserva' AS tabla, pg_size_pretty(pg_total_relation_size('reserva')) AS total
UNION ALL SELECT 'reserva_part', pg_size_pretty(pg_total_relation_size('reserva_part'));
SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS tam
FROM pg_class WHERE relname LIKE 'reserva_p%' AND relkind = 'r' ORDER BY relname;

EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM reserva
 WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM reserva
 WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM reserva_part
 WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM reserva_part
 WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';

BEGIN;
DELETE FROM reserva WHERE fecha_inicio >= '2020-01-01' AND fecha_inicio < '2021-01-01';
ROLLBACK;
BEGIN;
DROP TABLE reserva_p2020;
ROLLBACK;
