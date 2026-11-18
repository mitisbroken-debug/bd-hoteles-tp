# Prepara n8n antes de levantarlo por primera vez (punto 13).
#   1. Crea .env a partir de .env.example (si no existe).
#   2. Genera las 4 claves internas que esten vacias. No las muestra en pantalla.
#   3. Deja el token del webhook en monitoreo/alertmanager/secretos/ para que
#      Alertmanager lo mande en cada alerta.
# Se puede ejecutar mas de una vez: no pisa lo que ya tiene valor.
#
# Uso (PowerShell, parados en la carpeta n8n):   .\preparar.ps1

$ErrorActionPreference = 'Stop'
$carpeta = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $carpeta '.env'
$ejemplo = Join-Path $carpeta '.env.example'
$sinBom  = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $envPath)) {
    Copy-Item $ejemplo $envPath
    Write-Host 'Se creo .env a partir de .env.example'
}

function Nueva-Clave {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

$lineas = [System.IO.File]::ReadAllLines($envPath)
$internas = 'N8N_RUNNERS_AUTH_TOKEN', 'WEBHOOK_TOKEN', 'VERIF_ADMIN_PASSWORD', 'VERIF_N8N_PASSWORD'
$generadas = @()

for ($i = 0; $i -lt $lineas.Count; $i++) {
    foreach ($nombre in $internas) {
        if ($lineas[$i] -match "^$nombre=\s*$") {
            $lineas[$i] = "$nombre=$(Nueva-Clave)"
            $generadas += $nombre
        }
    }
}
[System.IO.File]::WriteAllText($envPath, (($lineas -join "`n") + "`n"), $sinBom)

if ($generadas.Count -gt 0) {
    Write-Host ('Claves generadas: ' + ($generadas -join ', '))
} else {
    Write-Host 'Las claves internas ya estaban generadas.'
}

# Token del webhook para Alertmanager (archivo ignorado por git).
$token = ''
foreach ($l in $lineas) { if ($l -match '^WEBHOOK_TOKEN=(.+)$') { $token = $Matches[1].Trim() } }
$secretos = Join-Path $carpeta '..\monitoreo\alertmanager\secretos'
if (Test-Path (Join-Path $carpeta '..\monitoreo\alertmanager')) {
    New-Item -ItemType Directory -Force -Path $secretos | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $secretos 'webhook_token'), $token, $sinBom)
    Write-Host 'Token del webhook copiado a monitoreo/alertmanager/secretos/webhook_token'
} else {
    Write-Host 'AVISO: no existe la carpeta monitoreo/alertmanager. El token no se copio.'
}

# Que falta completar a mano (solo nombres, nunca valores).
$aMano = 'SMTP_USER', 'SMTP_PASSWORD', 'MAIL_REMITENTE', 'MAIL_DESTINO', 'GEMINI_API_KEY',
         'MANTIS_URL', 'MANTIS_TOKEN', 'MANTIS_PROYECTO', 'NEXTCLOUD_URL', 'NEXTCLOUD_USUARIO', 'NEXTCLOUD_PASSWORD'
$vacias = @()
foreach ($nombre in $aMano) {
    foreach ($l in $lineas) { if ($l -match "^$nombre=\s*$") { $vacias += $nombre } }
}
if ($vacias.Count -gt 0) {
    Write-Host ''
    Write-Host 'Falta completar a mano en n8n\.env:'
    $vacias | ForEach-Object { Write-Host "  - $_" }
    Write-Host 'Sin SMTP no salen los mails. Sin Mantis y Nextcloud los flujos usan el registro local.'
}
Write-Host ''
Write-Host 'Siguiente paso:  docker compose up -d   y despues   .\importar.ps1'
