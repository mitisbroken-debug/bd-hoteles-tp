# 3. Inventario tecnológico

Las versiones salen de los archivos indicados en cada fila.

## Aplicación

| Capa | Tecnología | Versión | Origen |
|---|---|---|---|
| Base de datos | PostgreSQL | 16 (imagen `postgres:16`; en ejecución, 16.15) | `docker-compose.yml` |
| Extensión de la base | `btree_gist` | la de PostgreSQL 16 | `sql/esquema/schema.sql` |
| Backend | Node.js | 20 (imagen `node:20-alpine`) | `backend/Dockerfile` |
| Backend | Express | 4.22.3 | `backend/package.json` |
| Backend | pg (cliente de PostgreSQL) | 8.23.1 | `backend/package.json` |
| Frontend | HTML, CSS y JavaScript sin framework | — | `frontend/index.html` (rama `develop`) |
| Servidor web del frontend | Nginx | `nginx:alpine` (sin versión fija) | `frontend/Dockerfile` (rama `develop`) |

## Infraestructura y herramientas

| Para qué | Herramienta | Versión | Origen |
|---|---|---|---|
| Contenedores | Docker y Docker Compose | Docker Desktop | — |
| Administración de la base | pgAdmin 4 | `dpage/pgadmin4:latest` (sin versión fija) | `docker-compose.yml` |
| Backups | `pg_dump` y `pg_restore` | los de `postgres:16` | `docker-compose.yml` |
| Métricas | Prometheus | v3.16.0 | `monitoreo/docker-compose.yml` |
| Tableros | Grafana | 13.2.6 | `monitoreo/docker-compose.yml` |
| Alertas | Alertmanager | v0.35.0 | `monitoreo/docker-compose.yml` |
| Métricas del sistema | node-exporter | v1.12.1 | `monitoreo/docker-compose.yml` |
| Métricas de contenedores | cAdvisor | v0.60.6 | `monitoreo/docker-compose.yml` |
| Métricas de PostgreSQL | postgres-exporter (2, uno por nodo) | v0.20.1 | `monitoreo/docker-compose.yml` |
| Disponibilidad de la API | blackbox-exporter | v0.29.1 | `monitoreo/docker-compose.yml` |
| Automatización | n8n y su ejecutor de código | 2.45.7 | `n8n/docker-compose.yml` |
| Base de control de n8n | PostgreSQL | 16 | `n8n/docker-compose.yml` |
| Gestión de incidencias | MantisBT | `vimagick/mantisbt` (sin versión fija) | `mantis/docker-compose.yml` |
| Base de Mantis | MariaDB | 10.11 | `mantis/docker-compose.yml` |
| Gestión documental | Nextcloud | 33.0.5 (apache) | `nextcloud/docker-compose.yml` |
| Base de Nextcloud | PostgreSQL | 16 (alpine) | `nextcloud/docker-compose.yml` |
| CI/CD | GitHub Actions | `checkout@v4`, `setup-buildx-action@v3`, `login-action@v3` | `.github/workflows/docker-ci-cd.yml` (rama `develop`) |
| Registro de imágenes | Docker Hub | — | `.github/workflows/docker-ci-cd.yml` (rama `develop`) |
| Control de versiones | Git y GitHub | — | — |

## Servicios externos

| Servicio | Para qué | Estado |
|---|---|---|
| Brevo (SMTP) | Mails de aviso de n8n | Configurado en `n8n/.env.example`. Falta la prueba con la cuenta real |
| Gemini (API de Google) | Análisis del informe de rendimiento | Configurado. Falta la prueba con la clave real |
| Docker Hub | Publicar las imágenes del pipeline | En uso (rama `develop`) |

## Puertos en la PC

| Puerto | Servicio | Se ve desde |
|---|---|---|
| 5440 | PostgreSQL principal | Todas las interfaces |
| 5442 | PostgreSQL réplica | Todas las interfaces |
| 5050 | pgAdmin | Todas las interfaces |
| 3001 | API | Todas las interfaces |
| 8090 | Frontend (rama `develop`) | Todas las interfaces |
| 9090 | Prometheus | Solo `127.0.0.1` |
| 3000 | Grafana (cambia con `GRAFANA_PORT`) | Solo `127.0.0.1` |
| 9093 | Alertmanager | Solo `127.0.0.1` |
| 5678 | n8n | Solo `127.0.0.1` |
| 9081 | Mantis | Todas las interfaces |
| 8085 | Nextcloud | Solo `127.0.0.1` |

## Pendiente

- [PENDIENTE – Seba – herramientas del punto 9 (Traefik, cloudflared, dominio).]
- [PENDIENTE – Fede – herramientas de escaneo de seguridad (punto 14).]
- [PENDIENTE – Seba – herramienta de gestión del proyecto (punto 2).]
- [PENDIENTE – Brian – herramienta de análisis de la base que pide el punto 4 (por ejemplo pgBadger); en el repo no hay ninguna.]
