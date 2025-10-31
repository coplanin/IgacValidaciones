/* 1. Extensión FDW (solo una vez) */
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

/* 2. Definir el servidor remoto */
CREATE SERVER edgeograficos_srv
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host '172.19.1.61',
    port '5432',          -- cambia si tu remoto usa otro
    dbname 'edgeograficos'
  );

/* 3. Mapear credenciales                                 */
/*    Usa el rol local que lanzará las consultas          */
/*    (puede ser CURRENT_USER si lo ejecutas con ese rol) */
CREATE USER MAPPING FOR CURRENT_USER
  SERVER edgeograficos_srv
  OPTIONS (
    user 'colsmart_snc_linea_base',
    password '0vVUW184UXeg'      -- considera .pgpass o un rol dedicado
  );

/* 4. (Opcional) Crea un esquema local para las tablas remotas */
CREATE SCHEMA IF NOT EXISTS edge;

/* 5. Importar SOLO la tabla que necesitas                  */
/*    Nota: la tabla está en el esquema remoto              */
/*          colsmart_snc_linea_base.                           */
IMPORT FOREIGN SCHEMA "colsmart_snc_linea_base"
  LIMIT TO ("vw_ilc_predio")            -- respeta las mayúsculas si existen
  FROM SERVER edgeograficos_srv
  INTO edge;                         -- esquema LOCAL donde quedará expuesta
  
  
select *
from edge.vw_ilc_predio;

| Tema                      | Detalle                                                                                                                                                                                                    |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Datos actualizados**    | `ilc_predio` se lee directamente del nodo remoto; no hay que volver a importar para ver inserts/updates.                                                                                                   |
| **Cambios de estructura** | Si en el servidor remoto cambian columnas, corre:<br>`ALTER FOREIGN TABLE edge.ilc_predio …`<br>o borra la tabla y repite el paso 5.                                                                       |
| **Seguridad**             | Guarda la contraseña en `~/.pgpass` o crea un rol proxy con permisos mínimos; evita dejar claves en texto si tu repo es compartido.                                                                        |
| **Rendimiento**           | Se empujan (push-down) muchos filtros PostGIS (`&&`, `ST_Intersects`, etc.) siempre que ambas bases tengan la misma versión de PostGIS y SRID. Indexa la tabla remota para sacarle provecho.               |
| **Escritura**             | Si tu rol remoto tiene privilegios, la tabla es *updatable* (`INSERT/UPDATE/DELETE`). Para bloquearla, define la *foreign table* con `OPTIONS (updatable 'false')` o restringe permisos en la base origen. |

