# Matriz de amenazas – Sistema de Reservas de Hoteles

Práctica Integradora Final – Punto 14: Seguridad informática y amenazas actuales.
Responsable: Fede. Estado: borrador para revisión del equipo.

La matriz describe riesgos en general y los controles asociados. El detalle técnico de cada hallazgo, con evidencias de escaneo y corrección, se documenta en el informe de vulnerabilidades.

**Escala.** Probabilidad e impacto: Baja, Media o Alta. El riesgo resulta de combinarlas. Son estimaciones del equipo para un entorno de pruebas con datos sintéticos y se revisan después de las pruebas controladas.

## 1. Alcance

| Capa | Componentes |
|---|---|
| Aplicación | Frontend (nginx), API Node + Express |
| Datos | PostgreSQL primario y réplica, backups, pgAdmin |
| Contenedores e infraestructura | Docker Compose, red interna, Docker Desktop, túnel de acceso a Internet |
| CI/CD y cadena de suministro | GitHub, GitHub Actions, Docker Hub, dependencias npm e imágenes base |
| Observabilidad y automatización | Prometheus, Alertmanager, Grafana, n8n, Mantis o GLPI, Nextcloud |

## 2. Matriz

| ID | Amenaza | Componente | Cómo podría afectar | Prob. | Impacto | Riesgo | Control existente | Control a implementar | Resp. |
|---|---|---|---|---|---|---|---|---|---|
| A1 | Inyección SQL | API, base de datos | Lectura o alteración de datos de reservas y huéspedes | Baja | Alto | Medio | Consultas con parámetros y validación de entradas (verificado en prueba controlada) | Usuario de aplicación con permisos mínimos; ampliar la prueba al cuerpo de las peticiones y con herramientas especializadas | Fede / BD |
| A2 | Fallas de autorización | API | Consultar, confirmar o cancelar reservas de otros usuarios | Alta | Alto | Alto | Ninguno | Autenticación, control de acceso por usuario y verificación de propiedad del recurso | Fiore |
| A3 | Abuso de la API | API | Consumo excesivo, enumeración de datos, saturación | Alta | Medio | Alto | Paginación y límites en algunas consultas | Limitación de pedidos, CORS restringido, registro de accesos | Fiore |
| A4 | Denegación de servicio (DDoS) | Frontend, API, túnel | Servicio no disponible durante la demostración | Media | Medio | Medio | Alerta de disponibilidad en Prometheus | Límites de pedidos, protección del túnel o proxy, tiempos de espera | Seba |
| A5 | Robo de credenciales | `.env`, repositorio, CI/CD, pgAdmin | Acceso a la base o al registro de imágenes | Media | Alto | Alto | `.env` ignorado por Git, plantilla `.env.example` | Escaneo de secretos en el repo y su historial, tokens con permisos mínimos, rotación | Fede |
| A6 | Interfaces administrativas expuestas | pgAdmin, base de datos, Grafana, Prometheus | Acceso de terceros a la administración de datos | Media | Alto | Alto | Monitoreo publicado solo en la máquina local | Publicar al host únicamente lo necesario; administración accesible solo desde localhost | Seba / Fede |
| A7 | Vulnerabilidades en dependencias e imágenes | npm, imágenes Docker | Explotación de fallas conocidas | Alta | Medio | Alto | Imágenes oficiales y ligeras | Escaneo con Trivy, versiones fijas, actualización de versión de Node | Fede |
| A8 | Ataque a la cadena de suministro | GitHub Actions, Docker Hub, npm | Imagen o dependencia alterada que llega a producción | Baja | Alto | Medio | Ninguno específico | Acciones fijadas por versión exacta, permisos mínimos del token, publicación solo si pasan las validaciones, etiquetas por commit | Fiore / Fede |
| A9 | Ransomware | Servidor local, volúmenes, backups | Cifrado o pérdida de la base y de los respaldos | Baja | Alto | Medio | Servicio de backups periódicos | Copia fuera de línea o fuera del servidor, restauración probada con tiempos, volúmenes sin acceso innecesario | BD / Fede |
| A10 | Abuso de webhooks | n8n, Alertmanager | Disparo de flujos o acciones no autorizadas | Media | Medio | Medio | Ninguno | Autenticación en el webhook, validación de datos, aprobación humana antes de acciones críticas | Juan |
| A11 | Riesgos de IA | Flujo de informes de n8n | Envío de datos internos a un modelo externo; instrucciones maliciosas dentro de los datos analizados | Media | Medio | Medio | Datos sintéticos | Enviar solo métricas agregadas, tratar la salida del modelo como no confiable, sin acciones automáticas a partir de ella | Juan |
| A12 | Escalada desde contenedores | Docker, cAdvisor, exportadores | Acceso al host desde un contenedor comprometido | Baja | Alto | Medio | Redes de Docker separadas | Revisar permisos elevados, ejecutar sin root cuando se pueda, no montar el socket de Docker donde no haga falta | Juan / Fede |
| A13 | Exposición por el túnel a Internet | Túnel, frontend | Publicar más servicios de los necesarios; acceso no autorizado | Media | Alto | Alto | Ninguno aún | Exponer solo el frontend, HTTPS, control de acceso, documentar quién puede entrar | Seba |
| A14 | Fuga de datos en la documentación | Nextcloud, repositorio público | Credenciales o datos reales en archivos compartidos | Media | Medio | Medio | Datos sintéticos | Permisos por carpeta, usuarios autorizados, nada de secretos en texto plano | Fede |
| A15 | Pérdida de integridad en reservas | Base de datos | Reservas superpuestas para la misma habitación | Media | Medio | Medio | Restricción de exclusión sobre fechas (verificar que esté activa) | Comprobarla sobre los datos cargados; prueba de concurrencia | BD |

## 3. Controles priorizados

| Prioridad | Acción | Amenazas |
|---|---|---|
| 1 | Autenticación y autorización en la API | A2, A3 |
| 2 | Dejar de publicar base de datos y pgAdmin al host | A6, A13 |
| 3 | Usuarios de base separados (aplicación y monitoreo) con permisos mínimos | A1, A5 |
| 4 | Escaneo con Trivy y endurecimiento del pipeline | A7, A8 |
| 5 | Backups fuera del servidor con restauración probada | A9 |
| 6 | Seguridad de webhooks y flujos de n8n | A10, A11 |

## 4. Verificación con pruebas controladas (19/11/2026)

Se ejecutaron pruebas controladas en el entorno local propio, con datos sintéticos. El detalle con evidencias se conserva en el informe de pruebas controladas, de acceso restringido.

| ID | Resultado de la prueba | Estado |
|---|---|---|
| A1 | Las entradas maliciosas probadas fueron rechazadas por la validación | Control efectivo; prueba parcial |
| A2 | El riesgo se confirmó | Confirmada, pendiente de corrección |
| A3 | Se confirmaron la falta de restricción de origen y de limitación de pedidos | Confirmada, pendiente de corrección |
| A4 | No hay limitación de pedidos | Confirmada, pendiente de corrección |
| A6 | Servicios de datos y administración publicados fuera del equipo local | Confirmada, pendiente de corrección |
| A13 | Pendiente: depende de la publicación definida en el punto 9 | Sin probar |
| Resto | Sin pruebas todavía | Pendiente |

Los hallazgos confirmados se registran como incidencias y, una vez corregidos, se repiten las pruebas para dejar el resultado posterior.

## 5. Revisión

Esta matriz se actualiza después de cada escaneo y de las pruebas controladas. Cada cambio de riesgo se registra en el informe de vulnerabilidades y, si corresponde, como incidencia en la herramienta de gestión.
