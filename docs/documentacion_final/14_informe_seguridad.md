# 14. Informe de seguridad

Responsable: Fede.

Esta sección reúne el análisis de seguridad del proyecto: los **controles que ya existen** (cada uno con el archivo donde se puede comprobar), los **hallazgos** de las revisiones, los resultados de los **escaneos** y de las **pruebas controladas**, y el **procedimiento de respuesta ante incidentes**.

Por tratarse de un repositorio público, aquí se resume cada hallazgo sin los detalles que permitirían explotarlo. El informe completo, con las salidas originales de las herramientas, se conserva en la carpeta `09_Seguridad` de Nextcloud (sección 12).

## Entregables de la consigna

| Entregable | Estado | Dónde |
|---|---|---|
| Matriz de amenazas | Hecho | [`docs/matriz-amenazas.md`](../matriz-amenazas.md) y resumen en esta sección |
| Informe de vulnerabilidades | Hecho. Correcciones pendientes | Resumen en esta sección. Informe completo en Nextcloud (`09_Seguridad`) |
| Evidencias de escaneo y corrección | Escaneo "antes" hecho. Falta el escaneo "después" | Salidas de Trivy en Nextcloud (`09_Seguridad`) |
| Resultados de pruebas controladas | Hecho el 19/11/2026. Falta repetirlas tras las correcciones | Resumen en esta sección. Salida completa en Nextcloud |
| Configuración de controles de seguridad | Parcial | Controles existentes más abajo |
| Procedimiento de respuesta y recuperación | Hecho | [`docs/plan-respuesta-incidentes.md`](../plan-respuesta-incidentes.md). La recuperación de la base está en las secciones 8 y 15 |
| Evidencias del flujo de incidentes integrado con n8n | Hecho: flujo 1 de n8n | Sección 13 y `n8n/README.md` |

La consigna pide considerar: ransomware, DDoS, robo de credenciales, vulnerabilidades de dependencias, ataques a la cadena de suministro, inyección SQL, fallas de autorización, abuso de API y webhooks, y riesgos de sistemas de IA. La matriz de amenazas cubre todas.

## Matriz de amenazas (resumen)

Escala: Baja, Media o Alta. Son estimaciones del equipo para un entorno de pruebas con datos sintéticos. La matriz completa, con componentes, controles existentes y a implementar y responsables, está en [`docs/matriz-amenazas.md`](../matriz-amenazas.md).

| ID | Amenaza | Riesgo | Verificación (19/11/2026) |
|---|---|---|---|
| A1 | Inyección SQL | Medio | Control efectivo en los puntos probados |
| A2 | Fallas de autorización | Alto | Confirmada |
| A3 | Abuso de la API | Alto | Confirmada |
| A4 | Denegación de servicio (DDoS) | Medio | Falta limitación de pedidos (confirmado) |
| A5 | Robo de credenciales | Alto | Incidente real en la plantilla de variables (ver "Incidente real") |
| A6 | Interfaces administrativas expuestas | Alto | Confirmada |
| A7 | Vulnerabilidades en dependencias e imágenes | Alto | Escaneo realizado (ver "Escaneos") |
| A8 | Ataque a la cadena de suministro | Medio | Parcialmente controlado: versiones fijas en monitoreo y n8n; faltan en otras imágenes y en el pipeline |
| A9 | Ransomware | Medio | Backups con restauración de prueba (secciones 8 y 15) |
| A10 | Abuso de webhooks | Medio | Controlado: token obligatorio y validación (sección 13) |
| A11 | Riesgos de IA | Medio | Controlado: la IA recibe solo métricas agregadas (sección 13) |
| A12 | Escalada desde contenedores | Medio | Sin pruebas |
| A13 | Exposición por el túnel a Internet | Alto | Pendiente: depende del punto 9 |
| A14 | Fuga de datos en la documentación | Medio | Controlado con permisos por carpeta (sección 12) |
| A15 | Pérdida de integridad en reservas | Medio | La base impide reservas superpuestas con una restricción `EXCLUDE` |

## Controles que ya existen

### Aplicación

Origen: `backend/src/server.js` y `backend/README.md`.

| Amenaza | Control |
|---|---|
| Inyección SQL | Todas las consultas usan parámetros (`$1`, `$2`). No se arma SQL con texto del usuario |
| Datos inválidos | Se validan antes de llegar a la base: enteros positivos y fechas reales con formato `AAAA-MM-DD` |
| Pedidos gigantes | Límite de 10 KB por pedido (`express.json({ limit: '10kb' })`) |
| Consultas que no terminan | Límite de 10 s por consulta (`statement_timeout`) |
| Fuga de información en errores | Los errores internos devuelven "Error interno", sin detalles |
| Identificación del servidor | Se quita la cabecera `X-Powered-By` |
| Reservas superpuestas | Lo impide la base con una restricción `EXCLUDE`, no depende de la API |

### Docker e infraestructura

| Amenaza | Control | Origen |
|---|---|---|
| Robo de credenciales desde el repo | Claves solo en archivos `.env`, ignorados por git. En el repo hay `.env.example` con valores de ejemplo | `.gitignore`, `monitoreo/.gitignore`, `n8n/.gitignore` |
| Contenedor de la API comprometido | Corre con el usuario `node`, no como administrador, y solo con dependencias de producción | `backend/Dockerfile` |
| Acceso a herramientas de administración | Prometheus, Grafana, Alertmanager y n8n se publican solo en `127.0.0.1`. Grafana sin acceso anónimo ni registro | `monitoreo/docker-compose.yml`, `n8n/docker-compose.yml` |
| Recarga o apagado remoto de Prometheus | No se activa `--web.enable-lifecycle` | `monitoreo/README.md` |
| Imágenes que cambian sin aviso | Versiones fijas en monitoreo, n8n y Nextcloud | `monitoreo/docker-compose.yml`, `n8n/docker-compose.yml`, `nextcloud/docker-compose.yml` |
| Contenedores con privilegios | En n8n se descartó el *sandbox* del instalador, que usa `privileged: true` | `n8n/README.md` |
| Pérdida de datos (falla o ransomware) | Backups automáticos con verificación y restauración de prueba; réplica en otro contenedor | Secciones 8 y 15 |
| Conexión de réplica sin clave | La replicación entre contenedores pide clave (`scram-sha-256`) | `docker-compose.yml` |
| Acceso indebido a la documentación | Nextcloud con carpetas por grupo, permisos por rol, enlaces públicos con contraseña y caducidad obligatorias, y solo accesible desde el equipo local | `nextcloud/`, sección 12 |

### Automatizaciones (n8n)

Origen: `n8n/README.md`, "Requisitos de seguridad" y "Análisis de riesgos".

| Amenaza | Control |
|---|---|
| Abuso de webhooks | Token obligatorio (403 sin él), validación de datos, tope de alertas por aviso |
| Credenciales con demasiado permiso | Usuario de base sin borrado ni administración; token de Mantis de un usuario que solo reporta |
| Acciones automáticas peligrosas | Ningún flujo detiene ni reinicia servicios. La restauración pide aprobación humana |
| Riesgos de IA | La IA no decide números ni estados; recibe solo métricas de infraestructura, sin datos personales; el informe sale aunque falle |

### CI/CD y cadena de suministro

| Amenaza | Control | Origen |
|---|---|---|
| Fuga de credenciales del pipeline | Usuario y clave de Docker Hub en GitHub Secrets | `.github/workflows/docker-ci-cd.yml` (rama `develop`) |
| Publicar un cambio que no compila | Si el `docker build` falla, no se publica; en Pull Requests no se publica | ídem |
| Dependencias vulnerables | Las dependencias propias del backend no tienen vulnerabilidades según Trivy (ver "Escaneos"). Versiones fijas en `package.json` y `package-lock.json` | `backend/` |

## Escaneos de vulnerabilidades (19/11/2026)

Herramienta: Trivy 0.69.3, con la versión fijada y ejecutada con Docker. No se usó la etiqueta `latest` por el incidente de cadena de suministro que afectó a esa herramienta y a su acción de GitHub en 2026 (matriz, A8).

| Objetivo | Críticas | Altas | Medias |
|---|---|---|---|
| Dependencias propias del backend (`package-lock.json`) | 0 | 0 | 0 |
| Imagen del backend: paquetes del sistema (imagen base `node:20-alpine`) | 0 | 7 | no medido |
| Imagen del backend: `npm` incluido en la imagen base | 1 | 21 | no medido |
| Imagen del frontend (`nginx:alpine`) | 0 | 0 | 1 |
| Configuración de los Dockerfile | 0 | 1 | 0 (2 bajas) |
| Secretos en el repositorio | 0 | – | – |

Conclusiones:
- El código propio del backend y sus dependencias están limpios. Los hallazgos graves vienen de la **imagen base**: paquetes del sistema desactualizados y el gestor `npm`, que la aplicación no necesita para ejecutarse.
- Se corrigen reconstruyendo las imágenes: actualizar paquetes al construir, usar una versión de Node vigente, quitar `npm` de la imagen final, ejecutar el frontend sin privilegios de administrador y agregar chequeos de salud.
- Las salidas completas y las correcciones propuestas están en el informe de vulnerabilidades de Nextcloud.

Limitaciones: no se escanearon todavía las imágenes de la base de datos, pgAdmin, monitoreo, n8n ni Nextcloud. El escaneo de secretos revisa los archivos actuales, no el historial de commits.

## Pruebas controladas (19/11/2026)

Realizadas con el script `pruebas-controladas.sh`, contra el entorno local propio y con datos sintéticos.

| Prueba | Amenaza | Resultado |
|---|---|---|
| Inyección SQL en los parámetros de consulta | A1 | Las 4 entradas maliciosas fueron rechazadas por la validación. Control efectivo |
| Acceso sin credenciales | A2 | Se pudo consultar y modificar reservas sin autenticarse. Falla confirmada |
| CORS con un origen ajeno | A3 | La API acepta cualquier origen. Falla confirmada |
| Límite de pedidos (150 seguidos) | A3, A4 | Ninguno fue limitado. Falla confirmada |
| Cabeceras de seguridad HTTP | A3 | Faltan las principales. Mejora necesaria |
| Puertos publicados en el equipo | A6 | La base, la réplica y pgAdmin quedan abiertos en todas las interfaces. Falla confirmada |

Alcance de las pruebas: parámetros de consulta de cuatro endpoints. No se probó el cuerpo de las peticiones de escritura ni se usaron herramientas automáticas de inyección. Que no se haya logrado explotar la inyección SQL no implica que no pueda existir.

Con los resultados de las pruebas se prepararon las correcciones propuestas y se asignaron a los responsables. Después de aplicarlas se repiten los escaneos y las pruebas para completar el resultado "después".

## Incidente real durante el proyecto: credenciales en una plantilla

Durante la revisión del 19/11/2026, el equipo detectó que la plantilla de variables de Nextcloud (`nextcloud/.env.example`) contenía credenciales reales en lugar de valores de ejemplo, en un repositorio público. Se resolvió con el procedimiento del plan de respuesta:

| Fase | Qué se hizo |
|---|---|
| Detección | La revisión cruzada del equipo y el escaneo de archivos del repositorio |
| Contención | Se cambiaron de inmediato las claves de la instancia (administrador y base de datos) |
| Erradicación | Se devolvió la plantilla a valores de ejemplo mediante un Pull Request |
| Recuperación | Se verificó el acceso con la clave nueva y que los servicios siguen funcionando |
| Lección | Antes de cada commit se revisa el contenido, no solo el nombre, de los archivos de variables |

Como Git conserva el historial, no basta con borrar el valor: lo que resuelve el incidente es haber cambiado las claves.

## Hallazgos detectados en las revisiones

Estado al 19/11/2026. Ninguno está corregido todavía en `develop`.

| # | Hallazgo | Dónde | Riesgo | Verificado |
|---|---|---|---|---|
| 1 | La API no tiene autenticación ni control de roles | `backend/src/server.js` | Cualquiera que llegue a la API puede crear y cancelar reservas. Se agrava al publicarla en Internet | Sí |
| 2 | CORS acepta cualquier origen (`CORS_ORIGIN` vale `*` por defecto) | `backend/docker-compose.yml` | Cualquier página web puede llamar a la API desde el navegador de un usuario | Sí |
| 3 | La API no limita la cantidad de pedidos | `backend/README.md` lo menciona como mejora | Abuso de API, DDoS a nivel de aplicación | Sí |
| 4 | Los puertos de la base (5440, 5442) y de pgAdmin (5050) se publican en todas las interfaces | `docker-compose.yml` | Se ven desde cualquier máquina de la misma red. La consigna pide no exponer la base ni las interfaces administrativas | Sí |
| 5 | `pgadmin4:latest` y `nginx:alpine` no tienen versión fija | `docker-compose.yml`, `frontend/Dockerfile` | La imagen puede cambiar entre un despliegue y otro (cadena de suministro) | Revisión de código |
| 6 | El pipeline no escanea imágenes ni dependencias | `.github/workflows/docker-ci-cd.yml` | Una dependencia vulnerable llegaría a publicarse | Revisión de código |
| 7 | Los exportadores de monitoreo usan el mismo usuario de la aplicación | `monitoreo/.env.example` (está anotado como pendiente) | Más permiso del necesario. Debería ser un usuario de solo lectura con el rol `pg_monitor` | Revisión de código |
| 8 | El historial tiene commits directos a `develop` sin revisión | Historial de Git | Un cambio sin revisar puede llegar a la rama de integración | Revisión del historial |
| 9 | Dentro del contenedor de la base, las conexiones locales al principal usan `trust` | `docker-compose.yml` (`pg_hba.conf`) | Solo aplica a conexiones desde el propio contenedor. Las conexiones por red sí piden clave | Revisión de código |
| 10 | El contenedor del frontend corre como administrador y ningún Dockerfile tiene chequeo de salud | `frontend/Dockerfile`, `backend/Dockerfile` | Mayor impacto si el contenedor se compromete; Docker no detecta un servicio colgado | Escaneo |
| 11 | La imagen del backend parte de una base desactualizada (`node:20-alpine`) con paquetes y `npm` vulnerables | `backend/Dockerfile` | Vulnerabilidades altas y una crítica en componentes que la aplicación no usa al ejecutarse | Escaneo |
| 12 | Faltan cabeceras de seguridad HTTP | API y frontend | Menor protección contra ataques desde el navegador | Prueba (API) |

## Correcciones propuestas

| Hallazgo | Corrección | Responsable |
|---|---|---|
| 1 | Autenticación con token para crear, confirmar y cancelar; cada usuario solo ve sus reservas | Fiore |
| 2 | Definir `CORS_ORIGIN` con la dirección real del frontend (el código ya lo admite) | Fiore |
| 3 | Limitar pedidos por dirección, en la API o en el proxy o túnel | Fiore / Seba |
| 4 | Quitar los puertos publicados de la base y la réplica; pgAdmin solo en `127.0.0.1` | Brian |
| 5, 6 | Fijar versiones; agregar Trivy al pipeline para bloquear la publicación ante vulnerabilidades críticas, con versión fija y referencias exactas | Fiore |
| 7 | Crear un usuario de solo lectura para el monitoreo | Brian / Juan |
| 8 | Proteger `develop` con revisión obligatoria de Pull Requests | Seba |
| 10, 11 | Actualizar el Dockerfile del backend (versión vigente de Node, actualizar paquetes, quitar `npm`), usar un nginx sin privilegios en el frontend y agregar `HEALTHCHECK` | Fiore |
| 12 | Cabeceras en la configuración de nginx y en la API | Fiore |

Cada hallazgo se registra como incidencia en Mantis (sección 12) con pasos de reproducción, corrección y verificación.

## Procedimiento de respuesta ante incidentes

Resumen. El procedimiento completo, con roles, severidades y escenarios previstos, está en [`docs/plan-respuesta-incidentes.md`](../plan-respuesta-incidentes.md).

1. **Detección:** alertas de Prometheus y Alertmanager, escaneos, resultados del pipeline, revisión de registros y avisos del equipo. Las alertas llegan a n8n, que registra la incidencia y notifica (flujo 1, sección 13).
2. **Clasificación y registro:** identificador, severidad y responsable en Mantis.
3. **Contención:** aislar el componente, cerrar el acceso externo, revocar o cambiar credenciales. Toda acción que interrumpa el servicio requiere aprobación humana.
4. **Erradicación:** corregir la causa, reconstruir imágenes desde fuentes verificadas y volver a escanear.
5. **Recuperación:** restaurar desde un backup verificado (secciones 8 y 15), levantar los servicios en orden y comprobar que funcionan.
6. **Cierre:** documentar causa, línea de tiempo y mejoras; actualizar la matriz de amenazas.

## Lo que falta

- Aplicar las correcciones de la tabla anterior y repetir los escaneos y las pruebas controladas, para completar el resultado "después".
- Ampliar las pruebas: cuerpo de las peticiones de escritura, herramientas automáticas de inyección SQL, acceso a los puertos desde otra máquina de la red y cabeceras del frontend.
- Escanear el resto de las imágenes y el historial del repositorio en busca de secretos.
- HTTPS y control de acceso de la publicación en Internet (punto 9, Seba).
