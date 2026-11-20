# 9. Configuración CI/CD

Responsable: Fio. Origen: `.github/workflows/docker-ci-cd.yml` y `docs/rol2_base_de_datos.md`
(sección "Punto 8"), los dos en la rama `develop`.

## Flujo de trabajo con Git (punto 3)

| Rama | Para qué |
|---|---|
| `main` | Versión estable |
| `develop` | Integración |
| `feature/*` | Trabajo de cada integrante. Se integra a `develop` por Pull Request |

Origen: `README.md` de la raíz.

Estado al 17/11/2026 (historial de Git y página de Pull Requests de GitHub):

- 4 Pull Requests: #1 (base de datos), #2 (backend) y #4 (diagnóstico) integrados; #3 (monitoreo) abierto.
- `main` está 11 commits atrás de `develop`.
- [PENDIENTE – Seba – hay commits que entraron directo a `develop` sin Pull Request. La consigna
  pide revisar el código antes de integrar y proteger la rama principal. Falta configurar la
  protección de `main` y `develop` en GitHub (exigir Pull Request con una revisión) y documentarla.]

## El pipeline

Herramienta: GitHub Actions. Un solo trabajo, `build-and-test`, en `ubuntu-latest`.

**Cuándo se ejecuta**

| Evento | Ramas |
|---|---|
| `push` | `feature/front-docker-cicd`, `develop`, `main` |
| `pull_request` | hacia `develop` o `main` |

**Pasos**

| # | Paso | Qué hace |
|---|---|---|
| 1 | Checkout | Descarga el código (`actions/checkout@v4`) |
| 2 | Buildx | Prepara el constructor de imágenes (`docker/setup-buildx-action@v3`) |
| 3 | Login | Entra a Docker Hub con los secretos `DOCKER_USERNAME` y `DOCKER_PASSWORD` |
| 4 | Backend | `docker build -t fiore2028/hotel-backend:latest ./backend` |
| 5 | Frontend | `docker build -t fiore2028/hotel-frontend:latest ./frontend` |
| 6 | Push | Sube las dos imágenes a Docker Hub. **No se ejecuta en Pull Requests**, solo en `push` |

**Cómo frena un cambio defectuoso.** Si alguno de los dos `docker build` falla, el trabajo
termina con error y el paso de subida no corre. En un Pull Request las imágenes se construyen
pero no se publican.

**Secretos.** El usuario y la clave de Docker Hub están en *GitHub Secrets*. No aparecen en el
archivo ni en el historial.

## Evidencia

Pestaña *Actions* del repositorio, al 17/11/2026: 9 ejecuciones. La primera falló (commit
`963bd5f`, error de sintaxis del archivo, corregido en `faacbbc`) y las 8 siguientes terminaron
bien. La última corresponde al commit `4bd2a2c` en `develop`.

## Rollback

El procedimiento que está en `docs/rol2_base_de_datos.md`: identificar la versión estable
anterior, cambiar la etiqueta de la imagen en el compose y ejecutar
`docker compose up -d --pull always`.

## Lo que falta para cumplir todo el punto 8

- [PENDIENTE – Fio – **verificaciones automáticas del código.** Hoy lo único que se valida es que
  la imagen se pueda construir. Faltaría un paso anterior, por ejemplo `npm ci`,
  `node --check src/server.js` y `npm audit --audit-level=high` en el backend.]
- [PENDIENTE – Fio – **etiquetas de versión.** Solo se publica `:latest`. El material de la cátedra
  (Despliegue continuo) etiqueta cada imagen con el hash del commit además de `latest`. Sin eso
  el rollback documentado no se puede ejecutar: no existe una etiqueta anterior a la cual volver.]
- [PENDIENTE – Fio – **despliegue automático.** El material usa Watchtower para actualizar los
  contenedores cuando hay una imagen nueva. Hoy el compose construye las imágenes localmente
  (`build:`) y no usa las de Docker Hub, así que un cambio no llega solo al entorno.]
- [PENDIENTE – Fio – **commit de prueba** con evidencia de que el cambio llegó al entorno publicado.]
- [PENDIENTE – Fio – en `docs/rol2_base_de_datos.md` el paso de rollback está repetido (2 y 3 dicen lo mismo).]
- El pipeline también publica imágenes cuando se hace `push` a la rama `feature/front-docker-cicd`.
