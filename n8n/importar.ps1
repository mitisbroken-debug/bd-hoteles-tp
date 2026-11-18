# Carga en n8n las credenciales (desde .env) y los 3 flujos (desde la carpeta flujos).
# n8n tiene que estar levantado:  docker compose up -d
# Se puede ejecutar de nuevo cada vez que cambie el .env o un flujo: actualiza, no duplica.
#
# Uso (PowerShell, parados en la carpeta n8n):   .\importar.ps1

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host '1/4  Cargando credenciales desde .env (quedan cifradas dentro de n8n)...'
docker compose --profile herramientas run --rm n8n-credenciales
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR al cargar credenciales. Revisar .env (ejecutar preparar.ps1).'; exit 1 }

Write-Host '2/4  Importando los 3 flujos...'
docker compose exec -T n8n n8n import:workflow --separate --input=/flujos
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR al importar los flujos. Esta levantado n8n?'; exit 1 }

Write-Host '3/4  Publicando (activando) los flujos...'
foreach ($id in 'hia13Alertas0001', 'hia13Backups0002', 'hia13Informe0003') {
    docker compose exec -T n8n n8n publish:workflow --id=$id
}

Write-Host '4/4  Reiniciando n8n para que tome los cambios...'
docker compose restart n8n

Write-Host ''
Write-Host 'Listo. Editor: http://localhost:5678  (la primera vez pide crear la cuenta de dueno).'
