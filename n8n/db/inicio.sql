-- Base "automatizacion": tablas de control de los flujos de n8n (punto 13).
-- Se ejecuta sola la primera vez que arranca el contenedor n8n-db-verificacion.
--
-- Idea de seguridad: n8n entra con el usuario "n8n_flujos", que NO es administrador.
-- Solo puede leer, insertar y actualizar las 4 tablas de control y llamar a 5 funciones.
-- No puede borrar registros, ni crear tablas, ni leer archivos, ni ejecutar programas.
-- Las tareas delicadas (leer la carpeta de backups, ejecutar pg_restore) están
-- encerradas en funciones que validan lo que reciben.

\set ON_ERROR_STOP on

-- ------------------------------------------------------------------
-- 1. Tablas de control
-- ------------------------------------------------------------------

-- Flujo 1: una fila por incidencia nacida de una alerta de Prometheus.
CREATE TABLE incidencias_alertas (
    id            bigserial PRIMARY KEY,
    huella        text        NOT NULL,              -- alerta + instancia: identifica "el mismo problema"
    alerta        text        NOT NULL,
    instancia     text        NOT NULL DEFAULT '',
    severidad     text        NOT NULL,
    impacto       text        NOT NULL,
    urgencia      text        NOT NULL,
    prioridad     text        NOT NULL,
    estado        text        NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta', 'resuelta')),
    resumen       text,
    descripcion   text,
    inicio        timestamptz,
    fin           timestamptz,
    repeticiones  integer     NOT NULL DEFAULT 1,    -- cuántas veces avisó Alertmanager por lo mismo
    registro      text        NOT NULL DEFAULT 'pendiente' CHECK (registro IN ('pendiente', 'mantis', 'local')),
    mantis_id     bigint,
    ejecucion_n8n text,
    creada        timestamptz NOT NULL DEFAULT now(),
    actualizada   timestamptz NOT NULL DEFAULT now()
);

-- No puede haber dos incidencias ABIERTAS del mismo problema: lo garantiza la base,
-- no solo el flujo (aunque lleguen dos avisos al mismo tiempo).
CREATE UNIQUE INDEX incidencia_abierta_unica ON incidencias_alertas (huella) WHERE estado = 'abierta';

-- Flujo 2: una fila por cada verificación de backup.
CREATE TABLE verificaciones_backup (
    id                 bigserial PRIMARY KEY,
    fecha              timestamptz NOT NULL DEFAULT now(),
    archivo            text,
    bytes              bigint,
    modificado         timestamptz,
    antiguedad_horas   numeric(10, 2),
    legible            boolean,
    objetos            integer,                       -- cantidad de objetos que lista pg_restore
    estado             text NOT NULL CHECK (estado IN ('ok', 'sin_backup', 'viejo', 'chico', 'ilegible', 'error')),
    detalle            text,
    aprobacion         text NOT NULL DEFAULT 'no_corresponde'
                       CHECK (aprobacion IN ('no_corresponde', 'pendiente', 'aprobada', 'rechazada', 'sin_respuesta')),
    restauracion       text NOT NULL DEFAULT 'no_ejecutada' CHECK (restauracion IN ('no_ejecutada', 'ok', 'error')),
    tablas_restauradas integer,
    filas_reserva      bigint,
    duracion_seg       numeric(10, 2),
    ejecucion_n8n      text
);

-- Flujo 3: una fila por informe de rendimiento.
CREATE TABLE informes_rendimiento (
    id            bigserial PRIMARY KEY,
    fecha         timestamptz NOT NULL DEFAULT now(),
    metricas      jsonb       NOT NULL,
    anomalias     jsonb       NOT NULL DEFAULT '[]'::jsonb,
    uso_ia        boolean     NOT NULL DEFAULT false,
    modelo        text,
    destino       text        NOT NULL DEFAULT 'local' CHECK (destino IN ('nextcloud', 'local')),
    ruta          text,
    contenido     text        NOT NULL,
    ejecucion_n8n text
);

-- Los 3 flujos: registro de errores (qué tarea falló, cuándo y por qué).
CREATE TABLE errores_flujos (
    id            bigserial PRIMARY KEY,
    fecha         timestamptz NOT NULL DEFAULT now(),
    flujo         text NOT NULL,
    tarea         text NOT NULL,
    detalle       text,
    ejecucion_n8n text
);

-- ------------------------------------------------------------------
-- 2. Flujo 1: registrar una alerta sin duplicar incidencias
-- ------------------------------------------------------------------
-- Recibe la alerta ya validada por n8n (como JSON) y devuelve qué hizo:
--   nueva         -> no había incidencia abierta: se crea
--   duplicada     -> ya había una abierta: solo se suma una repetición
--   resuelta      -> la alerta se resolvió: se cierra la incidencia abierta
--   sin_incidencia-> llegó un "resuelta" de algo que no estaba registrado
CREATE FUNCTION registrar_alerta(p jsonb)
RETURNS TABLE (accion text, incidencia_id bigint, mantis_id bigint, registro text, repeticiones integer,
               alerta text, instancia text, severidad text, impacto text, urgencia text, prioridad text,
               resumen text, descripcion text, inicio timestamptz, fin timestamptz)
LANGUAGE plpgsql
AS $fn$
#variable_conflict use_column
DECLARE
    v incidencias_alertas%ROWTYPE;
BEGIN
    IF p->>'huella' IS NULL OR p->>'alerta' IS NULL OR p->>'estado' NOT IN ('firing', 'resolved') THEN
        RAISE EXCEPTION 'Alerta incompleta: faltan huella, alerta o estado';
    END IF;

    IF p->>'estado' = 'resolved' THEN
        UPDATE incidencias_alertas i
           SET estado = 'resuelta',
               fin = COALESCE(NULLIF(p->>'fin', '')::timestamptz, now()),
               actualizada = now()
         WHERE i.huella = p->>'huella' AND i.estado = 'abierta'
        RETURNING i.* INTO v;
        IF NOT FOUND THEN
            RETURN QUERY SELECT 'sin_incidencia'::text, NULL::bigint, NULL::bigint, NULL::text, NULL::integer,
                                p->>'alerta', COALESCE(p->>'instancia', ''), NULL::text, NULL::text, NULL::text, NULL::text,
                                NULL::text, NULL::text, NULL::timestamptz, NULL::timestamptz;
        ELSE
            RETURN QUERY SELECT 'resuelta'::text, v.id, v.mantis_id, v.registro, v.repeticiones,
                                v.alerta, v.instancia, v.severidad, v.impacto, v.urgencia, v.prioridad,
                                v.resumen, v.descripcion, v.inicio, v.fin;
        END IF;
        RETURN;
    END IF;

    -- Alerta activa: se intenta crear. Si ya hay una abierta, el índice único lo impide
    -- y en su lugar se suma una repetición.
    INSERT INTO incidencias_alertas AS i
           (huella, alerta, instancia, severidad, impacto, urgencia, prioridad,
            resumen, descripcion, inicio, ejecucion_n8n)
    VALUES (p->>'huella', p->>'alerta', COALESCE(p->>'instancia', ''), p->>'severidad',
            p->>'impacto', p->>'urgencia', p->>'prioridad',
            p->>'resumen', p->>'descripcion',
            COALESCE(NULLIF(p->>'inicio', '')::timestamptz, now()), p->>'ejecucion')
    ON CONFLICT (huella) WHERE estado = 'abierta'
    DO UPDATE SET repeticiones = i.repeticiones + 1, actualizada = now()
    RETURNING i.* INTO v;

    RETURN QUERY SELECT CASE WHEN v.repeticiones = 1 THEN 'nueva' ELSE 'duplicada' END,
                        v.id, v.mantis_id, v.registro, v.repeticiones,
                        v.alerta, v.instancia, v.severidad, v.impacto, v.urgencia, v.prioridad,
                        v.resumen, v.descripcion, v.inicio, v.fin;
END;
$fn$;

-- ------------------------------------------------------------------
-- 3. Flujo 2: funciones para revisar y restaurar backups
-- ------------------------------------------------------------------
-- Son SECURITY DEFINER: se ejecutan con los permisos del administrador aunque las
-- llame n8n_flujos. Por eso validan el nombre del archivo con una expresión regular:
-- solo aceptan nombres como hoteles_20261113_045405.dump, nada de rutas ni comandos.

-- Último backup de la carpeta /backups (montada en solo lectura).
CREATE FUNCTION ultimo_backup()
RETURNS TABLE (archivo text, bytes bigint, modificado timestamptz, antiguedad_horas numeric)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog
AS $fn$
    SELECT f,
           (pg_stat_file('/backups/' || f)).size,
           (pg_stat_file('/backups/' || f)).modification,
           round((extract(epoch FROM now() - (pg_stat_file('/backups/' || f)).modification) / 3600)::numeric, 2)
      FROM pg_ls_dir('/backups') AS f
     WHERE f ~ '^hoteles_[0-9]{8}_[0-9]{6}\.dump$'
     ORDER BY f DESC
     LIMIT 1;
$fn$;

-- Comprueba que pg_restore puede leer el archivo (lista su contenido, no restaura nada).
CREATE FUNCTION revisar_backup(p_archivo text)
RETURNS TABLE (legible boolean, objetos integer, detalle text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $fn$
DECLARE
    v_cmd    text;
    v_salida text;
BEGIN
    IF p_archivo IS NULL OR p_archivo !~ '^hoteles_[0-9]{8}_[0-9]{6}\.dump$' THEN
        RAISE EXCEPTION 'Nombre de backup no permitido: %', p_archivo;
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS tmp_salida (linea text) ON COMMIT DROP;
    TRUNCATE tmp_salida;

    v_cmd := replace($cmd$pg_restore --list /backups/__ARCHIVO__ 2>&1; echo "__salida=$?"$cmd$,
                     '__ARCHIVO__', p_archivo);
    v_cmd := replace(v_cmd, E'\r', '');  -- por si el archivo quedó con saltos de línea de Windows
    EXECUTE format('COPY tmp_salida FROM PROGRAM %L WITH (FORMAT csv, DELIMITER E''\x01'', QUOTE E''\x02'')', v_cmd);

    SELECT split_part(linea, '=', 2) INTO v_salida FROM tmp_salida WHERE linea LIKE '\_\_salida=%';

    RETURN QUERY
    SELECT v_salida = '0',
           (SELECT count(*)::integer FROM tmp_salida
             WHERE linea IS NOT NULL AND linea !~ '^;' AND linea NOT LIKE '\_\_%'),
           CASE WHEN v_salida = '0' THEN 'pg_restore pudo leer el archivo'
                ELSE left((SELECT string_agg(linea, ' | ') FROM tmp_salida WHERE linea NOT LIKE '\_\_%'), 500)
           END;
END;
$fn$;

-- Lo que llama el flujo: busca el último backup y, si existe, lo revisa.
-- Siempre devuelve una fila (con archivo vacío si la carpeta no tiene backups).
CREATE FUNCTION verificar_ultimo_backup()
RETURNS TABLE (archivo text, bytes bigint, modificado timestamptz, antiguedad_horas numeric,
               legible boolean, objetos integer, detalle text)
LANGUAGE plpgsql
AS $fn$
#variable_conflict use_column
DECLARE
    u record;
    r record;
BEGIN
    SELECT * INTO u FROM ultimo_backup();
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::text, NULL::bigint, NULL::timestamptz, NULL::numeric,
                            false, 0, 'No hay ningún backup en la carpeta'::text;
        RETURN;
    END IF;
    SELECT * INTO r FROM revisar_backup(u.archivo);
    RETURN QUERY SELECT u.archivo, u.bytes, u.modificado, u.antiguedad_horas, r.legible, r.objetos, r.detalle;
END;
$fn$;

-- Restaura el backup en la base "restauracion_prueba" (se borra y se crea de nuevo cada vez)
-- y cuenta lo que quedó. No toca la base de producción: este servidor ni siquiera la ve.
CREATE FUNCTION restaurar_backup(p_archivo text)
RETURNS TABLE (ok boolean, tablas integer, filas_reserva bigint, segundos numeric, detalle text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $fn$
DECLARE
    v_cmd      text;
    v_inicio   timestamptz := clock_timestamp();
    v_salida   text;
    v_tablas   text;
    v_reservas text;
BEGIN
    IF p_archivo IS NULL OR p_archivo !~ '^hoteles_[0-9]{8}_[0-9]{6}\.dump$' THEN
        RAISE EXCEPTION 'Nombre de backup no permitido: %', p_archivo;
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS tmp_salida (linea text) ON COMMIT DROP;
    TRUNCATE tmp_salida;

    v_cmd := replace($cmd$
dropdb -U postgres --if-exists restauracion_prueba 2>&1
createdb -U postgres restauracion_prueba 2>&1
pg_restore -U postgres --no-owner --no-privileges -j 2 -d restauracion_prueba /backups/__ARCHIVO__ 2>&1
echo "__salida=$?"
echo "__tablas=$(psql -U postgres -d restauracion_prueba -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'" 2>/dev/null)"
echo "__reservas=$(psql -U postgres -d restauracion_prueba -Atc "SELECT count(*) FROM reserva" 2>/dev/null)"
$cmd$, '__ARCHIVO__', p_archivo);
    v_cmd := replace(v_cmd, E'\r', '');
    EXECUTE format('COPY tmp_salida FROM PROGRAM %L WITH (FORMAT csv, DELIMITER E''\x01'', QUOTE E''\x02'')', v_cmd);

    SELECT split_part(linea, '=', 2) INTO v_salida   FROM tmp_salida WHERE linea LIKE '\_\_salida=%';
    SELECT split_part(linea, '=', 2) INTO v_tablas   FROM tmp_salida WHERE linea LIKE '\_\_tablas=%';
    SELECT split_part(linea, '=', 2) INTO v_reservas FROM tmp_salida WHERE linea LIKE '\_\_reservas=%';

    RETURN QUERY
    SELECT v_salida = '0' AND COALESCE(NULLIF(v_tablas, '')::integer, 0) > 0,
           NULLIF(v_tablas, '')::integer,
           NULLIF(v_reservas, '')::bigint,
           round(extract(epoch FROM clock_timestamp() - v_inicio)::numeric, 2),
           CASE WHEN v_salida = '0' THEN 'Restauración correcta en la base restauracion_prueba'
                ELSE left(COALESCE((SELECT string_agg(linea, ' | ') FROM tmp_salida
                                     WHERE linea IS NOT NULL AND linea NOT LIKE '\_\_%'), 'pg_restore falló'), 500)
           END;
END;
$fn$;

-- ------------------------------------------------------------------
-- 4. Usuario limitado para n8n
-- ------------------------------------------------------------------
-- La clave llega por la variable de entorno N8N_DB_PASSWORD (sale del .env).
\set clave_n8n `echo "$N8N_DB_PASSWORD"`
CREATE ROLE n8n_flujos LOGIN PASSWORD :'clave_n8n';

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO n8n_flujos;
GRANT CONNECT ON DATABASE automatizacion TO n8n_flujos;

-- Tablas: leer, insertar y actualizar. Sin DELETE: el historial no se borra desde n8n.
GRANT SELECT, INSERT, UPDATE ON incidencias_alertas, verificaciones_backup,
                                informes_rendimiento, errores_flujos TO n8n_flujos;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO n8n_flujos;

-- Funciones: por defecto cualquiera puede ejecutarlas; se lo sacamos a todos y
-- se lo damos solo a n8n_flujos.
REVOKE EXECUTE ON FUNCTION registrar_alerta(jsonb), ultimo_backup(), revisar_backup(text),
                           verificar_ultimo_backup(), restaurar_backup(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION registrar_alerta(jsonb), ultimo_backup(), revisar_backup(text),
                          verificar_ultimo_backup(), restaurar_backup(text) TO n8n_flujos;
