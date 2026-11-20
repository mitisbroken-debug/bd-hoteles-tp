# Plan de respuesta a incidentes – Sistema de Reservas de Hoteles

Práctica Integradora Final – Punto 14: Seguridad informática y amenazas actuales.
Responsable: Fede. Estado: borrador para revisión del equipo.

> Los ítems marcados con **(confirmar)** dependen de la configuración final del equipo.

## 1. Objetivo y alcance

Definir cómo detectar, clasificar, contener, resolver y documentar incidentes de seguridad o de disponibilidad que afecten a la aplicación, la base de datos, los contenedores, la infraestructura, el pipeline de CI/CD y los flujos automatizados. Se complementa con la matriz de amenazas.

## 2. Roles

| Rol | Responsabilidad | Persona |
|---|---|---|
| Coordinación del incidente | Clasifica, decide acciones y mantiene el registro | Fede **(confirmar)** |
| Infraestructura y acceso | Túnel, red, firewall, contenedores | Seba |
| Aplicación y CI/CD | API, frontend, pipeline, imágenes | Fiore |
| Monitoreo y automatización | Prometheus, Grafana, Alertmanager, n8n | Juan |
| Base de datos | Primario, réplica, backups y restauración | Responsable de BD **(confirmar)** |

Si una persona no está disponible, la coordinación del incidente pasa a quien esté disponible y lo deja asentado en el registro.

## 3. Clasificación de severidad

| Nivel | Criterio | Ejemplo | Primera respuesta |
|---|---|---|---|
| Crítico | Pérdida o exposición de datos, o servicio caído sin alternativa | Credenciales filtradas, base inaccesible, imagen comprometida en producción | Inmediata |
| Alto | Servicio degradado o vulnerabilidad explotable | Réplica caída, API saturada, dependencia con falla grave | Dentro del día |
| Medio | Anomalía sin impacto directo | Escaneo con hallazgos medios, intentos de acceso repetidos | Dentro de la semana de trabajo |
| Bajo | Observación o mejora | Configuración mejorable | Se planifica |

## 4. Fases de la respuesta

### 4.1 Detección
Fuentes de detección:
- Alertas de Prometheus y Alertmanager (servicio caído, uso excesivo de recursos, retraso o corte de replicación, reinicios de contenedores).
- Escaneos de Trivy sobre el repositorio y las imágenes.
- Resultados fallidos del pipeline de CI/CD.
- Revisión de registros de la API y de la base.
- Avisos de seguridad sobre dependencias, imágenes y acciones de terceros.
- Reportes del propio equipo.

Cuando una alerta llega a n8n, el flujo valida los datos, registra una incidencia en la herramienta de gestión (Mantis o GLPI) y notifica al responsable. Los datos recibidos se validan antes de procesarse y el webhook está autenticado **(confirmar)**.

### 4.2 Clasificación y registro
1. Asignar un identificador y una severidad.
2. Registrar en la herramienta de gestión: fecha y hora, quién detecta, qué se observa, componentes afectados y pasos para reproducir.
3. Asignar un responsable.

### 4.3 Contención
Acciones según el caso, de menor a mayor impacto:
- Aislar el componente afectado (detener el contenedor o quitarlo de la red).
- Cerrar el acceso externo (pausar el túnel).
- Revocar o rotar credenciales expuestas.
- Pasar la API a solo lectura.
- Detener el pipeline o bloquear nuevas publicaciones.

**Las acciones que interrumpen el servicio requieren aprobación humana**, también cuando las dispara un flujo automatizado. n8n puede proponerlas, no ejecutarlas por sí solo.

### 4.4 Erradicación
- Eliminar la causa raíz: corregir la vulnerabilidad, actualizar la dependencia o la imagen, retirar el acceso indebido.
- Reconstruir las imágenes desde fuentes verificadas.
- Volver a escanear para comprobar que el hallazgo desapareció.

### 4.5 Recuperación
- Restaurar desde un backup verificado si hubo pérdida o alteración de datos (ver sección 6).
- Volver a levantar los servicios en orden: base de datos, réplica, API, frontend, túnel.
- Comprobar el funcionamiento con el endpoint de salud, una consulta de lectura y una reserva de prueba.
- Verificar que la replicación esté al día y que las alertas vuelvan a estado normal.
- Monitorear de cerca durante las horas siguientes.

### 4.6 Cierre y lecciones aprendidas
- Cerrar la incidencia con la solución aplicada y la evidencia de verificación.
- Documentar: causa, línea de tiempo, qué funcionó, qué falló y qué cambiar.
- Actualizar la matriz de amenazas y abrir tareas para las mejoras.

## 5. Escenarios previstos

| Escenario | Señales | Contención | Recuperación |
|---|---|---|---|
| Credenciales expuestas (repositorio, pipeline o archivos compartidos) | Aviso del escáner de secretos, uso no reconocido | Revocar y rotar de inmediato la credencial; revisar accesos recientes | Reemplazar en el entorno y en los secretos del pipeline; limpiar el historial si hace falta |
| Dependencia, imagen o acción de terceros comprometida | Aviso de seguridad, cambio inesperado en una imagen, hallazgo crítico | Detener el pipeline; no publicar ni ejecutar la versión afectada | Volver a una versión conocida y segura; rotar secretos que pudo ver el pipeline; reconstruir las imágenes |
| Ataque de saturación (DDoS) o abuso de la API | Aumento de pedidos, latencia, alerta de disponibilidad | Limitar pedidos, pausar el túnel si es necesario | Reabrir de forma gradual con límites activos |
| Pérdida o alteración de datos (incluye ransomware) | Base inaccesible, datos cambiados, archivos cifrados | Aislar el servidor y los volúmenes; no conectar los backups hasta confirmar que están limpios | Restaurar desde el último backup verificado y comprobar la integridad |
| Caída del nodo primario | Alerta de base caída, errores de escritura | Confirmar la falla antes de actuar | Recuperación manual: promover la réplica con aprobación humana y reconfigurar la API; documentar la pérdida posible de datos recientes |
| Caída de la réplica | Alerta de replicación, lecturas en el primario | Ninguna urgente; la API lee del primario | Reconstruir la réplica a partir del primario |
| Webhook o flujo de n8n abusado | Ejecuciones no esperadas, datos inválidos | Desactivar el flujo; rotar el secreto del webhook | Revisar ejecuciones, corregir la validación y reactivar |

La replicación por sí sola no garantiza alta disponibilidad automática. La promoción de la réplica es un procedimiento manual y controlado, salvo que el equipo demuestre un mecanismo automático.

## 6. Backup y restauración

- Los respaldos los genera el servicio de backups en formato de volcado de PostgreSQL, con intervalo y retención definidos por variables de entorno.
- Debe existir al menos una copia fuera del servidor donde corren los contenedores **(confirmar)**.
- Cada backup se verifica con una restauración de prueba en un entorno aparte, registrando el tiempo que tarda y el resultado.
- Antes de restaurar en producción, se resguarda el estado actual para el análisis posterior.
- Tras restaurar, se comprueban la cantidad de registros por tabla y las restricciones de integridad.

Los comandos exactos de restauración y las evidencias se documentan en el manual de backup y restauración.

## 7. Comunicación

- Todo incidente se registra en la herramienta de gestión de incidencias.
- El equipo se entera por el canal de notificación definido (correo o mensajería) **(confirmar)**.
- Los incidentes de severidad crítica se informan a la cátedra si afectan la demostración.
- No se publican detalles técnicos de vulnerabilidades sin corregir en el repositorio público.

## 8. Pruebas del plan

Antes de la demostración final se simulan, en entorno controlado:
1. Una alerta de infraestructura que llegue hasta n8n y genere la incidencia en la herramienta de gestión.
2. La caída de la réplica y su recuperación.
3. Una restauración de backup con medición de tiempo.

Cada prueba deja evidencia (capturas del flujo, registro de ejecución y la incidencia cerrada).
