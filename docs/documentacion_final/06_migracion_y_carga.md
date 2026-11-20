# 6. Procedimiento de migración y carga de datos

Responsable: Brian. Origen: `sql/esquema/schema.sql`, `sql/carga/carga_masiva.sql`,
`salida_carga.txt` y `docs/rol2_base_de_datos.md`.

## Estructura

El esquema (12 tablas, restricciones y la extensión `btree_gist`) está en `sql/esquema/schema.sql`.
Se aplica solo la primera vez que arranca `db-hoteles`, porque el archivo está montado en
`/docker-entrypoint-initdb.d/`.

Para aplicarlo a mano sobre una base vacía:
```powershell
docker exec -i db-hoteles psql -U hoteles_app -d hoteles -f /docker-entrypoint-initdb.d/schema.sql
```

## Carga masiva

La consigna pide al menos 6.000.000 de registros. Los datos son sintéticos y se generan dentro
de PostgreSQL con `generate_series` (una sola sentencia por tabla, sin insertar fila por fila).

| Tabla | Cantidad | Cómo |
|---|---|---|
| `hotel` | 50 | `generate_series(1, 50)` |
| `habitacion` | 200 por hotel | `hotel CROSS JOIN generate_series(1, 200)` |
| `huesped` | 500.000 | `generate_series(1, 500000)` |
| `reserva` | 6.000.000 | Se reparten entre las habitaciones |

**Cómo se evita que las reservas se superpongan.** No se usan fechas al azar. Para cada
habitación se arma una secuencia: cada reserva dura de 1 a 7 noches y deja de 1 a 3 días libres
antes de la siguiente. La fecha de inicio de cada una es la suma acumulada de las anteriores
(una función de ventana `SUM(...) OVER (PARTITION BY habitacion_id ORDER BY rn)`). Así, por
construcción, dos reservas de la misma habitación nunca se pisan.

**Por qué se quita la restricción antes de cargar.** El script hace
`ALTER TABLE reserva DROP CONSTRAINT reserva_habitacion_id_daterange_excl` antes de insertar y la
vuelve a crear al final. Mantener un índice GiST mientras se insertan 6 millones de filas es
mucho más lento que construirlo una vez al terminar.

Para ejecutarla, una forma es copiar el archivo al contenedor y correrlo con `psql`:
```powershell
docker cp sql\carga\carga_masiva.sql db-hoteles:/tmp/carga_masiva.sql
```
```powershell
docker exec db-hoteles psql -U hoteles_app -d hoteles -f /tmp/carga_masiva.sql
```
[PENDIENTE – Brian – confirmar que este es el comando que usó. En el repo está el script pero no
el comando con el que se ejecutó; el de arriba no fue probado con la carga completa.]

## Tiempos medidos

De `salida_carga.txt`:

| Paso | Tiempo |
|---|---|
| Insertar 500.000 huéspedes | 15,6 s |
| Insertar 6.000.000 de reservas | 91,3 s (1 min 31 s) |
| Volver a crear la restricción de no superposición | 230,5 s (3 min 50 s) |

## Evidencia de volumen

Consultas de `docs/rol2_base_de_datos.md`, sección 3:

```sql
SELECT relname AS tabla, n_live_tup AS filas FROM pg_stat_user_tables ORDER BY n_live_tup DESC;
SELECT count(*) FROM reserva;
SELECT pg_size_pretty(pg_database_size('hoteles')) AS tamano_base;
SELECT pg_size_pretty(pg_relation_size('reserva')) AS tabla, pg_size_pretty(pg_indexes_size('reserva')) AS indices;
```

[PENDIENTE – Brian – pegar acá el resultado de estas consultas: cantidad de registros por tabla y
tamaño de la base. La consigna los pide documentados.]

## Restricciones de integridad

Todas están en `sql/esquema/schema.sql`: claves primarias y foráneas, `UNIQUE` (documento del
huésped, número de habitación por hotel), `CHECK` (estrellas de 1 a 5, capacidad mayor que 0,
`fecha_fin > fecha_inicio`, estados permitidos) y la restricción `EXCLUDE` de no superposición.

## Puntos abiertos

- [PENDIENTE – Brian – `salida_carga.txt` es de una ejecución sobre una base que ya tenía datos:
  muestra errores de clave duplicada y, al final, "could not create exclusion constraint". Hay que
  volver a generarlo con una carga limpia sobre una base vacía y confirmar con `\d reserva` que la
  restricción quedó creada.]
- [PENDIENTE – Brian – la consigna dice "al menos 6.000.000 registros por tabla de datos que forme
  parte del conjunto de prueba". Hoy `reserva` tiene 6.000.000 y `huesped` 500.000. Falta dejar
  escrito cuáles son las tablas del conjunto de prueba.]
- [PENDIENTE – Brian – `rendimiento_y_concurrencia/salida_48_mantenimiento.txt` muestra 18.000.096
  filas en `reserva`, no 6.000.000 (el commit `d5b2098` corrigió después el volumen de 18M a 6M). Conviene
  regenerar esa salida para que toda la evidencia muestre el mismo volumen.]
- [PENDIENTE – Brian – tiempo y resultado de las copias de seguridad con la base cargada.]
- En la PC donde se armó esta documentación la base tenía solo el esquema (0 filas): la carga
  hay que repetirla en la PC de la defensa.
