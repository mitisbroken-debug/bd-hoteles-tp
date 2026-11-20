# 2. Arquitectura general

Armada a partir de los archivos `docker-compose.yml` (raíz), `backend/docker-compose.yml`,
`monitoreo/docker-compose.yml` y `n8n/docker-compose.yml`.

## Vista general

```
                         ┌───────────────────────── Internet ─────────────────────────┐
                         │  [PENDIENTE – Seba – túnel y proxy inverso del punto 9]    │
                         └───────────────────────────┬────────────────────────────────┘
                                                     │
   Navegador ──► frontend-hoteles (Nginx, 8090) ─────┤
                                                     ▼
                     (/api y /health)     api-hoteles (Node, sin puerto publicado)
                                           │ escribe            │ lee
                                           ▼                    ▼
                                    db-hoteles ───WAL───►  db-replica
                                    (principal)            (solo lectura)
                                           │
                    ┌──────────────────────┼─────────────────────┐
                    ▼                      ▼                     ▼
              db-backup              pgadmin-hoteles      exportadores de monitoreo
           (pg_dump cada 24 h)   (127.0.0.1:5050)                │
                    │                                            ▼
                    ▼                              Prometheus ──► Alertmanager
            carpeta backups/                            │              │ webhook con token
                    │ solo lectura                      ▼              ▼
                    └──────────────────────────►   Grafana           n8n ──► Mantis (9081), Nextcloud (8085), mail, IA
                                                   (tablero)     (3 flujos)
```

## Redes de Docker

| Red | Quién la crea | Quién está |
|---|---|---|
| `bd-hoteles-tp_red-hoteles` | `docker-compose.yml` de la raíz | Base principal, réplica, pgAdmin, backup, API, frontend, y los exportadores que necesitan ver la base o la API |
| `monitoreo_red` | `monitoreo/docker-compose.yml` | Prometheus, Grafana, Alertmanager y exportadores |
| `n8n_red` | `n8n/docker-compose.yml` | n8n, su ejecutor de código y la base de verificación |
| `red-mantis` | `mantis/docker-compose.yml` | Mantis y su base MariaDB |
| `red-nextcloud` | `nextcloud/docker-compose.yml` | Nextcloud y su base PostgreSQL |

Los servicios se llaman entre sí por nombre dentro de cada red. Entre el monitoreo y n8n no hay
red compartida: Alertmanager y n8n se hablan a través de `host.docker.internal`. Lo mismo n8n con
Mantis (puerto 9081) y con Nextcloud (puerto 8085).

## Flujo de una reserva

1. El navegador carga la página desde `frontend-hoteles`.
2. La página llama a la API (`api-hoteles`).
3. Las lecturas (hoteles, habitaciones, disponibilidad) van a `db-replica`. Si la réplica no
   responde, la API lee del principal. La respuesta trae la cabecera `X-DB-Node` con el nodo usado.
4. Las escrituras (crear, confirmar, cancelar) van siempre a `db-hoteles`.
5. `db-hoteles` manda sus cambios (WAL) a `db-replica` por replicación en streaming asíncrona.

Origen: `backend/src/server.js` (funciones `leer`, `poolWrite`, `poolRead`).

## Flujo de una falla

1. Los exportadores miden cada 15 s. Prometheus evalúa 13 reglas de alerta.
2. Si una regla se cumple el tiempo indicado, Prometheus avisa a Alertmanager.
3. Alertmanager agrupa y manda la alerta al webhook de n8n, con un token.
4. n8n valida, registra la incidencia sin duplicarla, la crea en Mantis y avisa por mail.

Origen: `monitoreo/prometheus/alertas.yml`, `monitoreo/alertmanager/alertmanager.yml`,
`n8n/flujos/01_alertas_infraestructura.json`.

## Lo que todavía no está en la arquitectura

- [PENDIENTE – Seba – punto 9: dominio, túnel de Cloudflare y Traefik como única entrada desde Internet.]
Desde el 20/11/2026 la base, la réplica y la API ya no publican puertos en la PC: solo se ven
dentro de la red de Docker. Desde afuera se entra por el frontend (8090), que reenvía `/api` y
`/health` a la API (`frontend/nginx.conf`). pgAdmin quedó solo en `127.0.0.1`.
