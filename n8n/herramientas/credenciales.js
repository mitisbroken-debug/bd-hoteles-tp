// Carga las credenciales en n8n a partir del .env (lo ejecuta importar.ps1).
//
// Por qué así: las claves viven solo en el .env. Este programa arma las credenciales,
// se las pasa a n8n y n8n las guarda CIFRADAS en su volumen. Los flujos exportados
// solo nombran la credencial (id y nombre), nunca traen la clave.
//
// Corre en un contenedor que se borra al terminar. El archivo temporal también se borra.

const fs = require('fs');
const { execFileSync } = require('child_process');

const e = process.env;
const faltan = [];

// Devuelve el valor de la variable. Si es obligatoria y está vacía, la anota.
function valor(nombre, obligatoria) {
  const v = (e[nombre] || '').trim();
  if (!v && obligatoria) faltan.push(nombre);
  // n8n no guarda credenciales con campos vacíos: se pone un texto que no sirve como clave.
  return v || 'pendiente';
}

const credenciales = [
  {
    id: 'hiaWebhookAlertas',
    name: 'Webhooks de n8n (token)',
    type: 'httpHeaderAuth',
    data: { name: 'Authorization', value: 'Bearer ' + valor('WEBHOOK_TOKEN', true) },
  },
  {
    id: 'hiaPostgresControl',
    name: 'Postgres de control (n8n_flujos)',
    type: 'postgres',
    data: {
      host: 'db-verificacion',
      database: 'automatizacion',
      user: 'n8n_flujos',
      password: valor('VERIF_N8N_PASSWORD', true),
      port: 5432,
      ssl: 'disable',
    },
  },
  {
    id: 'hiaSmtpAvisos',
    name: 'SMTP de avisos',
    type: 'smtp',
    data: {
      user: valor('SMTP_USER'),
      password: valor('SMTP_PASSWORD'),
      host: valor('SMTP_HOST'),
      port: parseInt(e.SMTP_PORT || '587', 10),
      secure: (e.SMTP_SSL || 'false').trim() === 'true',
    },
  },
  {
    id: 'hiaGemini',
    name: 'Gemini (clave de API)',
    type: 'httpHeaderAuth',
    data: { name: 'x-goog-api-key', value: valor('GEMINI_API_KEY') },
  },
  {
    id: 'hiaMantis',
    name: 'Mantis (token de API)',
    type: 'httpHeaderAuth',
    data: { name: 'Authorization', value: valor('MANTIS_TOKEN') },
  },
  {
    id: 'hiaNextcloud',
    name: 'Nextcloud (usuario y clave de aplicación)',
    type: 'httpBasicAuth',
    data: { user: valor('NEXTCLOUD_USUARIO'), password: valor('NEXTCLOUD_PASSWORD') },
  },
];

if (faltan.length) {
  console.error('Faltan en el .env: ' + faltan.join(', ') + '. Ejecutar preparar.ps1.');
  process.exit(1);
}

const archivo = '/tmp/credenciales.json';
try {
  fs.writeFileSync(archivo, JSON.stringify(credenciales), { mode: 0o600 });
  execFileSync('n8n', ['import:credentials', '--input=' + archivo], { stdio: 'inherit' });
} finally {
  if (fs.existsSync(archivo)) fs.unlinkSync(archivo);
}

// Se informa solo QUÉ quedó cargado, nunca los valores.
const estado = (n) => ((e[n] || '').trim() ? 'cargada' : 'PENDIENTE (falta en el .env)');
console.log('Credenciales en n8n:');
console.log('  Webhooks de n8n    : cargada');
console.log('  Postgres de control: cargada');
console.log('  SMTP de avisos     : ' + estado('SMTP_PASSWORD'));
console.log('  Gemini             : ' + estado('GEMINI_API_KEY'));
console.log('  Mantis             : ' + estado('MANTIS_TOKEN'));
console.log('  Nextcloud          : ' + estado('NEXTCLOUD_PASSWORD'));
