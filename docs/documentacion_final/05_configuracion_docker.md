# 5. Configuración Docker

El proyecto usa cuatro archivos de Docker Compose, uno por bloque. Así cada integrante puede
levantar y cambiar su parte sin tocar la de los demás.

| Archivo | Proyecto de Compose | Qué levanta | Responsable |
|---|---|---|---|
| `docker-compose.yml` (raíz) | `bd-hoteles-tp` | Base principal, réplica, pgAdmin, backups (y en `develop`, frontend y un backend) | Brian, Fio |
| `backend/docker-compose.yml` | `backend` | API | Brian |
| `monitoreo/docker-compose.yml` | `monitoreo` | Prometheus, Grafana, Alertmanager y 5 exportadores | Juan |
| `n8n/docker-compose.yml` | `n8n-hoteles` | n8n, ejecutor de código, base de verificación | Juan |
| `mantis/docker-compose.yml` | `mantis` | Mantis (9081) y MariaDB | Seba |
| `nextcloud/docker-compose.yml` | `nextcloud-hoteles` | Nextcloud (8085, solo `127.0.0.1`) y PostgreSQL | Fede |

## Servicios

### Base de datos (`docker-compose.yml`)

| Servicio | Imagen | Puerto | Volumen | Notas |
|---|---|---|---|---|
| `db-hoteles` | `postgres:16` | 5440 | `hoteles-data` | Nodo principal. Arranca con `wal_level=replica`, `max_wal_senders=10`, `wal_keep_size=1GB`. Usa un `pg_hba.conf` propio para aceptar a la réplica. Tiene `healthcheck` con `pg_isready` |
| `db-replica` | `postgres:16` | 5442 | `replica-data` | La primera vez clona al principal con `pg_basebackup -R`; después arranca directo como réplica |
| `pgadmin` | `dpage/pgadmin4:latest` | 5050 | `pgadmin-data` | Los dos servidores ya vienen cargados desde `pgadmin/servers.json` |
| `db-backup` | `postgres:16` | — | carpeta `./backups` | `pg_dump -Fc` cada `BACKUP_INTERVAL_SECONDS` (24 h) y guarda los últimos `BACKUP_KEEP` (3) |

El esquema se carga solo la primera vez: `sql/esquema/schema.sql` está montado en
`/docker-entrypoint-initdb.d/`.

### API (`backend/docker-compose.yml` y `backend/Dockerfile`)

| Servicio | Imagen | Puerto | Notas |
|---|---|---|---|
| `api-hoteles` | Construida desde `node:20-alpine` | 3001 → 3000 | Se une a la red de la base como red externa. Recibe por variables el nodo principal, la réplica y las credenciales |

El `Dockerfile` instala solo dependencias de producción (`npm ci --omit=dev`) y corre con el
usuario `node`, no como administrador.

### Frontend (rama `develop`)

| Servicio | Imagen | Puerto |
|---|---|---|
| `frontend` | Construida desde `nginx:alpine` con `frontend/index.html` adentro | 8090 → 80 |

### Monitoreo y n8n

Detalle en `monitoreo/README.md` y `n8n/README.md`. Sus puertos se publican solo en `127.0.0.1`.

## Redes

| Red | Tipo | Para qué |
|---|---|---|
| `bd-hoteles-tp_red-hoteles` | bridge, creada por el compose de la raíz | Comunicación entre base, API y frontend por nombre de servicio |
| `monitoreo_red` | bridge | Componentes del monitoreo |
| `n8n_red` | bridge | n8n y su base de verificación |

Los otros compose usan la red de la base como **externa** (`external: true`), por eso la base
tiene que levantarse primero.

## Volúmenes y persistencia

| Volumen | Qué guarda |
|---|---|
| `hoteles-data` | Datos del nodo principal |
| `replica-data` | Datos de la réplica |
| `pgadmin-data` | Configuración de pgAdmin |
| `./backups` (carpeta) | Los `.dump` de `pg_dump` |
| Volúmenes de `monitoreo` | Series de Prometheus, datos de Grafana y de Alertmanager |
| `n8n-data` | Flujos, credenciales cifradas e historial de n8n |
| `verificacion-data` | Tablas de control de n8n y base de restauración de prueba |

Prueba de persistencia (origen: `docs/rol2_base_de_datos.md`): `docker compose down`,
`docker compose up -d` y contar las filas de `reserva`: da lo mismo que antes.

## Variables y credenciales

Ninguna clave está escrita en los compose ni en el código. Cada bloque tiene un `.env` que
**no se sube a GitHub** (está en `.gitignore`) y un `.env.example` que sí se sube, sin valores reales.

| Archivo | Variables |
|---|---|
| `.env.example` (raíz) | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `PGADMIN_EMAIL`, `PGADMIN_PASSWORD`, `BACKUP_INTERVAL_SECONDS`, `BACKUP_KEEP` |
| `monitoreo/.env.example` | Clave de Grafana, `GRAFANA_PORT`, credenciales de la base para los exportadores, `RED_HOTELES` |
| `n8n/.env.example` | Versión y puerto de n8n, claves internas (se generan solas), SMTP, Gemini, Mantis, Nextcloud |

## Dependencias entre servicios

- `db-replica` y `db-backup` esperan a que `db-hoteles` esté sano (`depends_on` con `service_healthy`).
- `n8n` espera a que su base de verificación esté sana.
- Todos los servicios usan `restart: unless-stopped`: vuelven a arrancar solos al reiniciar Docker.

Atención: `depends_on` solo ordena el arranque cuando se usa `docker compose up`. Cuando Docker
reinicia los contenedores por su cuenta (al reiniciar la PC) no respeta ese orden. Esto afecta
al backup: ver [15_backup_y_restauracion.md](15_backup_y_restauracion.md).

## Desarrollo y despliegue

[PENDIENTE – Fio – la consigna (punto 7) pide separar las configuraciones de desarrollo y de
despliegue. Hoy hay una sola configuración.]

## Pendiente

- [PENDIENTE – Fio – en `develop`, `backend-hoteles` y `api-hoteles` publican los dos el puerto 3001.]
- [PENDIENTE – Seba – compose del túnel y Traefik.]
