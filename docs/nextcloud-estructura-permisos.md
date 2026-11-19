# Gestión documental con Nextcloud – Estructura y permisos

Práctica Integradora Final – Punto 12: Gestión documental con Nextcloud.
Responsable: Fede. Estado: borrador para revisión del equipo.

> Los ítems marcados con **(confirmar)** dependen de la decisión final del equipo.

## 1. Despliegue

- Nextcloud corre en Docker con su propia base PostgreSQL y su propia red (`red-nextcloud`), separado de la aplicación.
- Archivos: `nextcloud/docker-compose.yml` y `nextcloud/.env.example`. Las contraseñas van en un `.env` local que no se sube al repositorio.
- Imagen con versión fija (`nextcloud:33.0.5-apache`, rama estable).
- Acceso solo desde la propia máquina: `http://localhost:8085`. Para que el equipo entre desde otras computadoras hay que hacerlo por el túnel definido en el punto 9, con control de acceso y HTTPS **(confirmar)**.
- Datos persistentes en volúmenes de Docker (`nc-html` y `nc-db-data`).

Puesta en marcha:
```
cd nextcloud
cp .env.example .env     # completar contraseñas
docker compose up -d
```

## 2. Usuarios y grupos

| Grupo | Integrantes | Uso |
|---|---|---|
| `equipo` | Los cinco integrantes | Lectura general de toda la documentación |
| `resp-seba`, `resp-fiore`, `resp-juan`, `resp-fede`, `resp-bd` | Cada responsable | Edición de sus carpetas |
| `catedra` | Cuentas de la cátedra | Solo lectura, para la evaluación **(confirmar)** |

Una cuenta de administración separada de las cuentas personales. Cada integrante tiene su propia cuenta; no se comparten usuarios.

## 3. Estructura de carpetas

Se corresponde con la documentación técnica obligatoria del punto 15.

| Carpeta | Contenido | Responsable |
|---|---|---|
| `00_Gestion_Scrum` | Backlog, plan de sprints, evidencias de seguimiento, decisiones | Seba |
| `01_Diagnostico_Arquitectura` | Diagnóstico, inventario tecnológico, diagrama de arquitectura | Fede |
| `02_Git_CICD` | Estrategia de ramas, pull requests, pipeline y rollback | Fiore |
| `03_Base_de_Datos` | Esquema, carga de datos, optimización, replicación, backups y restauración | Responsable de Brian |
| `04_Contenedores_Docker` | Configuración Docker y manual de instalación | Fiore |
| `05_Publicacion_Internet` | Arquitectura de acceso, túnel, firewall, HTTPS | Seba |
| `06_Monitoreo` | Prometheus, Grafana, alertas y pruebas | Juan |
| `07_Incidencias` | Registro y evidencias de la herramienta de gestión | Seba |
| `08_Automatizacion_n8n` | Flujos, ejecuciones y análisis de riesgos | Juan |
| `09_Seguridad` | Matriz de amenazas, informe de vulnerabilidades, escaneos, respuesta a incidentes | Fede |
| `10_Pruebas_y_Evidencias` | Informes de pruebas y capturas de todo el equipo | Todo el equipo |
| `11_Entrega_Final` | Documento final y material de la defensa | Juan |

Convención de nombres: `AAAA-MM-DD_tema_vN.ext` (por ejemplo `2026-11-17_matriz-amenazas_v1.md`).

## 4. Matriz de permisos

| Carpeta | Responsable | Grupo `equipo` | Grupo `catedra` | Sin cuenta |
|---|---|---|---|---|
| `00_Gestion_Scrum` | Edita | Lectura | Lectura | Sin acceso |
| `01_Diagnostico_Arquitectura` | Edita | Lectura | Lectura | Sin acceso |
| `02_Git_CICD` | Edita | Lectura | Lectura | Sin acceso |
| `03_Base_de_Datos` | Edita | Lectura | Lectura | Sin acceso |
| `04_Contenedores_Docker` | Edita | Lectura | Lectura | Sin acceso |
| `05_Publicacion_Internet` | Edita | Lectura | Lectura | Sin acceso |
| `06_Monitoreo` | Edita | Lectura | Lectura | Sin acceso |
| `07_Incidencias` | Edita | Lectura | Lectura | Sin acceso |
| `08_Automatizacion_n8n` | Edita | Lectura | Lectura | Sin acceso |
| `09_Seguridad` | Edita | Lectura | Lectura | Sin acceso |
| `10_Pruebas_y_Evidencias` | Edita | Edita | Lectura | Sin acceso |
| `11_Entrega_Final` | Edita | Lectura | Lectura | Sin acceso |

Principio aplicado: cada carpeta la edita solo su responsable, el resto del equipo la lee, y nadie sin cuenta accede. El borrado queda restringido al responsable.

## 5. Controles de seguridad

- Contraseñas largas y únicas; autenticación en dos pasos para la cuenta de administración.
- Enlaces públicos desactivados, o con contraseña y vencimiento.
- **No se guardan secretos** (contraseñas, tokens, claves, archivos `.env`). Si hace falta compartir uno, va cifrado o en un gestor de contraseñas.
- No se almacenan datos personales reales; los datos de prueba son sintéticos.
- El informe de vulnerabilidades con evidencias de fallas sin corregir se guarda solo en `09_Seguridad`.
- Versiones: Nextcloud conserva el historial de cada archivo, lo que permite registrar las versiones relevantes de los entregables.
- Los respaldos de Nextcloud (volúmenes y base) se incluyen en el plan de backup **(confirmar)**.

## 6. Verificación

| Prueba | Resultado esperado |
|---|---|
| Un integrante intenta editar una carpeta ajena | Denegado |
| Un integrante edita su propia carpeta | Permitido |
| Un usuario de `catedra` intenta subir o borrar | Denegado |
| Una persona sin cuenta abre un enlace a una carpeta | Sin acceso |
| Se sube una nueva versión de un archivo | El historial muestra ambas versiones |

Cada prueba se documenta con captura y fecha en `10_Pruebas_y_Evidencias`.
