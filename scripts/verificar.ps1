# Verificador del TP: revisa de una pasada que cada pieza este funcionando.
# No modifica nada: solo consulta. Sirve antes del ensayo y antes de la defensa.
#
# Uso (PowerShell, desde la raiz del repo):   .\scripts\verificar.ps1
# Termina con codigo 0 si no hay ninguna FALLA.

$ErrorActionPreference = 'SilentlyContinue'
$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:fallas = 0
$script:avisos = 0

function Mostrar($estado, $texto) {
    $color = 'Green'
    if ($estado -eq 'FALLA') { $color = 'Red'; $script:fallas++ }
    if ($estado -eq 'AVISO') { $color = 'Yellow'; $script:avisos++ }
    Write-Host ('[{0,-5}] {1}' -f $estado, $texto) -ForegroundColor $color
}

function Pedir($url) {
    try { return Invoke-RestMethod -Uri $url -TimeoutSec 6 } catch { return $null }
}

function Codigo($url, $metodo = 'GET') {
    try { return [int](Invoke-WebRequest -Uri $url -Method $metodo -TimeoutSec 6 -UseBasicParsing).StatusCode }
    catch { if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode } else { return 0 } }
}

function Sql($contenedor, $consulta) {
    # Usa el usuario y la base que el propio contenedor tiene configurados.
    $cmd = 'psql -U $POSTGRES_USER -d ${POSTGRES_DB:-hoteles} -Atc \"' + $consulta + '\"'
    return (docker exec $contenedor sh -c $cmd 2>$null)
}

Write-Host ''
Write-Host '=== Verificador del TP Final - Reservas de Hoteles ===' -ForegroundColor Cyan

# ---------- 1. Contenedores ----------
Write-Host ''
Write-Host '1. Contenedores' -ForegroundColor Cyan
$corriendo = @(docker ps --format '{{.Names}}')
if ($LASTEXITCODE -ne 0) { Mostrar 'FALLA' 'Docker no responde. Abrir Docker Desktop.'; exit 1 }

$obligatorios = 'db-hoteles', 'db-replica', 'db-backup', 'pgadmin-hoteles', 'api-hoteles',
                'monitoreo-prometheus', 'monitoreo-grafana', 'monitoreo-alertmanager',
                'monitoreo-node-exporter', 'monitoreo-cadvisor', 'monitoreo-blackbox-exporter',
                'monitoreo-postgres-exporter-principal', 'monitoreo-postgres-exporter-replica',
                'n8n-hoteles', 'n8n-runners', 'n8n-db-verificacion'
foreach ($c in $obligatorios) {
    if ($corriendo -contains $c) { Mostrar 'OK' "$c esta corriendo" } else { Mostrar 'FALLA' "$c NO esta corriendo" }
}
if ($corriendo -contains 'frontend-hoteles') { Mostrar 'OK' 'frontend-hoteles esta corriendo' }
else { Mostrar 'AVISO' 'frontend-hoteles no esta corriendo (punto 7)' }

# ---------- 2. Base de datos y replica (puntos 4 y 6) ----------
Write-Host ''
Write-Host '2. Base de datos y replica' -ForegroundColor Cyan
$replicas = Sql 'db-hoteles' "select count(*) from pg_stat_replication where state='streaming'"
if ([int]$replicas -ge 1) { Mostrar 'OK' "Replicacion: $replicas replica en streaming" }
else { Mostrar 'FALLA' 'Replicacion: la principal no tiene ninguna replica en streaming' }

$recovery = Sql 'db-replica' 'select pg_is_in_recovery()'
if ($recovery -eq 't') { Mostrar 'OK' 'db-replica esta en modo replica (solo lectura)' }
else { Mostrar 'FALLA' 'db-replica no esta en modo replica (fue promovida o no responde)' }

$reservas = Sql 'db-hoteles' "select greatest(reltuples, 0)::bigint from pg_class where relname='reserva'"
if ([long]$reservas -ge 6000000) { Mostrar 'OK' "Tabla reserva: aprox. $reservas filas" }
else { Mostrar 'AVISO' "Tabla reserva: aprox. $reservas filas (la consigna pide 6.000.000: falta la carga masiva)" }

$ultimo = Get-ChildItem (Join-Path $raiz 'backups') -Filter 'hoteles_*.dump' | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $ultimo) { Mostrar 'FALLA' 'Backups: no hay ningun archivo en la carpeta backups' }
else {
    $horas = [math]::Round(((Get-Date) - $ultimo.LastWriteTime).TotalHours, 1)
    if ($horas -le 26) { Mostrar 'OK' "Backups: ultimo $($ultimo.Name), hace $horas h" }
    else { Mostrar 'FALLA' "Backups: el ultimo ($($ultimo.Name)) tiene $horas h. Revisar: docker logs db-backup" }
}

# ---------- 3. Aplicacion (punto 7) ----------
Write-Host ''
Write-Host '3. Aplicacion' -ForegroundColor Cyan
$salud = Pedir 'http://localhost:3001/health'
if ($salud -and $salud.principal -eq 'ok' -and $salud.replica -eq 'ok') { Mostrar 'OK' 'API /health: api, principal y replica en ok' }
elseif ($salud) { Mostrar 'FALLA' "API /health responde pero con problemas: principal=$($salud.principal) replica=$($salud.replica)" }
else { Mostrar 'FALLA' 'API /health no responde en http://localhost:3001' }

if ((Codigo 'http://localhost:8090') -eq 200) { Mostrar 'OK' 'Frontend responde en http://localhost:8090' }
else { Mostrar 'AVISO' 'Frontend no responde en http://localhost:8090 (punto 7)' }

# ---------- 4. Monitoreo (punto 10) ----------
Write-Host ''
Write-Host '4. Monitoreo' -ForegroundColor Cyan
$targets = Pedir 'http://127.0.0.1:9090/api/v1/targets'
if ($targets) {
    $todos = @($targets.data.activeTargets)
    $caidos = @($todos | Where-Object { $_.health -ne 'up' })
    if ($caidos.Count -eq 0) { Mostrar 'OK' "Prometheus: $($todos.Count) de $($todos.Count) targets en up" }
    else { Mostrar 'FALLA' ("Prometheus: targets caidos: " + (($caidos | ForEach-Object { $_.labels.job }) -join ', ')) }
} else { Mostrar 'FALLA' 'Prometheus no responde en http://127.0.0.1:9090' }

$reglas = Pedir 'http://127.0.0.1:9090/api/v1/rules'
if ($reglas) { Mostrar 'OK' "Prometheus: $(@($reglas.data.groups.rules).Count) reglas de alerta cargadas" }

$alertas = Pedir 'http://127.0.0.1:9090/api/v1/alerts'
if ($alertas) {
    $activas = @($alertas.data.alerts | Where-Object { $_.state -eq 'firing' })
    if ($activas.Count -eq 0) { Mostrar 'OK' 'Prometheus: ninguna alerta activa' }
    else { Mostrar 'AVISO' ('Prometheus: alertas activas: ' + (($activas | ForEach-Object { $_.labels.alertname }) -join ', ')) }
}

$grafana = Pedir 'http://127.0.0.1:3000/api/health'
if ($grafana -and $grafana.database -eq 'ok') { Mostrar 'OK' "Grafana responde (version $($grafana.version))" }
else { Mostrar 'FALLA' 'Grafana no responde en http://127.0.0.1:3000 (ver GRAFANA_PORT en monitoreo/.env)' }

if ((Codigo 'http://127.0.0.1:9093/-/healthy') -eq 200) { Mostrar 'OK' 'Alertmanager responde' }
else { Mostrar 'FALLA' 'Alertmanager no responde en http://127.0.0.1:9093' }

# ---------- 5. Automatizacion con n8n (punto 13) ----------
Write-Host ''
Write-Host '5. Automatizacion (n8n)' -ForegroundColor Cyan
if ((Codigo 'http://localhost:5678/healthz') -eq 200) { Mostrar 'OK' 'n8n responde en http://localhost:5678' }
else { Mostrar 'FALLA' 'n8n no responde en http://localhost:5678' }

# Sin token, los 3 webhooks tienen que rechazar el pedido con 403.
# 403 = el flujo esta activo y protegido. 404 = el flujo no esta importado o publicado.
foreach ($ruta in 'alertas-prometheus', 'verificar-backups', 'informe-rendimiento') {
    $c = Codigo "http://localhost:5678/webhook/$ruta" 'POST'
    if ($c -eq 403) { Mostrar 'OK' "Webhook $ruta activo y rechaza pedidos sin token (403)" }
    elseif ($c -eq 404) { Mostrar 'FALLA' "Webhook $ruta no existe: ejecutar n8n\importar.ps1" }
    else { Mostrar 'FALLA' "Webhook $ruta respondio $c sin token (se esperaba 403)" }
}

if (Test-Path (Join-Path $raiz 'monitoreo\alertmanager\secretos\webhook_token')) { Mostrar 'OK' 'Alertmanager tiene el token del webhook' }
else { Mostrar 'FALLA' 'Falta monitoreo\alertmanager\secretos\webhook_token: ejecutar n8n\preparar.ps1' }

# ---------- Resumen ----------
Write-Host ''
if ($script:fallas -eq 0) {
    Write-Host "RESULTADO: todo en orden ($($script:avisos) aviso/s)." -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULTADO: $($script:fallas) falla/s y $($script:avisos) aviso/s. Revisar las lineas en rojo." -ForegroundColor Red
    exit 1
}
