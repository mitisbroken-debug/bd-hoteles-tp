# Rol 2 - Base de datos (puntos 4, 5 y 6)

Documento con los comandos usados y el por que de cada decision.

## 1. Servicios (docker-compose.yml)

| Servicio | Imagen | Puerto | Para que sirve |
|---|---|---|---|
| db-hoteles | postgres:16 | 5440 | Nodo principal: lee y escribe. Tiene los 6.000.000 de reservas |
| db-replica | postgres:16 | 5442 | Nodo replica: copia del principal, solo lectura |
| pgadmin | dpage/pgadmin4 | 5050 | Cliente web para administrar las bases |
| db-backup | postgres:16 | - | Hace un pg_dump automatico cada 24 h y guarda los 3 ultimos |

Todos estan en la red interna `red-hoteles`, asi se ven por nombre (`db-hoteles`, `db-replica`).
Los datos viven en volumenes (`hoteles-data`, `replica-data`, `pgadmin-data`) para que no se pierdan al recrear contenedores.
Las credenciales estan en `.env` (no se sube al repo); en el repo solo esta `.env.example`.

## 2. Como levantarlo

```
copy .env.example .env        (y poner las claves)
docker compose up -d
docker compose ps
```
Importante: nunca usar `docker compose down -v`, porque `-v` borra los volumenes (los 6 millones de datos).

La primera vez, la replica tarda unos minutos porque clona toda la base con pg_basebackup.
Para ver el avance: `docker compose logs -f db-replica`

## 3. Punto 4 - Evidencia de volumen

```
docker exec -it db-hoteles psql -U hoteles_app -d hoteles
```
```sql
SELECT relname AS tabla, n_live_tup AS filas FROM pg_stat_user_tables ORDER BY n_live_tup DESC;
SELECT count(*) FROM reserva;
SELECT pg_size_pretty(pg_database_size('hoteles')) AS tamano_base;
SELECT pg_size_pretty(pg_relation_size('reserva')) AS tabla, pg_size_pretty(pg_indexes_size('reserva')) AS indices;
```
Metodo de carga: SQL set-based con generate_series (sql/carga/carga_masiva.sql). Tiempos medidos: ver salida_carga.txt.

### Persistencia
```
docker compose down
docker compose up -d
docker exec db-hoteles psql -U hoteles_app -d hoteles -c "SELECT count(*) FROM reserva;"
```
Da 6.000.000 de nuevo: los datos estan en el volumen, no en el contenedor.

### pgAdmin
Abrir http://localhost:5050, entrar con el mail y la clave de PGADMIN_* del `.env`.
Los dos servidores ya aparecen cargados (Primario y Replica); al conectar pide la clave de POSTGRES_PASSWORD.

### Backup y restauracion
El servicio db-backup genera archivos en la carpeta `backups/`.
Ver que corrio: `docker compose logs db-backup`
Backup manual extra, medido con tiempo:
```
docker exec db-backup bash -c 'time pg_dump -h db-hoteles -U $POSTGRES_USER -d $POSTGRES_DB -Fc -f /backups/manual.dump'
```
Prueba de restauracion en una base aparte (no pisa la original):
```
docker exec db-hoteles psql -U hoteles_app -d postgres -c "CREATE DATABASE hoteles_restore;"
docker exec db-backup bash -c 'time pg_restore -h db-hoteles -U $POSTGRES_USER -d hoteles_restore -j 4 /backups/manual.dump'
docker exec db-hoteles psql -U hoteles_app -d hoteles_restore -c "SELECT count(*) FROM reserva;"
```
Si el conteo coincide con la base original, la copia sirve. Al restaurar, el indice EXCLUDE (gist) se reconstruye y es lo que mas tarda.
Limpieza: `docker exec db-hoteles psql -U hoteles_app -d postgres -c "DROP DATABASE hoteles_restore;"`

## 4. Punto 5 - Optimizacion
Esta en sql/consultas e indices: consultas originales y optimizadas, planes con EXPLAIN ANALYZE antes y despues, indices creados con su justificacion y mediciones.
Cada indice se justifica por el costo: los indices de `reserva` pesan mas que la tabla y encarecen los INSERT, por eso no se crean de forma indiscriminada.

## 5. Punto 6 - Replicacion

Tipo: replicacion en streaming asincrona (fisica). El principal manda su WAL a la replica y esta lo aplica.

### Verificar que replica
```
docker exec db-hoteles psql -U hoteles_app -d postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
```
Tiene que aparecer una fila con state = streaming.

Prueba de escritura y lectura:
```
docker exec db-hoteles psql -U hoteles_app -d hoteles -c "CREATE TABLE prueba_replica(id int); INSERT INTO prueba_replica VALUES (1),(2),(3);"
docker exec db-replica psql -U hoteles_app -d hoteles -c "SELECT * FROM prueba_replica;"
```
La replica ve las 3 filas. Limpieza: `DROP TABLE prueba_replica;` en el principal.

La replica es de solo lectura:
```
docker exec db-replica psql -U hoteles_app -d hoteles -c "INSERT INTO prueba_replica VALUES (9);"
```
Da: ERROR: cannot execute INSERT in a read-only transaction.

Retraso (lag) medido en la replica:
```
docker exec db-replica psql -U hoteles_app -d hoteles -c "SELECT now() - pg_last_xact_replay_timestamp() AS retraso;"
```
La consulta anterior mide el tiempo desde la ultima transaccion aplicada, asi que si el principal esta quieto el valor crece sin que haya un problema real.
Para medir el retraso real se usa desde el principal pg_stat_replication (replay_lag y bytes pendientes = pg_wal_lsn_diff(sent_lsn, replay_lsn)).
La replicacion es asincrona: hay un retraso de milisegundos a segundos cuando hay escrituras, y es consistencia eventual, no inmediata.

### Prueba de fallo 1: cae la replica
```
docker stop db-replica
docker exec db-hoteles psql -U hoteles_app -d hoteles -c "INSERT INTO prueba_replica VALUES (10),(11);"
docker start db-replica
docker exec db-replica psql -U hoteles_app -d hoteles -c "SELECT * FROM prueba_replica;"
```
El principal sigue andando sin problema y, cuando la replica vuelve, se pone al dia sola con el WAL que se guardo (wal_keep_size = 1GB).

### Prueba de fallo 2: cae el principal
```
docker stop db-hoteles
docker exec db-replica psql -U hoteles_app -d hoteles -c "SELECT count(*) FROM reserva;"
```
La replica sigue respondiendo lecturas. Para escribir hay que promoverla a mano:
```
docker exec -u postgres db-replica pg_ctl promote -D /var/lib/postgresql/data
docker exec db-replica psql -U hoteles_app -d hoteles -c "SELECT pg_is_in_recovery();"
```
Da `f`: ahora es un nodo principal y acepta escrituras.

### Volver al estado normal
Despues de promover, la replica ya no sigue al principal viejo. Para volver a la arquitectura original:
```
docker compose rm -sf db-replica
docker volume ls
docker volume rm <nombre_del_proyecto>_replica-data
docker start db-hoteles
docker compose up -d
```
(`docker volume ls` muestra el nombre exacto, por ejemplo `bd-hoteles-tp_replica-data`). La replica se vuelve a clonar desde el principal.

## 6. Limitaciones conocidas
- No hay failover automatico: la promocion es manual. Para automatizarlo haria falta Patroni, repmgr o similar, con deteccion de falla y manejo de split-brain.
- Replicacion asincrona: si el principal cae, las ultimas transacciones que la replica no recibio se pueden perder.
- La replica guarda la clave de replicacion en su configuracion (postgresql.auto.conf), dentro de su volumen.
- Los 6M de reservas implican mucho tiempo de clonado y de restauracion (indice EXCLUDE).
- La aplicacion todavia escribe solo contra el principal; no hay balanceo de lecturas hacia la replica.

## 7. Por que se decidio asi

| Decision | Motivo |
|---|---|
| Credenciales en `.env` | El TP prohibe claves en el repositorio publico |
| pg_hba.conf propio en el principal | El de la imagen no permite replicacion desde otro contenedor, y la base ya tenia datos, asi que no se podia usar un script de inicio |
| pg_basebackup para crear la replica | Copia la base completa de forma consistente y deja lista la configuracion de replica (`-R`) |
| Sin slot de replicacion + wal_keep_size | Un slot retiene WAL sin limite si la replica cae mucho tiempo y puede llenar el disco |
| healthcheck en el principal | La replica y el backup esperan a que el principal acepte conexiones |
| pg_dump formato custom (-Fc) | Comprime y permite restaurar en paralelo con pg_restore -j |
| Backups con retencion de 3 | Evita llenar el disco con copias de una base grande |
| Red `red-hoteles` | Los servicios se comunican por nombre sin exponer todos los puertos |


## Rol 3: DevOps e Infraestructura (Puntos 7, 8) 

## Punto 7: Contenerización de la aplicación web (Frontend y Backend)

Para cumplir con la contenerización y el aislamiento de todos los componentes del sistema, se estructuró la aplicación web de la siguiente manera:

### Servicios añadidos en `docker-compose.yml`:
| Servicio | Directorio / Build | Puerto | Para qué sirve |
|---|---|---|---|
| `backend` | `./backend` | `3001` | API REST en Node.js que procesa la lógica de negocio y conecta con PostgreSQL. |
| `frontend` | `./frontend` | `8090:80` | Interfaz web interactiva ("Red Hoteles Argentina") servida mediante Nginx. |

### Red y Comunicación:
* Ambos servicios están conectados dentro de la red puente interna `red-hoteles`, lo que les permite comunicarse de forma aislada y segura con los nodos de base de datos (`db-hoteles` y `db-replica`).

### Características de la Interfaz Web:
* **Catálogo Visual de Alojamientos:** Permite seleccionar un hotel de la red y visualizar sus habitaciones disponibles en formato de tarjetas interactivas, eliminando la necesidad de ingresar IDs numéricos manuales.
* **Emisión de Comprobantes (Vouchers):** Al confirmar la estadía ingresando los datos del huésped titular, la aplicación interactúa con la API para registrar la operación y emite un comprobante legible sincronizado directamente con la base de datos PostgreSQL.

---

## 8. Punto 8 - CI/CD, Fallos y Mecanismos de Reversión

### Pipeline Implementado
Se configuró **GitHub Actions** para automatizar el proceso de integración continua (CI) y despliegue continuo (CD). Cada vez que se realiza un `push` o un Pull Request validado:
1. Se descargan las dependencias y se clona el repositorio de forma aislada en contenedores limpios (`ubuntu-latest`).
2. Se compilan y construyen las imágenes Docker del **Frontend** y el **Backend**.
3. Si la compilación es exitosa, se autentica mediante tokens seguros y se publican las nuevas versiones en **Docker Hub**.

### Control de Fallos y Validaciones
* **Validación de código:** El pipeline se interrumpe automáticamente (falla) si el Dockerfile de alguna de las aplicaciones tiene errores de sintaxis, rompiendo el ciclo y evitando que código defectuoso llegue a producción.
* **Aislamiento:** Las credenciales de acceso al registro de contenedores están protegidas mediante los *GitHub Secrets*, impidiendo su filtración en el historial de commits.

### Procedimiento de Recuperación (Rollback)
En caso de que una imagen subida mediante el pipeline presente errores críticos en producción:
1. **Identificar la versión estable anterior** en el historial de etiquetas (tags) de Docker Hub o mediante los commits de Git.
2. **Forzar el despliegue de la versión anterior** conectándose al servidor de destino y ejecutando:
   ```bash
   docker compose down
   # Modificar temporalmente la versión en docker-compose.yml a una etiqueta anterior estable (ej: :v1.0.0)
   docker compose up -d --pull always
3. **Forzar el despliegue de la versión anterior** conectándose al servidor de destino y ejecutando:
   ```bash
   docker compose down
   # Modificar temporalmente la versión en docker-compose.yml a una etiqueta anterior estable (ej: :v1.0.0 o el tag previo)
   docker compose up -d --pull always
