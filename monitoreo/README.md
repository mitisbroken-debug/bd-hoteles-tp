# Monitoreo (punto 10): Prometheus + Grafana

Esta carpeta tiene todo el monitoreo del sistema de reservas de hoteles: la base de datos
(principal + réplica), la API y los contenedores. Tiene su propio `docker-compose.yml` y no
modifica nada de las otras carpetas del repo.

## En números

Para no confundir: **contenedores** son los que levanta este `docker-compose.yml`; **targets**
son las direcciones a las que Prometheus les pide métricas. No es lo mismo: Prometheus se mide
a sí mismo, los dos postgres-exporter son dos targets del mismo job, y blackbox aparece dos
veces (como exportador y como sonda de la API).

| Qué | Cantidad | Cómo verificarlo |
|---|---|---|
| Contenedores del monitoreo | **8** | `docker ps --filter name=monitoreo-` |
| Targets de Prometheus | **9** (todos UP) | http://localhost:9090/targets o `curl -s http://localhost:9090/api/v1/targets` |
| Reglas de alerta | **13** en 3 grupos (disponibilidad 7, sistema 3, contenedores 3) | http://localhost:9090/alerts o `/api/v1/rules` |
| Dashboards en Grafana | **4** (1 propio + 3 de la comunidad) | Grafana > Dashboards |
| Paneles del dashboard propio | **36** paneles en 6 filas | Abrir "Hoteles - Visión general" |
| Intervalo de scrape y de evaluación de alertas | **15 s** (timeout de scrape 10 s) | http://localhost:9090/config |
| Retención de datos en Prometheus | **15 días** | http://localhost:9090/flags (`storage.tsdb.retention.time`) |

Los 9 targets son:

| Job | Target | Qué contenedor responde |
|---|---|---|
| `prometheus` | `localhost:9090` | monitoreo-prometheus |
| `alertmanager` | `alertmanager:9093` | monitoreo-alertmanager |
| `grafana` | `grafana:3000` | monitoreo-grafana |
| `node` | `node-exporter:9100` | monitoreo-node-exporter |
| `cadvisor` | `cadvisor:8080` | monitoreo-cadvisor |
| `postgres` (instancia `db-hoteles`) | `postgres-exporter-principal:9187` | monitoreo-postgres-exporter-principal |
| `postgres` (instancia `db-replica`) | `postgres-exporter-replica:9187` | monitoreo-postgres-exporter-replica |
| `blackbox-exporter` | `blackbox-exporter:9115` | monitoreo-blackbox-exporter |
| `blackbox-api` | `http://api-hoteles:3000/health` | monitoreo-blackbox-exporter (hace la sonda a la API) |

## Qué hay y para qué sirve cada cosa

```
        ┌────────────── red monitoreo_red ───────────────────────────────┐
        │                                                                │
 Grafana :3000 ──► Prometheus :9090 ──► Alertmanager :9093 ──► webhook n8n (punto 13)
                        │  (pide métricas cada 15 s)
        ┌───────────────┼───────────────┬───────────────┬────────────────┐
  node-exporter     cAdvisor     postgres-exporter x2   blackbox-exporter
  (sistema)       (contenedores)  (principal/réplica)    (GET /health)
                                        │                       │
        └─────────────── red de la base: bd-hoteles-tp_red-hoteles ──────┘
                                  db-hoteles, db-replica, api-hoteles
```

Los 8 contenedores:

| Contenedor | Imagen | Para qué lo usamos |
|---|---|---|
| monitoreo-prometheus | `prom/prometheus:v3.16.0` | Junta las métricas cada 15 s, las guarda 15 días y evalúa las reglas de alerta. |
| monitoreo-alertmanager | `prom/alertmanager:v0.35.0` | Recibe las alertas de Prometheus, las agrupa y las manda por webhook a n8n. |
| monitoreo-grafana | `grafana/grafana:13.2.6` | Dashboards. La fuente de datos y los dashboards se cargan solos (provisioning). |
| monitoreo-node-exporter | `prom/node-exporter:v1.12.1` | Métricas del sistema operativo: CPU, memoria, disco. |
| monitoreo-cadvisor | `ghcr.io/google/cadvisor:v0.60.6` | Métricas de cada contenedor: CPU, memoria, red, si está corriendo, hora de arranque. |
| monitoreo-postgres-exporter-principal | `prometheuscommunity/postgres-exporter:v0.20.1` | Conectado a `db-hoteles`: conexiones, transacciones, tamaño, replicación vista desde la principal. |
| monitoreo-postgres-exporter-replica | `prometheuscommunity/postgres-exporter:v0.20.1` | Conectado a `db-replica`: lo mismo, más el atraso de la réplica. |
| monitoreo-blackbox-exporter | `prom/blackbox-exporter:v0.29.1` | Hace `GET http://api-hoteles:3000/health` como si fuera un cliente y mide si responde y cuánto tarda. Así medimos la API sin tocar el código del backend. |

Todas las imágenes tienen versión fija (nada de `latest`), así en cualquier PC se baja lo mismo.
Las versiones las elegimos mirando las etiquetas estables publicadas en Docker Hub y ghcr.io, y
las bajamos con `docker pull` para confirmar que existen.

### Archivos

| Archivo | Qué tiene |
|---|---|
| `docker-compose.yml` | Los 8 contenedores, puertos, redes y volúmenes. La configuración de los dos postgres-exporter (conexión y colectores activados) está acá. |
| `prometheus/prometheus.yml` | Qué se mide (los jobs que generan los 9 targets), cada cuánto y dónde está Alertmanager. |
| `prometheus/alertas.yml` | Las 13 reglas de alerta, cada una con su umbral y el porqué. |
| `alertmanager/alertmanager.yml` | A dónde se mandan las alertas (webhook de n8n) y cómo se agrupan. |
| `blackbox/blackbox.yml` | Cómo se prueba `/health` (qué cuenta como "anda"). |
| `grafana/provisioning/` | Fuente de datos Prometheus y carpetas de dashboards que Grafana carga al arrancar. |
| `grafana/dashboards/propios/hoteles-vision-general.json` | Nuestro dashboard con lo que pide la consigna. |
| `grafana/dashboards/comunidad/*.json` | Dashboards de grafana.com: Node Exporter Full (1860), Cadvisor exporter (14282) y PostgreSQL Database (9628). |
| `.env.example` | Variables que hay que completar (sin valores reales). |
| `.gitignore` | Ignora `monitoreo/.env`. |

## Cómo levantarlo en otra PC

Estos pasos son los que seguimos en nuestra PC (Windows + Docker Desktop). **En otra PC todavía
no los probamos.**

1. Levantar primero la base y la API (son de otros integrantes):
   ```bash
   docker compose up -d                                              # en la raíz del repo
   docker compose -f backend/docker-compose.yml --env-file .env up -d --build
   ```
   (El segundo comando es el que indica el compose del backend. Nosotros lo corrimos desde
   `backend/` con `docker compose --env-file ../.env up -d --build`, que es equivalente.)
2. Ver cómo se llama la red de la base (depende del nombre de la carpeta del repo):
   ```bash
   docker network ls
   ```
   Buscar la que termina en `_red-hoteles` (con el repo clonado como `bd-hoteles-tp` es `bd-hoteles-tp_red-hoteles`).
3. Crear el `.env` del monitoreo:
   ```bash
   cd monitoreo
   cp .env.example .env
   ```
   Completar la clave de Grafana, copiar `POSTGRES_USER`, `POSTGRES_PASSWORD` y `POSTGRES_DB` del `.env` de la raíz y poner en `RED_HOTELES` el nombre de la red del paso 2.
4. Levantar (crea los 8 contenedores):
   ```bash
   docker compose up -d
   ```
5. Comprobar que los **9 targets** están UP en http://localhost:9090/targets.

Si se cambia `prometheus.yml` o `alertas.yml`, se recarga sin reiniciar con (probado):
```bash
docker kill -s HUP monitoreo-prometheus
```
No activamos `--web.enable-lifecycle` a propósito: permitiría recargar o apagar Prometheus con
un simple POST sin login.

## Puertos y acceso

| Servicio | URL | Acceso |
|---|---|---|
| Grafana | http://localhost:3000 | Usuario y clave del `monitoreo/.env`. Sin registro libre ni acceso anónimo. |
| Prometheus | http://localhost:9090 | Publicado solo en `127.0.0.1`. |
| Alertmanager | http://localhost:9093 | Publicado solo en `127.0.0.1`. |
| Exportadores (5 contenedores) | No tienen | Sin puertos publicados: solo Prometheus llega a ellos por la red interna de Docker. |

Cómo quedan restringidas las interfaces administrativas:
- **Prometheus y Alertmanager no tienen login**, por eso se publican solo en `127.0.0.1`
  (se ve en `docker ps`: `127.0.0.1:9090->9090/tcp` y `127.0.0.1:9093->9093/tcp`). Con eso no
  deberían ser accesibles desde otra máquina de la red; **no lo probamos desde otra PC**.
- **Grafana** pide usuario y clave: si se entra a la API sin login devuelve `401` (probado con
  `curl http://127.0.0.1:3000/api/search`). Tiene desactivados el registro de usuarios
  (`GF_USERS_ALLOW_SIGN_UP=false`) y el acceso anónimo (`GF_AUTH_ANONYMOUS_ENABLED=false`).
  Por defecto también se publica solo en `127.0.0.1`; si hay que mostrarlo desde otra PC se
  cambia `GRAFANA_BIND=0.0.0.0` en el `.env` (no probado).
- Los dashboards provisionados están configurados para que no se puedan borrar ni editar desde la
  interfaz (`disableDeletion`, `allowUiUpdates: false`); se cambian en el JSON del repo. Esto está
  configurado pero **no lo probamos** intentando borrar o guardar un dashboard.
- Ojo: la clave de Grafana del `.env` solo se aplica la **primera vez** que arranca (cuando crea
  su base en el volumen `grafana-data`). Para cambiarla después existe el comando
  `docker exec -it monitoreo-grafana grafana cli admin reset-admin-password <nueva>`
  (verificamos que el comando existe, **no lo ejecutamos**).

## Dashboard "Hoteles - Visión general"

Es el que se abre al iniciar sesión en Grafana (carpeta *Hoteles*). Tiene **36 paneles en 6 filas**:

| Fila | Paneles | De dónde sale |
|---|---|---|
| Disponibilidad de la aplicación (6) | API arriba/caída, código HTTP de `/health`, % de disponibilidad en el período, tiempo de respuesta actual, tiempo de respuesta en el tiempo, API arriba/caída en el tiempo | blackbox-exporter |
| Sistema (5) | CPU, memoria, disco usado (`/var/lib` y `C:`), CPU y memoria en el tiempo, red de la VM | node-exporter y cAdvisor |
| Contenedores (7) | Estado de los 5 contenedores del proyecto, arranques en el período, tiempo desde el último arranque, CPU, memoria, red recibida y red enviada de cada uno | cAdvisor |
| Base de datos (12) | Principal y réplica arriba/caída, conexiones abiertas, tamaño de la base, tiempo encendida, conexiones por estado, transacciones por segundo, filas por segundo, aciertos de caché, transacción abierta más larga, locks y deadlocks, y un panel de texto que explica lo de las consultas lentas | postgres-exporter |
| Replicación (5) | Réplicas en streaming (vistas desde la principal), rol de `db-replica`, atraso actual, atraso en el tiempo (segundos) y WAL pendiente (bytes) | postgres-exporter |
| Alertas (1) | Tabla con las alertas en estado *pending* o *firing* | Prometheus (`ALERTS`) |

Cada panel tiene una descripción (el ícono ⓘ) que explica qué métrica usa. Todas las consultas
del dashboard las ejecutamos contra la API de Prometheus (`/api/v1/query`) y devuelven datos,
salvo la tabla de alertas, que queda vacía ("No data") cuando no hay ninguna alerta activa; con
la API detenida mostró las alertas.

Los dashboards de la carpeta *Comunidad* son para ver más detalle. Solo les cambiamos la
referencia a la fuente de datos (de `${DS_PROMETHEUS}` a la nuestra) para que se carguen solos;
los paneles quedan como los publicó el autor. El de PostgreSQL (9628) fue hecho para Kubernetes
y filtra por las etiquetas `release` y `kubernetes_namespace`: para que funcione sin editarlo,
en `prometheus.yml` les ponemos esas etiquetas fijas (`hoteles`) a los dos postgres-exporter.
El panel *Active sessions* de ese dashboard aparece sin datos mientras la base está quieta: su
consulta filtra `state="active" ... != 0`, y si nadie está ejecutando nada no queda ningún valor.

## Alertas

Prometheus evalúa las 13 reglas cada 15 s. "Durante" es el `for`: cuánto tiempo seguido se tiene
que cumplir la condición antes de disparar, para no avisar por un pico suelto.

**Solo 2 de las 13 alertas se probaron disparándolas de verdad** (`ApiCaida` y
`ContenedorSinReportar`, con `docker stop api-hoteles`). De las demás verificamos que la regla
carga sin errores y que la métrica que usan existe y tiene datos, pero **no las hicimos disparar**.

| Alerta | Condición | Durante | Severidad | ¿Probada? | Por qué ese umbral |
|---|---|---|---|---|---|
| `ApiCaida` | `probe_success == 0` en `/health` | 1 min | critical | **Sí**, disparó y se resolvió | 4 sondas fallidas seguidas: descarta un timeout aislado y avisa rápido. Falla si no responde, si tarda más de 5 s o si no da 200 (el backend da 503 cuando la principal está caída). |
| `ContenedorSinReportar` | cAdvisor no ve a `db-hoteles`, `db-replica`, `api-hoteles`, `pgadmin-hoteles` o `db-backup` | 1 min | critical | **Sí** (con `api-hoteles`), disparó y se resolvió | cAdvisor actualiza cada 15 s; 1 min alcanza para confirmar que no es un parpadeo. |
| `BasePrincipalCaida` | `pg_up{rol="principal"} == 0` | 1 min | critical | No probada | Que un reinicio corto de Postgres no llegue a avisar (no medimos cuánto tarda uno). |
| `ReplicaCaida` | `pg_up{rol="replica"} == 0` | 1 min | critical | No probada | Igual que la principal. |
| `ReplicaDesconectada` | En la principal no hay ninguna réplica en `streaming` (`pg_stat_replication`) y la principal está arriba | 2 min | critical | No probada | La réplica puede estar viva pero sin recibir cambios. 2 min le da tiempo a reconectarse sola. |
| `ReplicacionRetrasoAlto` | `pg_replication_lag_seconds > 30` | 2 min | warning | No probada | En red local la réplica asíncrona debería ir casi al día; 30 s sostenidos = no da abasto (ej. carga masiva). |
| `ReplicacionRetrasoBytesAlto` | WAL sin aplicar `> 64 MB` | 2 min | warning | No probada | La principal guarda 1 GB de WAL (`wal_keep_size`, verificado en `pg_settings`) y no hay slot de replicación (verificado: `pg_replication_slots` vacío). 64 MB avisa con mucho margen antes de llegar a 1 GB. |
| `ConexionesAltas` | Conexiones usadas `> 80%` de `max_connections` (100, verificado en `pg_settings`) | 5 min | warning | No probada | Queda margen antes de que Postgres rechace conexiones. |
| `CpuAlta` | CPU de la VM `> 85%` | 5 min | warning | No probada | Saturación sostenida, no un pico (ej. crear un índice). |
| `MemoriaAlta` | Memoria usada (sin caché) `> 90%` | 5 min | warning | No probada | Cerca de que el kernel empiece a matar procesos. |
| `DiscoCasiLleno` | `/var/lib` (disco de Docker) o `C:` `> 85%` | 10 min | warning | No probada | Deja lugar para la carga masiva, los backups y el WAL. El disco cambia lento: 10 min evita falsas alarmas por temporales. |
| `ContenedorReiniciandose` | Más de 2 arranques en 15 min | Sin espera (`for: 0m`) | warning | No probada (solo verificamos que la métrica cuenta los arranques: dio 2 después de 2 `docker start`) | Indica un ciclo de caídas (ver limitaciones: es la forma de medir reinicios con cAdvisor). |
| `TargetCaido` | `up == 0` en cualquier target | 2 min | warning | No probada | Si se cae un exportador, las otras alertas quedan ciegas; esto lo avisa. |

En `alertmanager.yml` hay dos reglas de inhibición (Alertmanager las cargó, se ve en
`/api/v2/status`): si la réplica está caída no se avisa además que está desconectada o atrasada,
y si la principal está caída no se avisa que la réplica está desconectada (es la misma causa).
**Las inhibiciones no las probamos.**

Las alertas se mandan a `http://host.docker.internal:5678/webhook/alertas-prometheus`, que es el
webhook de n8n (punto 13), con `send_resolved: true` para avisar también cuando se resuelven.
**Pendiente:** n8n todavía no está conectado. Mientras tanto, Alertmanager registra en su log
`Notify attempt failed ... connection refused` y reintenta (lo vimos en la prueba).

## Prueba de alerta (para la demo)

1. Abrir Grafana (dashboard propio, fila *Alertas*), http://localhost:9090/alerts y http://localhost:9093.
2. Tirar la API:
   ```bash
   docker stop api-hoteles
   ```
3. Qué pasó en nuestra prueba (con `honor_timestamps: false` ya aplicado, ver limitaciones):
   - ~10 s: `probe_success` pasa a 0 y el código HTTP a 0 (sin respuesta).
   - ~30 s: `ApiCaida` y `ContenedorSinReportar` quedan en **pending** (se cumple la condición, corre el `for`).
   - ~90 s: pasan a **firing** y aparecen en Alertmanager como `active`, con receptor `n8n`.
4. Levantarla de nuevo:
   ```bash
   docker start api-hoteles
   ```
   A los ~30-40 s las alertas vuelven a `inactive` y desaparecen de Alertmanager. En el
   dashboard, "Arranques en el período" de `api-hoteles` sube 1 por cada `docker start`.

Los tiempos pueden variar unos segundos según en qué momento caen el scrape y la evaluación
(los dos son cada 15 s).

Para verlo por consola en vez de la web:
```bash
curl -s http://localhost:9090/api/v1/alerts
curl -s http://localhost:9093/api/v2/alerts
```

## Limitaciones conocidas (y cómo se resolverían)

- **Consultas lentas: no se miden consultas SQL individuales.** El postgres-exporter solo puede
  ver consultas individuales con la extensión `pg_stat_statements` (colector `stat_statements`),
  que no está instalada en la base (las métricas `pg_stat_statements*` no existen en
  Prometheus). Lo que mostramos es una métrica general: la duración de la transacción abierta
  más larga de cada nodo (`pg_stat_activity_max_tx_duration`), que no dice qué consulta es.
  Para activarlo (pendiente, no probado) haría falta, en el compose de la base (de Brian):
  agregar `-c shared_preload_libraries=pg_stat_statements` al `command` de `db-hoteles`,
  reiniciar, ejecutar `CREATE EXTENSION pg_stat_statements;` en la base `hoteles`, y acá agregar
  `--collector.stat_statements` al exportador de la principal.
- **Reinicios de contenedores:** cAdvisor no tiene un contador de reinicios (la métrica
  `container_restart*` no existe, lo verificamos en `/api/v1/label/__name__/values`). Lo que
  usamos es `changes(container_start_time_seconds[...])`: cuenta cuántas veces cambió la hora de
  arranque. Cuenta tanto un reinicio automático como un `docker stop` + `docker start` manual
  (lo segundo lo probamos; un reinicio automático no). El dato exacto de Docker
  (`RestartCount`) solo se ve con `docker inspect`; para tenerlo en Prometheus habría que
  agregar otro exportador de Docker.
- **El "sistema operativo" es la VM de Docker Desktop.** En Windows, Docker corre dentro de una
  máquina virtual Linux (WSL2). node-exporter mide esa VM (en nuestra PC: 12 CPUs y 7,7 GiB de
  memoria), no Windows. Como es donde corren todos los contenedores, es lo que importa para el
  TP. En un servidor Linux mediría el servidor directamente.
- **Disco:** el disco de Docker (`/var/lib`, unos 1.081 GB virtuales) es un archivo que crece
  adentro de `C:` (499 GB en nuestra PC), por eso el panel y la alerta miran los dos. Como `C:`
  es más chico que el tamaño virtual, en la práctica se llenaría primero `C:`.
- **Red del sistema:** node-exporter corre en una red de Docker y solo ve su propia interfaz,
  así que la red de la VM la sacamos de cAdvisor (contenedor raíz `/`, interfaz `eth0`). Poner
  node-exporter con `network_mode: host` no lo probamos: creemos que en Docker Desktop
  Prometheus no podría llegar a él por nombre de servicio.
- **Montaje `rslave` de node-exporter:** la documentación oficial monta `/:/host:ro,rslave`, pero
  en Docker Desktop falla con `path / is mounted on / but it is not a shared or slave mount`
  (nos pasó). Lo dejamos como `/:/host:ro`. Lo que se pierde, según para qué sirve `rslave`, es
  ver discos montados después de arrancar el exportador (no lo probamos).
- **cAdvisor y `honor_timestamps: false`:** cAdvisor publica cada muestra con su propia hora.
  En la primera prueba, con eso Prometheus siguió mostrando el contenedor detenido durante
  5 minutos y `ContenedorSinReportar` tardó unos 6 min en disparar. Con `honor_timestamps: false`
  (usar la hora del scrape) la repetimos: la serie desaparece enseguida y la alerta disparó a los
  ~90 s.
- **Estado de la conexión de la réplica (`stat_wal_receiver`):** probamos activar ese colector
  en el exportador de la réplica y no publica ninguna métrica (aunque el colector responde
  bien), así que lo sacamos. Creemos que es porque la réplica no usa slot de replicación
  (`slot_name` vacío en `pg_stat_wal_receiver`), pero no lo confirmamos en el código del
  exportador. El estado de la replicación lo medimos igual desde la principal
  (`pg_stat_replication`) y con `pg_replication_is_replica` y `pg_replication_lag_seconds` en la
  réplica.
- **`pg_replication_last_replay_seconds` no es atraso:** es el tiempo desde la última
  transacción aplicada. Con la base quieta crece aunque la réplica esté al día (la vimos en
  ~1.350 s con atraso 0); por eso no la usamos en alertas.
- **Avisos en los logs que se pueden ignorar:** los postgres-exporter dicen
  `Error loading config ... postgres_exporter.yml` (ese archivo es para configurar módulos de
  autenticación en modo multi-target, que no usamos), y Grafana dice que no encuentra
  `provisioning/plugins` y `provisioning/alerting` (no provisionamos plugins ni alertas de
  Grafana: las alertas las maneja Prometheus). Con esos avisos los 9 targets igual están UP.
- **Webhook a n8n (pendiente):** queda configurado pero n8n se conecta en el punto 13. Hasta
  entonces las notificaciones fallan con `connection refused` (las alertas igual se ven en
  Prometheus, Alertmanager y Grafana).

## Pendiente con Brian (base de datos)

Nada de esto está hecho ni probado todavía.

1. **Usuario de solo lectura para el monitoreo.** Ahora los postgres-exporter usan el mismo
   usuario de la aplicación (`hoteles_app`), que es superusuario (verificado: `rolsuper = t` en
   `pg_roles`). Lo correcto es uno que solo pueda leer estadísticas:
   ```sql
   CREATE ROLE monitoreo WITH LOGIN PASSWORD '...';
   GRANT pg_monitor TO monitoreo;
   ```
   Hay que crearlo en la principal (por la replicación debería aparecer también en la réplica)
   y después cambiar `POSTGRES_USER` / `POSTGRES_PASSWORD` en `monitoreo/.env`.
2. **`pg_stat_statements`** si queremos mostrar consultas lentas de verdad (ver limitaciones).
3. **Slot de replicación** para la réplica: hoy no hay ninguno, así que si la réplica se atrasa
   más de lo que guarda `wal_keep_size` (1 GB), la principal puede borrar WAL que la réplica
   todavía necesita y habría que volver a clonarla. Con un slot la principal guarda el WAL hasta
   que la réplica lo reciba (la alerta de bytes pendientes sirve para vigilar que no se acumule
   demasiado).
