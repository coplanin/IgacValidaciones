/* 1. Extensión FDW (solo una vez) */
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

/* 2. Definir el servidor remoto */
CREATE SERVER colsmart_preprod_migra_srv
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host '172.19.1.61',
    port '5432',          -- cambia si tu remoto usa otro
    dbname 'egdb_colsmart_prod'
  );

/* 3. Mapear credenciales                                 */
/*    Usa el rol local que lanzará las consultas          */
/*    (puede ser CURRENT_USER si lo ejecutas con ese rol) */
CREATE USER MAPPING FOR CURRENT_USER
  SERVER colsmart_preprod_migra_srv
  OPTIONS (
    user 'colsmart_preprod_migra',
    password 'lti0KImvfWS9'      -- considera .pgpass o un rol dedicado
  );

/* 4. (Opcional) Crea un esquema local para las tablas remotas */
CREATE SCHEMA IF NOT EXISTS preprod;

/* 5. Importar SOLO la tabla que necesitas                  */
/*    Nota: la tabla está en el esquema remoto              */
/*          colsmart_test5_owner.                           */
IMPORT FOREIGN SCHEMA "colsmart_preprod_migra"
  LIMIT TO ("ilc_predio")            -- respeta las mayúsculas si existen
  FROM SERVER colsmart_preprod_migra_srv
  INTO preprod;                         -- esquema LOCAL donde quedará expuesta
  
  
select *
from preprod.ilc_predio;


