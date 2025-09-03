/* ============================================================
   1. Extensión FDW (ejecutar solo una vez en la BD destino)
   ============================================================ */
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

/* ============================================================
   2. Definir el servidor remoto
   ============================================================ */
DROP SERVER IF EXISTS colsmart_preprod_migra_srv CASCADE;

CREATE SERVER colsmart_preprod_migra_srv
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host '172.19.1.61',
    port '5432',
    dbname 'egdb_colsmart_prod'
  );

/* ============================================================
   3. Mapear credenciales
   ============================================================ */
CREATE USER MAPPING FOR CURRENT_USER
  SERVER colsmart_preprod_migra_srv
  OPTIONS (
    user 'colsmart_preprod_migra',
    password 'lti0KImvfWS9'
  );

/* ============================================================
   4. Crear esquema local destino
   ============================================================ */
CREATE SCHEMA IF NOT EXISTS preprod;

/* ============================================================
   5. Importar todas las tablas necesarias como FOREIGN TABLES
   ============================================================ */
IMPORT FOREIGN SCHEMA "colsmart_preprod_migra"
  LIMIT TO (
    "asignaciones",
    "cr_datosphcondominio",
    "cr_fuenteespacial",
    "cr_terreno",
    "cr_unidadconstruccion",
    "extdireccion",
    "ilc_caracteristicasunidadconstruccion",
    "ilc_datosadicionaleslevantamientocatastral",
    "ilc_derecho",
    "ilc_estructuraavaluo",
    "ilc_fuenteadministrativa",
    "ilc_interesado",
    "ilc_marcas",
    "ilc_predio",
    "ilc_predio_informalidad",
    "ilc_tramitesderechosterritoriales"
  )
  FROM SERVER colsmart_preprod_migra_srv
  INTO preprod;

/* ============================================================
   6. Crear TABLAS LOCALES (snapshot) en preprod.t_...
   ============================================================ */
CREATE TABLE preprod.t_asignaciones AS SELECT * FROM preprod.asignaciones;
CREATE TABLE preprod.t_cr_datosphcondominio AS SELECT * FROM preprod.cr_datosphcondominio;
CREATE TABLE preprod.t_cr_fuenteespacial AS SELECT * FROM preprod.cr_fuenteespacial;
CREATE TABLE preprod.t_cr_terreno AS SELECT * FROM preprod.cr_terreno;
CREATE TABLE preprod.t_cr_unidadconstruccion AS SELECT * FROM preprod.cr_unidadconstruccion;
CREATE TABLE preprod.t_extdireccion AS SELECT * FROM preprod.extdireccion;
CREATE TABLE preprod.t_ilc_caracteristicasunidadconstruccion AS SELECT * FROM preprod.ilc_caracteristicasunidadconstruccion;
CREATE TABLE preprod.t_ilc_datosadicionaleslevantamientocatastral AS SELECT * FROM preprod.ilc_datosadicionaleslevantamientocatastral;
CREATE TABLE preprod.t_ilc_derecho AS SELECT * FROM preprod.ilc_derecho;
CREATE TABLE preprod.t_ilc_estructuraavaluo AS SELECT * FROM preprod.ilc_estructuraavaluo;
CREATE TABLE preprod.t_ilc_fuenteadministrativa AS SELECT * FROM preprod.ilc_fuenteadministrativa;
CREATE TABLE preprod.t_ilc_interesado AS SELECT * FROM preprod.ilc_interesado;
CREATE TABLE preprod.t_ilc_marcas AS SELECT * FROM preprod.ilc_marcas;
CREATE TABLE preprod.t_ilc_predio AS SELECT * FROM preprod.ilc_predio;
CREATE TABLE preprod.t_ilc_predio_informalidad AS SELECT * FROM preprod.ilc_predio_informalidad;
CREATE TABLE preprod.t_ilc_tramitesderechosterritoriales AS SELECT * FROM preprod.ilc_tramitesderechosterritoriales;
