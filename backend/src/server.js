'use strict';

const express = require('express');
const { Pool, types } = require('pg');

// Las fechas (DATE) se devuelven como texto "YYYY-MM-DD" y no como objetos Date,
// para que no cambien por la zona horaria.
types.setTypeParser(1082, (v) => v);
// Los ids son BIGINT: se devuelven como numero (y no como texto) para que el frontend los use directo.
types.setTypeParser(20, (v) => parseInt(v, 10));

const PORT = parseInt(process.env.PORT || '3000', 10);
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

const base = {
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  max: 10,
  connectionTimeoutMillis: 3000,
  statement_timeout: 10000,
};

// Escrituras -> nodo principal. Lecturas -> replica (con respaldo al principal si la replica no responde).
const poolWrite = new Pool({ ...base, host: process.env.DB_HOST_PRIMARY || 'db-hoteles' });
const poolRead = new Pool({ ...base, host: process.env.DB_HOST_REPLICA || 'db-replica' });
poolWrite.on('error', (e) => console.error('[pg principal]', e.message));
poolRead.on('error', (e) => console.error('[pg replica]', e.message));

const ERRORES_DE_CONEXION = ['ECONNREFUSED', 'ENOTFOUND', 'ETIMEDOUT', 'ECONNRESET', 'EAI_AGAIN'];

function esErrorDeConexion(e) {
  if (ERRORES_DE_CONEXION.includes(e.code)) return true;
  if (!e.code) return true; // timeout de conexion del pool
  return /^(08|53|57)/.test(e.code); // clases de error de PostgreSQL: conexion, recursos, apagado
}

async function leer(res, sql, params) {
  try {
    const r = await poolRead.query(sql, params);
    res.set('X-DB-Node', 'replica');
    return r;
  } catch (e) {
    if (!esErrorDeConexion(e)) throw e;
    console.warn('[lectura] replica no disponible, se usa el principal:', e.message);
    const r = await poolWrite.query(sql, params);
    res.set('X-DB-Node', 'principal (respaldo)');
    return r;
  }
}

// ---------- validaciones ----------
function entero(v) {
  const n = Number(v);
  return Number.isInteger(n) && n > 0 && n < 9007199254740991 ? n : null;
}

function fecha(v) {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return null;
  const d = new Date(v + 'T00:00:00Z');
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v ? v : null;
}

class ErrorHttp extends Error {
  constructor(status, mensaje) {
    super(mensaje);
    this.status = status;
  }
}

const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);

// ---------- app ----------
const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '10kb' }));
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', CORS_ORIGIN);
  res.set('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.get('/health', wrap(async (req, res) => {
  const estado = { api: 'ok' };
  try {
    await poolWrite.query('SELECT 1');
    estado.principal = 'ok';
  } catch (e) {
    estado.principal = 'caido';
  }
  try {
    await poolRead.query('SELECT 1');
    estado.replica = 'ok';
  } catch (e) {
    estado.replica = 'caida';
  }
  res.status(estado.principal === 'ok' ? 200 : 503).json(estado);
}));

app.get('/api/hoteles', wrap(async (req, res) => {
  const r = await leer(res, 'SELECT id, nombre, ciudad FROM hotel ORDER BY id LIMIT 100', []);
  res.json(r.rows);
}));

app.get('/api/habitaciones', wrap(async (req, res) => {
  const hotelId = entero(req.query.hotel_id);
  if (!hotelId) throw new ErrorHttp(400, 'hotel_id es obligatorio y debe ser un numero');
  const r = await leer(res,
    `SELECT hab.id, hab.numero, th.nombre AS tipo, hab.capacidad
       FROM habitacion hab
       JOIN tipo_habitacion th ON th.id = hab.tipo_habitacion_id
      WHERE hab.hotel_id = $1
      ORDER BY hab.numero
      LIMIT 100`, [hotelId]);
  res.json(r.rows);
}));

app.get('/api/disponibilidad', wrap(async (req, res) => {
  const hotelId = entero(req.query.hotel_id);
  const desde = fecha(req.query.desde);
  const hasta = fecha(req.query.hasta);
  if (!hotelId || !desde || !hasta) {
    throw new ErrorHttp(400, 'hotel_id, desde y hasta (YYYY-MM-DD) son obligatorios');
  }
  if (hasta <= desde) throw new ErrorHttp(400, 'hasta tiene que ser posterior a desde');
  const r = await leer(res,
    `SELECT hab.id, hab.numero, th.nombre AS tipo, hab.capacidad
       FROM habitacion hab
       JOIN tipo_habitacion th ON th.id = hab.tipo_habitacion_id
      WHERE hab.hotel_id = $1
        AND NOT EXISTS (
              SELECT 1 FROM reserva r
               WHERE r.habitacion_id = hab.id
                 AND r.estado <> 'cancelada'
                 AND r.fecha_inicio < $3::date
                 AND r.fecha_fin    > $2::date)
      ORDER BY hab.numero
      LIMIT 100`, [hotelId, desde, hasta]);
  res.json(r.rows);
}));

app.get('/api/reservas', wrap(async (req, res) => {
  const huespedId = entero(req.query.huesped_id);
  if (!huespedId) throw new ErrorHttp(400, 'huesped_id es obligatorio y debe ser un numero');
  const r = await leer(res,
    `SELECT r.id, r.fecha_inicio, r.fecha_fin, r.estado,
            h.nombre AS hotel, h.ciudad, hab.numero AS habitacion
       FROM reserva r
       JOIN habitacion hab ON hab.id = r.habitacion_id
       JOIN hotel h        ON h.id   = hab.hotel_id
      WHERE r.huesped_id = $1
      ORDER BY r.fecha_inicio DESC
      LIMIT 50`, [huespedId]);
  res.json(r.rows);
}));

app.post('/api/reservas', wrap(async (req, res) => {
  const b = req.body || {};
  const habitacionId = entero(b.habitacion_id);
  const huespedId = entero(b.huesped_id);
  const inicio = fecha(b.fecha_inicio);
  const fin = fecha(b.fecha_fin);
  if (!habitacionId || !huespedId || !inicio || !fin) {
    throw new ErrorHttp(400, 'habitacion_id, huesped_id, fecha_inicio y fecha_fin (YYYY-MM-DD) son obligatorios');
  }
  if (fin <= inicio) throw new ErrorHttp(400, 'fecha_fin tiene que ser posterior a fecha_inicio');
  const r = await poolWrite.query(
    `INSERT INTO reserva (habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado)
     VALUES ($1, $2, $3, $4, 'pendiente')
     RETURNING id, habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado`,
    [habitacionId, huespedId, inicio, fin]);
  res.set('X-DB-Node', 'principal').status(201).json(r.rows[0]);
}));

app.patch('/api/reservas/:id/confirmar', wrap(async (req, res) => {
  const id = entero(req.params.id);
  if (!id) throw new ErrorHttp(400, 'id invalido');
  const r = await poolWrite.query(
    `UPDATE reserva SET estado = 'confirmada'
      WHERE id = $1 AND estado = 'pendiente'
      RETURNING id, habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado`, [id]);
  if (r.rowCount === 0) throw new ErrorHttp(404, 'La reserva no existe o no esta pendiente');
  const t = await poolWrite.query('SELECT monto FROM tarifa WHERE reserva_id = $1', [id]);
  res.set('X-DB-Node', 'principal').json({ ...r.rows[0], tarifa: t.rows[0] ? t.rows[0].monto : null });
}));

app.patch('/api/reservas/:id/cancelar', wrap(async (req, res) => {
  const id = entero(req.params.id);
  if (!id) throw new ErrorHttp(400, 'id invalido');
  const r = await poolWrite.query(
    `UPDATE reserva SET estado = 'cancelada'
      WHERE id = $1 AND estado <> 'cancelada'
      RETURNING id, habitacion_id, huesped_id, fecha_inicio, fecha_fin, estado`, [id]);
  if (r.rowCount === 0) throw new ErrorHttp(404, 'La reserva no existe o ya esta cancelada');
  res.set('X-DB-Node', 'principal').json(r.rows[0]);
}));

app.use((req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err instanceof ErrorHttp) return res.status(err.status).json({ error: err.message });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON invalido' });
  switch (err.code) {
    case '23P01': return res.status(409).json({ error: 'La habitacion ya esta reservada en esas fechas' });
    case '23503': return res.status(400).json({ error: 'La habitacion o el huesped no existen' });
    case '23514':
    case '23502': return res.status(400).json({ error: 'Datos invalidos' });
    case '25006': return res.status(503).json({ error: 'El nodo no acepta escrituras en este momento' });
    default:
      console.error('[error]', err.message);
      return res.status(500).json({ error: 'Error interno' });
  }
});

const server = app.listen(PORT, () => console.log(`API de hoteles escuchando en el puerto ${PORT}`));

function cerrar() {
  server.close(async () => {
    await Promise.allSettled([poolWrite.end(), poolRead.end()]);
    process.exit(0);
  });
}
process.on('SIGTERM', cerrar);
process.on('SIGINT', cerrar);
