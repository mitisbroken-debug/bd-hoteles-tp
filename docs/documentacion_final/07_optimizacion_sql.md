# 7. Informe de optimización SQL

Responsable: Brian. Esta sección resume lo que hay en el repositorio y dónde está cada cosa.

## Dónde está el trabajo

| Archivo | Qué tiene |
|---|---|
| `sql/consultas/consultas_complejas.sql` y `salida_consultas.txt` | Las consultas de trabajo y su salida |
| `sql/consultas/baseline_optimizacion.sql` y `salida_baseline.txt` | Las consultas **antes** de optimizar, con `EXPLAIN (ANALYZE, BUFFERS)` |
| `sql/consultas/despues_optimizacion.sql` y `salida_despues.txt` | Las mismas consultas **después**, con sus planes |
| `sql/consultas/confirmacion.sql` y `salida_confirmacion.txt` | Confirmación de resultados y costo de los `INSERT` |
| `indices/*.sql` y `indices/salida_*.txt` | Pruebas de índices: compuesto, prefijo izquierdo, cobertura, sargabilidad, índice funcional |
| `rendimiento_y_concurrencia/` | Configuración del motor, buffers, estadísticas, pool, log de consultas lentas, mantenimiento, particionamiento |

## Consultas optimizadas

De `baseline_optimizacion.sql` y `despues_optimizacion.sql`:

| Consulta | Problema original | Cambio |
|---|---|---|
| Q3 – huéspedes sin reservas | `LEFT JOIN ... WHERE r.id IS NULL` sobre 6M de filas, y `reserva.huesped_id` no tenía índice | `NOT EXISTS` + índice `idx_reserva_huesped` |
| Q6 – hoteles con más reservas | Un `JOIN` a `tipo_habitacion` que no se usaba | Se quitó el `JOIN` de sobra |
| Q7 – ingresos por hotel y tipo | Agrupaba por textos (nombres) | Se agrupa por IDs y los nombres se traducen al final |
| Q8 – huéspedes que más gastaron | Unía `huesped` con todas las filas antes de agrupar | Se agrupa por `huesped_id`, se toma el top 10 y recién ahí se une con `huesped` |
| Q10 – comodidades más usadas | Un `JOIN` a `hotel` que no se usaba | Se quitó |
| Q16 – reservas por rango de fechas | `SELECT *` | Solo las columnas necesarias |
| Q17 – paginado | `OFFSET` (recorre y descarta filas) | Paginado por clave: `WHERE id > ... ORDER BY id LIMIT 20` |
| Q11 / Q12 – disponibilidad | Dos formas de escribir la superposición (comparaciones de fechas y operador `&&`) | Se comparan los dos planes |

[PENDIENTE – Brian – confirmar que estas son las 8 consultas que se presentan (la consigna pide
al menos 8) y completar una tabla con el tiempo antes y después de cada una. Los números están
en `salida_baseline.txt` y `salida_despues.txt`.]

## Índices

Creados sobre `reserva` (origen: `despues_optimizacion.sql` e `indices/*.sql`):

| Índice | Columnas | Para qué |
|---|---|---|
| `idx_reserva_huesped` | `(huesped_id)` | La clave foránea no tenía índice: las búsquedas por huésped recorrían toda la tabla |
| `idx_reserva_hab_fecha` | `(habitacion_id, fecha_inicio)` | Índice compuesto. Sirve también para buscar solo por `habitacion_id` (regla del prefijo izquierdo) |
| `idx_reserva_cobertura` | `(habitacion_id, fecha_inicio) INCLUDE (fecha_fin, estado)` | Índice de cobertura: la consulta se responde sin ir a la tabla |
| `idx_reserva_huesped_cob` | `(huesped_id) INCLUDE (fecha_inicio, fecha_fin, estado)` | Cobertura para el listado de reservas de un huésped |
| `idx_reserva_anio` | `(EXTRACT(YEAR FROM fecha_inicio))` | Índice funcional, para la prueba de consultas no sargables |

**Por qué no se crean índices de más.** Según `docs/rol2_base_de_datos.md`: los índices de
`reserva` pesan más que la tabla y cada uno encarece los `INSERT`. Por eso cada índice se
justifica con una consulta concreta y se mide su costo (`confirmacion.sql`).

## Consultas no sargables

En `indices/sargabilidad_y_funcional.sql` y `sargabilidad_v2.sql` se prueba qué pasa cuando la
columna está dentro de una función (por ejemplo `EXTRACT(YEAR FROM fecha_inicio) = 2022`): el
índice común no se puede usar. Las dos soluciones probadas son reescribir la condición como un
rango de fechas o crear un índice funcional.

## Configuración del motor

En `rendimiento_y_concurrencia/` están las salidas de la revisión de parámetros
(`salida_43_config.txt`), uso de buffers (`salida_44_buffers.txt`), pool de conexiones
(`salida_46_pool.txt`), consultas lentas (`salida_47_slowlog.txt`), mantenimiento con `VACUUM`
(`salida_48_mantenimiento.txt`) y particionamiento de `reserva` por fecha con poda de particiones
(`50_particionamiento.sql`, `51_pruning.sql`).

## Lo que falta para cerrar el informe

- [PENDIENTE – Brian – un informe redactado: qué se midió, tabla de antes y después con tiempos,
  qué índice se agregó para cada consulta, cuánto pesa cada índice y cuánto encarece los `INSERT`.]
- [PENDIENTE – Brian – análisis de los parámetros del motor con los valores elegidos y su motivo
  (`shared_buffers`, `work_mem`, `maintenance_work_mem`, `max_connections`).]
- [PENDIENTE – Brian – la consigna pide usar una herramienta de análisis (nombra pgBadger). En el
  repo no hay ninguna.]
