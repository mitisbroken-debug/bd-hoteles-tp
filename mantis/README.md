# Mantis Bug Tracker (punto 11)

Gestión de incidencias del proyecto, desplegada con Docker.

## Requisitos
- Docker Desktop
- Archivo `.env` en la raíz con las variables `MANTIS_DB_*` (ver `.env.example`).
  Las claves reales se piden al equipo; no se suben al repo.

## Levantar Mantis
```powershell
docker compose -f docker-compose.mantis.yml up -d
```
Se accede en http://localhost:9081

Se usa el puerto 9081 porque en Windows el rango cercano a 8081 puede quedar
reservado por el sistema y Docker no logra publicarlo.

## Restaurar la configuración inicial (proyecto y categorías)
Sobre una base recién creada (si ya existe un volumen anterior, bajarlo antes con
`docker compose -f docker-compose.mantis.yml down -v`). Usar la clave de
`MANTIS_DB_ROOT_PASSWORD` de tu `.env`:
```powershell
docker cp mantis\mantis_inicial.sql mantis-db:/tmp/mantis_inicial.sql
docker exec mantis-db sh -c "mariadb -u root -p<MANTIS_DB_ROOT_PASSWORD> bugtracker < /tmp/mantis_inicial.sql"
```

Luego hay que generar el archivo de configuración de Mantis: abrir
http://localhost:9081/admin/install.php y completar la instalación con los datos
de la base (host `mantis-db`, usuario y claves del `.env`). Si ya existen las tablas,
Mantis las detecta; no debería borrar el proyecto ni las categorías restauradas.
Si la pantalla muestra un error o duda, avisar al equipo antes de continuar.

## Configuración incluida
- Proyecto: BD Hoteles TP (privado)
- Categorías: Base de datos, Backend/API, Rendimiento, Seguridad, Concurrencia, Índices, Infraestructura, Documentación
- Usuario: `administrator` (la clave se pasa por fuera del repo)