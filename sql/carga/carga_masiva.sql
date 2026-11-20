-- =========================================================
-- Carga masiva de datos de prueba
-- Objetivo: ~6.000.000 de registros en la tabla "reserva"
-- Estrategia: generación set-based con generate_series,
-- sin colisiones de fechas por construcción (no al azar)
-- =========================================================

\timing on

-- ---------- 1) Catálogos base ----------

INSERT INTO tipo_habitacion (nombre, descripcion) VALUES
    ('Individual', 'Habitación para una persona'),
    ('Doble', 'Habitación para dos personas'),
    ('Triple', 'Habitación para tres personas'),
    ('Suite', 'Habitación superior con sala de estar'),
    ('Familiar', 'Habitación amplia para grupos familiares');

INSERT INTO comodidad (nombre) VALUES
    ('WiFi'), ('Aire acondicionado'), ('TV por cable'), ('Minibar'),
    ('Balcón'), ('Vista al mar'), ('Jacuzzi'), ('Caja fuerte'),
    ('Desayuno incluido'), ('Servicio a la habitación');

-- ---------- 2) Hoteles (50) ----------

INSERT INTO hotel (nombre, descripcion, estrellas, direccion, ciudad, pais, codigo_postal, latitud, longitud)
SELECT
    'Hotel ' || gs,
    'Hotel genérico número ' || gs || ' generado para pruebas de carga',
    (floor(random() * 5) + 1)::smallint,
    'Calle ' || gs || ' Nº ' || (100 + gs),
    (ARRAY['Buenos Aires','Córdoba','Rosario','Mendoza','Salta','Bariloche'])[floor(random() * 6 + 1)],
    'Argentina',
    lpad((1000 + gs)::text, 5, '0'),
    -34 + random() * 10,
    -65 + random() * 10
FROM generate_series(1, 50) gs;

-- ---------- 3) Contactos y puntos de interés por hotel ----------

INSERT INTO hotel_contacto (hotel_id, tipo, valor)
SELECT id, 'telefono', '+54 11 ' || lpad((4000000 + id)::text, 8, '0') FROM hotel
UNION ALL
SELECT id, 'email', 'contacto' || id || '@hotel.com' FROM hotel;

INSERT INTO punto_interes (hotel_id, nombre, tipo, distancia_km)
SELECT h.id, 'Punto de interés ' || gs, (ARRAY['museo','restaurante','playa','parque'])[floor(random()*4+1)], round((random()*5)::numeric, 2)
FROM hotel h CROSS JOIN generate_series(1, 3) gs;

-- ---------- 4) Habitaciones (200 por hotel = 10.000 habitaciones) ----------

INSERT INTO habitacion (hotel_id, tipo_habitacion_id, numero, piso, capacidad)
SELECT
    h.id,
    (floor(random() * 5) + 1)::bigint,
    lpad(n::text, 4, '0'),
    (n / 20) + 1,
    (floor(random() * 4) + 1)::smallint
FROM hotel h CROSS JOIN generate_series(1, 200) n;

-- ---------- 5) Comodidades por habitación (relación N:M) ----------

INSERT INTO habitacion_comodidad (habitacion_id, comodidad_id)
SELECT hb.id, c.id
FROM habitacion hb CROSS JOIN comodidad c
WHERE random() < 0.4   -- cada habitación tiene ~40% de probabilidad por comodidad (~4 de 10)
ON CONFLICT DO NOTHING;

-- ---------- 6) Huéspedes (500.000) ----------

INSERT INTO huesped (nombre, apellido, documento, fecha_nacimiento)
SELECT
    (ARRAY['Juan','María','Carlos','Ana','Luis','Laura','Diego','Sofía','Pedro','Lucía'])[floor(random()*10+1)],
    (ARRAY['Gómez','Fernández','Rodríguez','López','Martínez','García','Pérez','Sánchez','Romero','Díaz'])[floor(random()*10+1)],
    (20000000 + gs)::text,
    DATE '1950-01-01' + (random() * 25000)::int
FROM generate_series(1, 500000) gs;

INSERT INTO huesped_contacto (huesped_id, tipo, valor)
SELECT id, 'email', 'huesped' || id || '@mail.com' FROM huesped
UNION ALL
SELECT id, 'telefono', '+54 9 ' || lpad((1000000000 + id)::bigint::text, 10, '0') FROM huesped;

INSERT INTO huesped_domicilio (huesped_id, direccion, ciudad, pais, codigo_postal)
SELECT id, 'Av. Siempre Viva ' || id, 'Buenos Aires', 'Argentina', '1000'
FROM huesped;

-- ---------- 7) Reservas (6.000.000) — sin colisiones por construcción ----------

-- Por rendimiento, quitamos temporalmente la restricción de no-superposición:
-- los datos se generan SIN solapamiento por diseño (ver explicación abajo),
-- así que no hace falta que Postgres valide cada fila contra el índice GiST
-- durante la carga masiva. La volvemos a crear al final para demostrar que
-- los datos cumplen la regla y medir el costo de construir el índice sobre 6M filas.

ALTER TABLE reserva DROP CONSTRAINT reserva_habitacion_id_daterange_excl;

WITH parametros AS (
    SELECT 6000000::bigint AS total_reservas
),
habitaciones_count AS (
    SELECT count(*) AS n_habitaciones FROM habitacion
),
reservas_por_habitacion AS (
    SELECT ceil(p.total_reservas::numeric / h.n_habitaciones)::int AS n
    FROM parametros p, habitaciones_count h
),
secuencia AS (
    SELECT
        hb.id AS habitacion_id,
        gs AS rn,
        (floor(random() * 7) + 1)::int AS largo_estadia,     -- 1 a 7 noches
        (floor(random() * 3) + 1)::int AS dias_hueco          -- 1 a 3 días libres entre reservas
    FROM habitacion hb
    CROSS JOIN LATERAL generate_series(1, (SELECT n FROM reservas_por_habitacion)) AS gs
),
con_offset AS (
    SELECT
        habitacion_id,
        rn,
        largo_estadia,
        COALESCE(
            SUM(largo_estadia + dias_hueco) OVER (
                PARTITION BY habitacion_id ORDER BY rn
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0
        ) AS offset_dias
    FROM secuencia
)
INSERT INTO reserva (habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado, fecha_creacion)
SELECT
    habitacion_id,
    (floor(random() * 500000) + 1)::bigint,
    DATE '2015-01-01' + offset_dias::int,
    DATE '2015-01-01' + offset_dias::int + largo_estadia,
    CASE
        WHEN random() < 0.60 THEN 'confirmada'
        WHEN random() < 0.85 THEN 'pendiente'
        ELSE 'cancelada'
    END,
    now() - (random() * interval '365 days')
FROM con_offset
LIMIT 6000000;

-- Recrear la restricción y confirmar que los datos generados la cumplen
ALTER TABLE reserva
    ADD CONSTRAINT reserva_habitacion_id_daterange_excl
    EXCLUDE USING gist (
        habitacion_id WITH =,
        daterange(fecha_inicio, fecha_fin, '[)') WITH &&
    ) WHERE (estado <> 'cancelada');

-- ---------- 8) Tarifas (solo para reservas confirmadas) ----------

INSERT INTO tarifa (reserva_id, monto, moneda, fecha_confirmacion)
SELECT id, round((50 + random() * 450)::numeric, 2), 'USD', fecha_creacion + (random() * interval '2 days')
FROM reserva
WHERE estado = 'confirmada';

\timing off