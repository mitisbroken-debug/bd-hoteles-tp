# 13. Flujos de n8n

Responsable: Juan. La documentación completa está en [`n8n/README.md`](../../n8n/README.md):
diagramas, disparadores, condiciones, acciones, instalación, guion de demostración, evidencias de
las pruebas y análisis de riesgos. Acá va el resumen.

## Los tres flujos

| Flujo | Disparador | Qué hace | Componentes que integra |
|---|---|---|---|
| 1. Alertas de infraestructura | Webhook con token, llamado por Alertmanager | Valida la alerta, calcula la prioridad, registra la incidencia sin duplicarla, la crea en Mantis y avisa por mail | Prometheus y Alertmanager (10), Mantis (11), mail |
| 2. Verificación de backups | Todos los días 08:00, manual o webhook con token | Comprueba que el último backup existe, se puede leer, no está vacío y no es viejo. Si está bien, pide aprobación y lo restaura en una base de prueba | Backups de la base (4), mail |
| 3. Informe de rendimiento con IA | Todos los días 09:00, manual o webhook con token | Consulta 11 métricas, detecta anomalías con reglas, le pide un análisis a una IA, guarda el informe en Nextcloud y lo manda al equipo | Prometheus (10), IA, Nextcloud (12), mail |

Archivos: `n8n/flujos/01_alertas_infraestructura.json`, `02_verificacion_backups.json` y
`03_informe_rendimiento_ia.json`. No contienen credenciales.

## Cómo se cumplen las actividades del punto 13

| Actividad | Cómo |
|---|---|
| Desplegar n8n en Docker | `n8n/docker-compose.yml`, a partir del compose del instalador oficial |
| Persistencia y protección de credenciales | Volumen `n8n-data`. Credenciales cifradas por n8n; las claves solo están en `.env`, que no se sube |
| Integrar al menos tres componentes | Prometheus/Alertmanager, backups, Mantis, Nextcloud y mail |
| Al menos tres flujos funcionales | Tres |
| Validación de datos y manejo de errores | Nodos de validación al entrar; cada tarea que puede fallar tiene un camino alternativo |
| Registrar las ejecuciones y sus resultados | Historial de n8n (14 días) y 4 tablas de control |
| Documentar disparadores, condiciones y acciones | `n8n/README.md` |
| Probar qué pasa cuando una tarea falla | Probado: Mantis caído, mail caído, Prometheus inalcanzable, IA sin clave, backup viejo, restauración rechazada |

## Requisitos de seguridad

| Requisito | Cómo se cumple |
|---|---|
| Proteger la interfaz de administración | Cuenta de dueño con usuario y clave; puerto solo en `127.0.0.1` |
| Autenticar los webhooks | Token en la cabecera `Authorization`. Sin token: 403 |
| Sin secretos en los flujos | Los flujos solo nombran la credencial |
| Restringir permisos de las credenciales | Usuario de base sin permisos de borrado ni de administración; token de Mantis de un usuario que solo reporta; contraseña de aplicación en Nextcloud |
| Validar los datos recibidos | Forma del aviso, lista de caracteres permitidos, recorte de textos, nombres de archivo con formato fijo |
| Controlar acciones que puedan interrumpir servicios | Ningún flujo detiene ni reinicia nada. Backups en solo lectura. Restauración en una base aparte |
| Aprobación humana antes de acciones críticas | La restauración espera que una persona toque "Aprobar" en un mail con enlace firmado |

## Registro

Tablas de la base `automatizacion` (contenedor `n8n-db-verificacion`):

| Tabla | Qué guarda |
|---|---|
| `incidencias_alertas` | Una fila por incidencia: alerta, prioridad, estado, repeticiones, dónde quedó registrada |
| `verificaciones_backup` | Una fila por verificación: archivo, tamaño, antigüedad, estado, aprobación, resultado de la restauración |
| `informes_rendimiento` | Una fila por informe: métricas, anomalías, si se usó IA, dónde quedó y el texto completo |
| `errores_flujos` | Una fila por tarea que falló: flujo, tarea, detalle y número de ejecución |

## Resultado de las pruebas (17/11/2026)

| Flujo | Probado | Resultado |
|---|---|---|
| 1 | Sin token, token incorrecto, datos inválidos, alerta maliciosa, alertas válidas, repetidas, resueltas, Mantis caído, mail caído, camino real desde Alertmanager | Todo como se esperaba. Detalle en `n8n/README.md` |
| 2 | Backup viejo, backup aceptado, firma alterada, aprobar, rechazar | 12 tablas restauradas al aprobar; 401 con la firma alterada |
| 3 | Métricas reales, sin IA, con y sin Nextcloud, Prometheus inalcanzable | 11 de 11 métricas; el informe sale aunque falle la IA |

## Pendiente

- [PENDIENTE – Seba – Mantis real. La integración se probó contra un simulador de su API.]
- [PENDIENTE – Fede – Nextcloud real. La integración se probó contra un simulador de WebDAV.]
- [PENDIENTE – Juan – prueba con la cuenta real de Brevo y con la clave real de Gemini.]
