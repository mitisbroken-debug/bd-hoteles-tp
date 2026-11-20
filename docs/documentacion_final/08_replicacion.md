# 8. Configuración y pruebas de replicación

Responsable: Brian. Origen: `docker-compose.yml`, `docs/rol2_base_de_datos.md` (sección 5) y
`backend/src/server.js`.

## Qué se implementó

Replicación **física en streaming, asíncrona**, de PostgreSQL 16, con dos nodos:

| Nodo | Contenedor | Puerto | Rol |
|---|---|---|---|
| Principal | `db-hoteles` | 5440 | Lee y escribe. Manda su registro de cambios (WAL) a la réplica |
| Réplica | `db-replica` | 5442 | Solo lectura. Recibe el WAL y lo aplica |

```
            escrituras                      lecturas
 api-hoteles ─────────► db-hoteles ══WAL══► db-replica ◄───────── api-hoteles
                        (principal)  streaming  (hot standby)
                                     asíncrono
```

## Configuración de los nodos

Principal (`docker-compose.yml`, servicio `db-hoteles`):

| Parámetro | Valor | Para qué |
|---|---|---|
| `wal_level` | `replica` | Que el WAL tenga la información que necesita una réplica |
| `max_wal_senders` | `10` | Cuántas conexiones de replicación acepta |
| `wal_keep_size` | `1GB` | Cuánto WAL guarda por si la réplica se desconecta un rato |
| `hot_standby` | `on` | Permite consultas de lectura en la réplica |
| `pg_hba.conf` propio | líneas `host replication ... scram-sha-256` | El de la imagen no deja que otro contenedor se conecte para replicar |

Réplica (servicio `db-replica`): la primera vez ejecuta
`pg_basebackup -h db-hoteles -U <usuario> -D $PGDATA -R -X stream`. La opción `-R` deja escrita la
configuración de réplica (`standby.signal` y los datos de conexión). Las veces siguientes arranca
directamente como réplica.

Decisiones (de `docs/rol2_base_de_datos.md`, sección 7):

- **Sin slot de replicación, con `wal_keep_size`.** Un slot retiene WAL sin límite si la réplica
  está caída mucho tiempo y puede llenar el disco. Con `wal_keep_size` el límite es 1 GB.
- **`pg_basebackup`** copia la base completa de forma consistente y deja lista la réplica.

## Cómo usa la aplicación la réplica

En `backend/src/server.js` hay dos grupos de conexiones: uno al principal (escrituras) y otro a
la réplica (lecturas). Si la réplica no responde, la lectura se hace en el principal. Cada
respuesta trae la cabecera `X-DB-Node` con el nodo que la atendió:

```powershell
curl.exe -i http://localhost:3001/api/hoteles
```
En la respuesta aparece `X-DB-Node: replica`.

## Pruebas

Comandos de `docs/rol2_base_de_datos.md`. El primero y el del modo de la réplica se volvieron a
ejecutar el 16/11/2026.

**1. La réplica está conectada**
```powershell
docker exec db-hoteles psql -U hoteles_app -d postgres -c "SELECT client_addr, state, sync_state, sent_lsn, replay_lsn FROM pg_stat_replication;"
```
Resultado del 16/11/2026: una fila, `state = streaming`, `sync_state = async`,
`sent_lsn = replay_lsn = 0/3062A58` (sin atraso).

**2. Lo que se escribe en el principal aparece en la réplica**
```powershell
docker exec db-hoteles psql -U hoteles_app -d hoteles -c "CREATE TABLE prueba_replica(id int); INSERT INTO prueba_replica VALUES (1),(2),(3);"
```
```powershell
docker exec db-replica psql -U hoteles_app -d hoteles -c "SELECT * FROM prueba_replica;"
```

**3. La réplica no acepta escrituras**
```powershell
docker exec db-replica psql -U hoteles_app -d hoteles -c "INSERT INTO prueba_replica VALUES (9);"
```
Da `ERROR: cannot execute INSERT in a read-only transaction`.
Además `SELECT pg_is_in_recovery();` devuelve `t` en la réplica y `f` en el principal (comprobado el 16/11/2026).

**4. Retraso de replicación**

Desde el principal, `pg_stat_replication` muestra `replay_lag` y los bytes pendientes
(`pg_wal_lsn_diff(sent_lsn, replay_lsn)`). Medirlo en la réplica con
`now() - pg_last_xact_replay_timestamp()` engaña: si el principal está quieto, ese valor crece
aunque no haya ningún problema. El monitoreo (sección 11) grafica el atraso en segundos y en
bytes y tiene dos alertas sobre eso.

**5. Falla de la réplica**
```powershell
docker stop db-replica
```
El principal sigue atendiendo. La API pasa a leer del principal (`X-DB-Node: principal (respaldo)`).
Al volver (`docker start db-replica`), la réplica se pone al día sola con el WAL guardado.

**6. Falla del principal**
```powershell
docker stop db-hoteles
```
La réplica sigue respondiendo lecturas. Para escribir hay que promoverla **a mano**:
```powershell
docker exec -u postgres db-replica pg_ctl promote -D /var/lib/postgresql/data
```

**7. Volver al estado normal** después de promover: borrar el contenedor y el volumen de la
réplica y volver a levantar, para que se clone de nuevo desde el principal. Pasos en
`docs/rol2_base_de_datos.md`, "Volver al estado normal".

## Consistencia y limitaciones

- **No hay failover automático.** La promoción es manual. Automatizarla necesitaría una
  herramienta como Patroni o repmgr, que detecte la falla, elija el nodo y evite que queden dos
  principales a la vez (*split-brain*). No lo afirmamos ni lo implementamos.
- **Consistencia eventual.** La replicación es asíncrona: el principal confirma la escritura sin
  esperar a la réplica. Una reserva recién creada puede tardar milisegundos en verse en una lectura.
- **Posible pérdida de las últimas transacciones** si el principal se cae antes de enviarlas.
- **Si la réplica queda desconectada más de 1 GB de WAL**, ya no puede ponerse al día y hay que
  clonarla de nuevo.
- La réplica guarda la clave de replicación en su volumen (`postgresql.auto.conf`).

## Pendiente

- [PENDIENTE – Brian – diagrama de replicación propio (es un entregable del punto 6).]
- [PENDIENTE – Brian – en `docs/rol2_base_de_datos.md`, sección 6, dice "la aplicación todavía
  escribe solo contra el principal; no hay balanceo de lecturas hacia la réplica". Ya no es
  cierto: la API lee de la réplica. Hay que corregir esa línea.]
