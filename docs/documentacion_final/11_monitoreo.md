# 11. Manual de monitoreo

Responsable: Juan. El manual completo está en [`monitoreo/README.md`](../../monitoreo/README.md).
Acá va el resumen y lo que hace falta para operarlo.

## Qué se monitorea y con qué

| Qué | Exportador | Qué mide |
|---|---|---|
| Sistema (la máquina de Docker) | node-exporter | CPU, memoria, disco, red |
| Contenedores | cAdvisor | Uso de recursos por contenedor, si está corriendo, cuándo arrancó |
| PostgreSQL principal | postgres-exporter | Conexiones, actividad, tamaño, replicación vista desde el principal |
| PostgreSQL réplica | postgres-exporter | Lo mismo, más el atraso de la réplica |
| Disponibilidad de la aplicación | blackbox-exporter | Hace `GET http://api-hoteles:3000/health` cada 15 s |

Prometheus junta todo cada 15 s (9 targets), Grafana lo muestra y Alertmanager envía las alertas.

Origen: `monitoreo/docker-compose.yml`, `monitoreo/prometheus/prometheus.yml`.

## Cómo entrar

| Herramienta | Dirección | Usuario |
|---|---|---|
| Grafana | http://localhost:3000 (o el puerto de `GRAFANA_PORT`) | `admin` y la clave de `monitoreo/.env` |
| Prometheus | http://localhost:9090 | Sin login. Solo se ve desde la propia PC |
| Alertmanager | http://localhost:9093 | Sin login. Solo se ve desde la propia PC |

Los tres puertos están publicados en `127.0.0.1`: no se ven desde otra máquina de la red.

## Tablero

El tablero propio es **"Hoteles - Visión general"**
(`monitoreo/grafana/dashboards/propios/hoteles-vision-general.json`). Se carga solo al levantar
Grafana, igual que la fuente de datos. Cubre lo que pide la consigna: CPU y memoria, disco, red,
estado y reinicios de contenedores, disponibilidad de la aplicación, métricas de la base,
conexiones activas y estado de la replicación. También hay tres tableros de la comunidad
(node-exporter, cAdvisor y PostgreSQL) para ver más detalle.

**Lo que no se monitorea:** consultas SQL individuales. Las métricas de la base son generales
(conexiones, transacciones, tamaño, atraso), como aclara la consigna.

## Alertas

13 reglas en `monitoreo/prometheus/alertas.yml`. Cada una tiene comentado por qué ese umbral y
por qué ese tiempo de espera.

| Grupo | Alerta | Condición | Severidad |
|---|---|---|---|
| Disponibilidad | `ApiCaida` | `/health` falla 1 min | critical |
| | `BasePrincipalCaida` | El exportador no conecta con el principal 1 min | critical |
| | `ReplicaCaida` | El exportador no conecta con la réplica 1 min | critical |
| | `ReplicaDesconectada` | Ninguna réplica en streaming 2 min | critical |
| | `ReplicacionRetrasoAlto` | Más de 30 s de atraso durante 2 min | warning |
| | `ReplicacionRetrasoBytesAlto` | Más de 64 MB de WAL sin aplicar durante 2 min | warning |
| | `ConexionesAltas` | Más del 80 % de `max_connections` durante 5 min | warning |
| Sistema | `CpuAlta` | Más del 85 % durante 5 min | warning |
| | `MemoriaAlta` | Más del 90 % durante 5 min | warning |
| | `DiscoCasiLleno` | Más del 85 % durante 10 min | warning |
| Contenedores | `ContenedorSinReportar` | Un contenedor del proyecto desaparece 1 min | critical |
| | `ContenedorReiniciandose` | Más de 2 arranques en 15 min | warning |
| | `TargetCaido` | Un exportador no responde 2 min | warning |

Alertmanager (`monitoreo/alertmanager/alertmanager.yml`) agrupa por alerta e instancia, espera
30 s antes del primer aviso, repite cada 4 h si sigue activa, avisa también cuando se resuelve y
no manda avisos redundantes (si la réplica está caída, no avisa además que está desconectada).

Las alertas van al webhook de n8n con un token. Qué hace n8n con ellas: sección 13.

## Prueba de una condición anormal

```powershell
docker stop api-hoteles
```
1. A los ~10 s, `probe_success` pasa a 0 (la sonda de blackbox ya no recibe respuesta).
2. A los ~30 s, `ApiCaida` y `ContenedorSinReportar` quedan en *pending*: la condición se cumple
   y corre el tiempo de espera (`for: 1m`). Se ve en `http://localhost:9090/alerts`.
3. A los ~90 s pasan a *firing* y aparecen en Alertmanager con el receptor `n8n`.
4. Alertmanager espera 30 s para agrupar y avisa a n8n, que registra una incidencia por cada
   alerta y manda los mails.

```powershell
docker start api-hoteles
```
La alerta se resuelve y llega el aviso de resolución.

La prueba de la API caída está documentada con sus tiempos en `monitoreo/README.md`,
sección "Prueba de alerta". El 17/11/2026 se probó además el camino completo Alertmanager → n8n
con una alerta de prueba (`n8n/README.md`, "Evidencias").

## Operación

| Tarea | Comando |
|---|---|
| Ver que todo está arriba | `docker compose ps` en `monitoreo/` |
| Recargar reglas sin reiniciar | `docker kill -s HUP monitoreo-prometheus` |
| Ver por qué falla un aviso | `docker logs monitoreo-alertmanager` |
| Comprobar todo el TP | `.\scripts\verificar.ps1` desde la raíz |

## Estado al 17/11/2026

9 de 9 targets en UP, 13 reglas cargadas, ninguna alerta activa. Grafana 13.2.6 respondiendo.
El Pull Request #3 (monitoreo) sigue abierto.

## Limitaciones

Están detalladas en `monitoreo/README.md`, "Limitaciones conocidas". Las principales: las
métricas del sistema son las de la máquina virtual de Docker Desktop, no las de Windows; no se
monitorea la URL pública (todavía no existe); y nadie vigila a n8n desde Prometheus.
