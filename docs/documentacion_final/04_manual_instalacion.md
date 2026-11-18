# 4. Manual de instalación

Cómo levantar todo en una PC nueva, en orden. Cada bloque depende del anterior.

## Requisitos

- Windows con Docker Desktop abierto (o Linux con Docker y Docker Compose).
- Git.
- Puertos libres: 5440, 5442, 5050, 3001, 8090, 9090, 3000, 9093 y 5678.
  Para ver qué contenedor ocupa un puerto: `docker ps --format "{{.Names}} {{.Ports}}"`.

## Paso 1 – Clonar el repositorio

```powershell
git clone https://github.com/mitisbroken-debug/bd-hoteles-tp.git
```
```powershell
cd bd-hoteles-tp
```

## Paso 2 – Base de datos, réplica, pgAdmin y backups

Origen: `docs/rol2_base_de_datos.md`, sección 2.

```powershell
copy .env.example .env
```
Editar `.env` y poner las claves (`POSTGRES_PASSWORD`, `PGADMIN_PASSWORD`).

```powershell
docker compose up -d
```
```powershell
docker compose ps
```

La primera vez, la réplica clona toda la base con `pg_basebackup`: con los datos cargados tarda
unos minutos. Avance: `docker compose logs -f db-replica`.

**Nunca usar `docker compose down -v`**: la `-v` borra los volúmenes, es decir, los datos.

## Paso 3 – Cargar los datos de prueba

Ver [06_migracion_y_carga.md](06_migracion_y_carga.md). El esquema se crea solo al levantar la base
por primera vez; los 6.000.000 de reservas hay que cargarlos.

## Paso 4 – API

Origen: `backend/README.md`.

```powershell
docker compose -f backend/docker-compose.yml --env-file .env up -d --build
```
```powershell
curl.exe http://localhost:3001/health
```
Tiene que responder `{"api":"ok","principal":"ok","replica":"ok"}`.

## Paso 5 – Frontend

Origen: `docker-compose.yml` de la rama `develop` (servicio `frontend`). Queda en `http://localhost:8090`.

[PENDIENTE – Fio – en `develop` el compose de la raíz también levanta un segundo backend
(`backend-hoteles`) en el puerto 3001, el mismo de `api-hoteles`. Hasta que quede uno solo, este
paso no se puede escribir como definitivo.]

## Paso 6 – Monitoreo

Origen: `monitoreo/README.md`, sección "Cómo levantarlo en otra PC".

```powershell
cd monitoreo
```
```powershell
copy .env.example .env
```
Completar la clave de Grafana, copiar `POSTGRES_USER`, `POSTGRES_PASSWORD` y `POSTGRES_DB` del
`.env` de la raíz y poner en `RED_HOTELES` el nombre de la red (`bd-hoteles-tp_red-hoteles` si la
carpeta del repo se llama `bd-hoteles-tp`).

```powershell
docker compose up -d
```
Comprobar en `http://localhost:9090/targets` que los 9 targets están en UP.

## Paso 7 – Automatización con n8n

Origen: `n8n/README.md`, sección "Cómo levantarlo en otra PC".

```powershell
cd ..\n8n
```
```powershell
.\preparar.ps1
```
Completar en `n8n\.env` los datos de Brevo y la clave de Gemini.
```powershell
docker compose up -d
```
```powershell
.\importar.ps1
```
```powershell
docker compose -f ..\monitoreo\docker-compose.yml --env-file ..\monitoreo\.env up -d alertmanager
```
Abrir `http://localhost:5678` y crear la cuenta de dueño.

## Paso 8 – Publicación en Internet, Mantis y Nextcloud

- [PENDIENTE – Seba – pasos para levantar el túnel y Traefik (punto 9) y Mantis (punto 11).]
- [PENDIENTE – Fede – pasos para levantar Nextcloud (punto 12).]

Cuando estén, completar sus datos en `n8n\.env` y volver a ejecutar `.\importar.ps1`.

## Paso 9 – Comprobar todo

Desde la raíz del repo:
```powershell
.\scripts\verificar.ps1
```
Muestra una línea por cada pieza, con OK, AVISO o FALLA. No modifica nada.

## Direcciones

| Qué | Dirección |
|---|---|
| Frontend | http://localhost:8090 |
| API | http://localhost:3001/health |
| pgAdmin | http://localhost:5050 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| Alertmanager | http://localhost:9093 |
| n8n | http://localhost:5678 |

## Problemas conocidos al instalar

| Problema | Causa | Solución |
|---|---|---|
| "port is already allocated" | Otro contenedor usa ese puerto | `docker ps` para encontrarlo y detenerlo. Para Grafana, cambiar `GRAFANA_PORT` en `monitoreo/.env` |
| El puerto 80 está ocupado | Contenedores viejos de otros trabajos | `docker ps -a` y detener el que publique `:80->` |
| PowerShell no deja ejecutar `.ps1` | Política de ejecución de Windows | `powershell -ExecutionPolicy Bypass -File .\preparar.ps1` |
| El monitoreo no levanta: "network ... not found" | La base no está levantada o la red tiene otro nombre | Levantar primero el paso 2 y revisar `RED_HOTELES` |
| La API da 503 en `/health` | El nodo principal no responde | `docker compose ps` y `docker compose logs db-hoteles` |
| No se generan backups después de reiniciar la PC | Ver [15_backup_y_restauracion.md](15_backup_y_restauracion.md) | `docker restart db-backup` |
