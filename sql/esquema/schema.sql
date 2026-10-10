-- =========================================================
-- Esquema: Sistema de Reservas de Hoteles
-- Motor: PostgreSQL
-- =========================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------- HOTEL ----------
CREATE TABLE hotel (
    id              BIGSERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    estrellas       SMALLINT CHECK (estrellas BETWEEN 1 AND 5),
    direccion       VARCHAR(200) NOT NULL,
    ciudad          VARCHAR(100) NOT NULL,
    pais            VARCHAR(100) NOT NULL,
    codigo_postal   VARCHAR(20),
    latitud         NUMERIC(9,6),
    longitud        NUMERIC(9,6),
    fecha_alta      TIMESTAMP NOT NULL DEFAULT now()
);

-- Un hotel puede tener varios teléfonos/emails (1FN: no repetir columnas)
CREATE TABLE hotel_contacto (
    id          BIGSERIAL PRIMARY KEY,
    hotel_id    BIGINT NOT NULL REFERENCES hotel(id) ON DELETE CASCADE,
    tipo        VARCHAR(20) NOT NULL CHECK (tipo IN ('telefono','email')),
    valor       VARCHAR(150) NOT NULL,
    UNIQUE (hotel_id, tipo, valor)
);

-- Puntos de interés cercanos a cada hotel
CREATE TABLE punto_interes (
    id              BIGSERIAL PRIMARY KEY,
    hotel_id        BIGINT NOT NULL REFERENCES hotel(id) ON DELETE CASCADE,
    nombre          VARCHAR(150) NOT NULL,
    tipo            VARCHAR(50),              -- ej: museo, restaurante, playa
    distancia_km    NUMERIC(5,2) CHECK (distancia_km >= 0)
);

-- ---------- HABITACIONES ----------
CREATE TABLE tipo_habitacion (
    id          BIGSERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,   -- ej: Individual, Doble, Suite
    descripcion TEXT
);

CREATE TABLE habitacion (
    id                  BIGSERIAL PRIMARY KEY,
    hotel_id            BIGINT NOT NULL REFERENCES hotel(id) ON DELETE CASCADE,
    tipo_habitacion_id  BIGINT NOT NULL REFERENCES tipo_habitacion(id),
    numero              VARCHAR(10) NOT NULL,
    piso                SMALLINT,
    capacidad           SMALLINT NOT NULL CHECK (capacidad > 0),
    UNIQUE (hotel_id, numero)
);

CREATE TABLE comodidad (
    id      BIGSERIAL PRIMARY KEY,
    nombre  VARCHAR(50) NOT NULL UNIQUE          -- ej: WiFi, Aire acondicionado
);

-- Relación N:M entre habitación y comodidad
CREATE TABLE habitacion_comodidad (
    habitacion_id   BIGINT NOT NULL REFERENCES habitacion(id) ON DELETE CASCADE,
    comodidad_id    BIGINT NOT NULL REFERENCES comodidad(id) ON DELETE CASCADE,
    PRIMARY KEY (habitacion_id, comodidad_id)
);

-- ---------- HUÉSPEDES ----------
CREATE TABLE huesped (
    id                  BIGSERIAL PRIMARY KEY,
    nombre              VARCHAR(100) NOT NULL,
    apellido            VARCHAR(100) NOT NULL,
    documento           VARCHAR(30) NOT NULL UNIQUE,
    fecha_nacimiento    DATE,
    fecha_alta          TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE huesped_contacto (
    id          BIGSERIAL PRIMARY KEY,
    huesped_id  BIGINT NOT NULL REFERENCES huesped(id) ON DELETE CASCADE,
    tipo        VARCHAR(20) NOT NULL CHECK (tipo IN ('telefono','email')),
    valor       VARCHAR(150) NOT NULL,
    UNIQUE (huesped_id, tipo, valor)
);

CREATE TABLE huesped_domicilio (
    id              BIGSERIAL PRIMARY KEY,
    huesped_id      BIGINT NOT NULL REFERENCES huesped(id) ON DELETE CASCADE,
    direccion       VARCHAR(200) NOT NULL,
    ciudad          VARCHAR(100) NOT NULL,
    pais            VARCHAR(100) NOT NULL,
    codigo_postal   VARCHAR(20)
);

-- ---------- RESERVAS Y TARIFAS ----------
CREATE TABLE reserva (
    id              BIGSERIAL PRIMARY KEY,
    habitacion_id   BIGINT NOT NULL REFERENCES habitacion(id),
    huesped_id      BIGINT NOT NULL REFERENCES huesped(id),
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE NOT NULL CHECK (fecha_fin > fecha_inicio),
    estado          VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente','confirmada','cancelada')),
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT now(),

    -- Regla de negocio clave: una habitación no puede tener reservas
    -- (activas) que se superpongan en el tiempo.
    EXCLUDE USING gist (
        habitacion_id WITH =,
        daterange(fecha_inicio, fecha_fin, '[)') WITH &&
    ) WHERE (estado <> 'cancelada')
);

-- La tarifa solo existe cuando la reserva se confirma
CREATE TABLE tarifa (
    id                  BIGSERIAL PRIMARY KEY,
    reserva_id          BIGINT NOT NULL UNIQUE REFERENCES reserva(id) ON DELETE CASCADE,
    monto               NUMERIC(10,2) NOT NULL CHECK (monto >= 0),
    moneda              CHAR(3) NOT NULL DEFAULT 'USD',
    fecha_confirmacion  TIMESTAMP NOT NULL DEFAULT now()
);