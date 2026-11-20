# 15. Procedimiento de backup y restauración

Responsables: Brian (servicio de backup) y Juan (verificación automática con n8n).
Origen: `docker-compose.yml`, `docs/rol2_base_de_datos.md` (sección 3) y `n8n/README.md`.

## Cómo se hacen los backups

El servicio `db-backup` (imagen `postgres:16`) ejecuta en un ciclo:

1. `pg_dump -h db-hoteles -Fc` hacia `backups/hoteles_AAAAMMDD_HHMMSS.dump`.
2. Si `pg_dump` falla, borra el archivo incompleto.
3. Borra los backups viejos y deja los últimos `BACKUP_KEEP` (3).
4. Espera `BACKUP_INTERVAL_SECONDS` (86400 s = 24 h) y repite.

| Decisión | Motivo (de `docs/rol2_base_de_datos.md`) |
|---|---|
| Formato *custom* (`-Fc`) | Comprime y permite restaurar en paralelo con `pg_restore -j` |
| Guardar solo 3 | Evita llenar el disco con copias de una base grande |
| Carpeta `./backups` en la PC | Los archivos quedan fuera del contenedor y del volumen de la base |

Los `.dump` y la carpeta `backups/` están en `.gitignore`: no se suben al repositorio.

Ver que corrió:
```powershell
docker compose logs db-backup
```

Backup manual, con tiempo medido:
```powershell
docker exec db-backup bash -c 'time pg_dump -h db-hoteles -U $POSTGRES_USER -d $POSTGRES_DB -Fc -f /backups/manual.dump'
```

## Cómo se restaura

### Prueba manual (de `docs/rol2_base_de_datos.md`)

En una base aparte, sin pisar la original:
```powershell
docker exec db-hoteles psql -U hoteles_app -d postgres -c "CREATE DATABASE hoteles_restore;"
```
```powershell
docker exec db-backup bash -c 'time pg_restore -h db-hoteles -U $POSTGRES_USER -d hoteles_restore -j 4 /backups/manual.dump'
```
```powershell
docker exec db-hoteles psql -U hoteles_app -d hoteles_restore -c "SELECT count(*) FROM reserva;"
```
Si el conteo coincide con el de la base original, la copia sirve. Al restaurar, lo que más tarda
es reconstruir el índice de no superposición de `reserva`.

Limpieza:
```powershell
docker exec db-hoteles psql -U hoteles_app -d postgres -c "DROP DATABASE hoteles_restore;"
```

### Verificación automática (flujo 2 de n8n)

Todos los días a las 08:00, o a pedido, n8n:

1. Busca el último backup y comprueba cuatro cosas: que existe, que `pg_restore --list` lo puede
   leer, que pesa más que el mínimo y que tiene menos de 26 h.
2. Guarda el resultado en la tabla `verificaciones_backup`.
3. Si algo está mal, manda un mail de error.
4. Si está bien, pide aprobación por mail. Al aprobar, restaura el backup en la base
   `restauracion_prueba` del contenedor `n8n-db-verificacion`, cuenta las tablas y las filas de
   `reserva` y manda el resultado.

Ese contenedor ve la carpeta de backups en solo lectura y no tiene conexión con la base de
producción: la prueba no puede dañar nada.

Ejecutarlo a pedido y ver el resultado: `n8n/README.md`, "Cómo demostrarlo en vivo", paso 3.

### Restauración real ante un desastre

Si se pierde la base principal:

1. Si la réplica está sana, lo más rápido es **promoverla** (sección 8, prueba 6). No hace falta el backup.
2. Si se perdieron los dos nodos o los datos están dañados (por ejemplo, un borrado por error, que
   la réplica copia igual), se restaura el último backup:
   - levantar una base vacía (`docker compose up -d db-hoteles`);
   - restaurar con `pg_restore -h db-hoteles -U <usuario> -d hoteles -j 4 /backups/<archivo>.dump` desde `db-backup`;
   - volver a crear la réplica (sección 8, "Volver al estado normal").
3. Se pierde lo escrito después del último backup: como máximo 24 h.

[PENDIENTE – Brian – probar y medir la restauración completa del punto 2 con los 6.000.000 de
reservas, y anotar el tiempo.]

## Evidencia

Del 17/11/2026 (`n8n/README.md`, "Evidencias"):

| Prueba | Resultado |
|---|---|
| Lectura del backup con `pg_restore --list` | 101 objetos |
| Restauración aprobada en la base de prueba | 12 tablas restauradas en 0,49 s |
| Backup de más de 26 h | Detectado como `viejo` y avisado por mail |

La base de esa PC tenía solo el esquema, por eso el backup pesa 34 KB.
[PENDIENTE – Brian – repetir la verificación con la base cargada y anotar tamaño del backup y
tiempo de la copia y de la restauración.]

## Problema abierto: el backup no se genera después de reiniciar la PC

Detectado el 16/11/2026 por el log del servicio y confirmado por la verificación automática
(el último backup tenía 95 h).

```
[backup] iniciando /backups/hoteles_20261117_023647.dump
pg_dump: error: connection to server at "db-hoteles", port 5432 failed: Connection refused
[backup] ERROR, se borra el archivo incompleto
```

**Causa.** `db-backup` tiene `depends_on: db-hoteles (service_healthy)`, pero eso solo ordena el
arranque con `docker compose up`. Cuando Docker reinicia los contenedores solo (al prender la
PC), arrancan todos juntos: el backup intenta conectarse antes de que la base esté lista, falla,
y recién vuelve a intentar 24 h después. Si la PC se apaga todas las noches, nunca hay backup nuevo.

**Solución provisoria.**
```powershell
docker restart db-backup
```

**Solución definitiva.** [PENDIENTE – Brian – en el servicio `db-backup` de `docker-compose.yml`,
esperar a la base antes de cada `pg_dump`, por ejemplo con
`until pg_isready -h db-hoteles -U "$$POSTGRES_USER"; do sleep 5; done`, o reintentar a los pocos
minutos cuando falla en lugar de esperar 24 h.]

## Limitaciones

- Los backups quedan en la misma PC que la base. Si se pierde el disco, se pierden los dos.
  Lo recomendable es copiarlos a otro lugar (por ejemplo, a Nextcloud).
- Un backup por día: se puede perder hasta un día de reservas. Para perder menos haría falta
  archivar el WAL (recuperación a un punto en el tiempo).
- Los backups no están cifrados.
