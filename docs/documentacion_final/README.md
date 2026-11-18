# Documentación final – Sistema de Reservas de Hoteles

Trabajo Final Integrador de Herramientas Informáticas Avanzadas (APU – UNJu), 2026.

Esta carpeta junta la **documentación técnica obligatoria** del punto 15 de la consigna: 16
secciones, una por archivo. Cada dato dice de qué archivo del repositorio sale, para que se
pueda comprobar.

## Cómo leerla

- Estado al **17/11/2026**. Lo que se cita como "rama `develop`" es lo que había en GitHub ese día.
- Donde falta el aporte de un integrante hay un cartel con este formato:
  `[PENDIENTE – responsable – qué falta]`. No se completó con contenido inventado.
- Los comandos están pensados para PowerShell en Windows con Docker Desktop.

## Índice

| # | Sección | Archivo | Estado |
|---|---|---|---|
| 1 | Descripción de la aplicación | [01_descripcion.md](01_descripcion.md) | Completa (el diagnóstico del punto 1 está en `docs/diagnostico.md`, con ítems por confirmar) |
| 2 | Arquitectura general | [02_arquitectura.md](02_arquitectura.md) | Completa para lo que existe |
| 3 | Inventario tecnológico | [03_inventario_tecnologico.md](03_inventario_tecnologico.md) | Completa para lo que existe |
| 4 | Manual de instalación | [04_manual_instalacion.md](04_manual_instalacion.md) | Completa para lo que existe |
| 5 | Configuración Docker | [05_configuracion_docker.md](05_configuracion_docker.md) | Completa para lo que existe |
| 6 | Migración y carga de datos | [06_migracion_y_carga.md](06_migracion_y_carga.md) | Parcial |
| 7 | Informe de optimización SQL | [07_optimizacion_sql.md](07_optimizacion_sql.md) | Parcial (falta el informe redactado) |
| 8 | Configuración y pruebas de replicación | [08_replicacion.md](08_replicacion.md) | Completa |
| 9 | Configuración CI/CD | [09_ci_cd.md](09_ci_cd.md) | Parcial |
| 10 | Publicación en Internet | [10_publicacion_internet.md](10_publicacion_internet.md) | **Pendiente** |
| 11 | Manual de monitoreo | [11_monitoreo.md](11_monitoreo.md) | Completa |
| 12 | Gestión de incidencias | [12_gestion_incidencias.md](12_gestion_incidencias.md) | **Pendiente** (lista la integración con n8n) |
| 13 | Flujos de n8n | [13_flujos_n8n.md](13_flujos_n8n.md) | Completa |
| 14 | Informe de seguridad | [14_informe_seguridad.md](14_informe_seguridad.md) | **Pendiente** (están los controles que ya existen) |
| 15 | Backup y restauración | [15_backup_y_restauracion.md](15_backup_y_restauracion.md) | Completa, con un problema abierto |
| 16 | Limitaciones conocidas y mejoras futuras | [16_limitaciones_y_mejoras.md](16_limitaciones_y_mejoras.md) | Completa para lo que existe |

## Quién hizo qué

| Integrante | Puntos de la consigna |
|---|---|
| Brian Vega | 4 (base en Docker), 5 (optimización), 6 (réplica) y la API |
| Fio | 7 (aplicación en Docker), 8 (CI/CD) |
| Seba | 2 (Scrum), 3 (control de versiones), 9 (publicación en Internet), 11 (incidencias) |
| Fede | 1 (diagnóstico), 12 (Nextcloud), 14 (seguridad) |
| Juan Sebastián Baca Wayar | 10 (monitoreo), 13 (n8n), 15 (documentación) |

## Puntos de la consigna que no tienen sección propia en el punto 15

| Punto | Dónde queda documentado |
|---|---|
| 1. Selección y diagnóstico | [`docs/diagnostico.md`](../diagnostico.md) (Fede, PR #5) y el resumen en la sección 1 |
| 2. Gestión con Scrum | [PENDIENTE – Seba – enlace al tablero de Jira, backlog, plan de sprints y evidencias de seguimiento] |
| 3. Control de versiones | Sección 9 (flujo de ramas y Pull Requests) |
| 12. Gestión documental con Nextcloud | [PENDIENTE – Fede – estructura de carpetas, matriz de permisos y evidencias]. La subida automática de informes desde n8n ya está lista (sección 13) |
