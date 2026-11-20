# 10. Procedimiento de publicación en Internet

Responsable: Seba.

**[PENDIENTE – Seba – toda la sección. Al 17/11/2026 no hay nada de este punto en el repositorio:
la rama `feature/publicacion-internet` fue borrada y no hay archivos con Traefik ni cloudflared.]**

La consigna exige que la aplicación esté accesible desde Internet durante la demostración final.

## Qué tiene que tener esta sección (según la consigna, punto 9)

| Entregable | Estado |
|---|---|
| URL o mecanismo de acceso documentado | [PENDIENTE – Seba] |
| Diagrama de red | [PENDIENTE – Seba] |
| Configuración de publicación | [PENDIENTE – Seba] |
| Evidencia de acceso externo (desde un dispositivo fuera de la red local) | [PENDIENTE – Seba] |
| Configuración del firewall y HTTPS | [PENDIENTE – Seba] |
| Análisis de riesgos y limitaciones de la alternativa elegida | [PENDIENTE – Seba] |
| Medición de disponibilidad y registro de errores | El monitoreo ya mide la disponibilidad de la API (sección 11). Falta sumar la URL pública |

## Lo que ya condiciona a esta sección

Datos del resto del proyecto que hay que tener en cuenta al hacerla:

- **El frontend llama a `http://localhost:3001`** (`frontend/index.html`, línea 263, rama
  `develop`). Desde un dispositivo externo, `localhost` es ese dispositivo, así que la página
  cargaría pero no traería datos. [PENDIENTE – Fio – que la dirección de la API no quede fija.]
- **Qué no se debe publicar**, según la consigna: la base de datos (5440, 5442) y las interfaces
  administrativas (pgAdmin 5050, Grafana, Prometheus, Alertmanager, n8n). Las de monitoreo y n8n
  ya están publicadas solo en `127.0.0.1`.
- **La red de la base** se llama `bd-hoteles-tp_red-hoteles`: el proxy tiene que unirse a esa
  red como externa para llegar al frontend.
- **El puerto 80 de la PC** suele estar ocupado por contenedores de otros trabajos.
