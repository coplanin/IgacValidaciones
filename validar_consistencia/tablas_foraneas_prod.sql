/* ============================================================
   1. Extensión FDW (ejecutar solo una vez en la BD destino)
   ============================================================ */
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

/* ============================================================
   2. Definir el servidor remoto
   ============================================================ */
DROP SERVER IF EXISTS colsmart_prod_migra_srv CASCADE;

CREATE SERVER colsmart_prod_migra_srv
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
  SERVER colsmart_prod_migra_srv
  OPTIONS (
    user 'colsmart_prod_reader',
    password 'byNVM7ICyz'
  );

/* ============================================================
   4. Crear esquema local destino
   ============================================================ */
CREATE SCHEMA IF NOT EXISTS prod;

/* ============================================================
   5. Importar tablas remotas como foreign tables
   ============================================================ */
IMPORT FOREIGN SCHEMA "colsmart_prod_owner"
  LIMIT TO (
    "asignaciones_",
    "cr_datosphcondominio_",
    "cr_fuenteespacial_",
    "cr_terreno_",
    "cr_unidadconstruccion_",
    "extdireccion_",
    "ilc_caracteristicasunidadconstruccion_",
    "ilc_datosadicionaleslevantamientocatastral_",
    "ilc_derecho_",
    "ilc_estructuraavaluo_",
    "ilc_fuenteadministrativa_",
    "ilc_interesado_",
    "ilc_marcas_",
    "ilc_predio_",
    "ilc_predio_informalidad_",
    "ilc_tramitesderechosterritoriales_"
  )
  FROM SERVER colsmart_prod_migra_srv
  INTO prod;

/* ============================================================
   6. Crear TABLAS LOCALES (snapshot) sin el sufijo "_"
   ============================================================ */
CREATE TABLE prod.t_asignaciones AS SELECT * FROM prod.asignaciones_;
CREATE TABLE prod.t_cr_datosphcondominio AS SELECT * FROM prod.cr_datosphcondominio_;
CREATE TABLE prod.t_cr_fuenteespacial AS SELECT * FROM prod.cr_fuenteespacial_;
CREATE TABLE prod.t_cr_terreno AS SELECT * FROM prod.cr_terreno_;
CREATE TABLE prod.t_cr_unidadconstruccion AS SELECT * FROM prod.cr_unidadconstruccion_;
CREATE TABLE prod.t_extdireccion AS SELECT * FROM prod.extdireccion_;
CREATE TABLE prod.t_ilc_caracteristicasunidadconstruccion AS SELECT * FROM prod.ilc_caracteristicasunidadconstruccion_;
CREATE TABLE prod.t_ilc_datosadicionaleslevantamientocatastral AS SELECT * FROM prod.ilc_datosadicionaleslevantamientocatastral_;
CREATE TABLE prod.t_ilc_derecho AS SELECT * FROM prod.ilc_derecho_;
CREATE TABLE prod.t_ilc_estructuraavaluo AS SELECT * FROM prod.ilc_estructuraavaluo_;
CREATE TABLE prod.t_ilc_fuenteadministrativa AS SELECT * FROM prod.ilc_fuenteadministrativa_;
CREATE TABLE prod.t_ilc_interesado AS SELECT * FROM prod.ilc_interesado_;
CREATE TABLE prod.t_ilc_marcas AS SELECT * FROM prod.ilc_marcas_;
CREATE TABLE prod.t_ilc_predio AS SELECT * FROM prod.ilc_predio_;
CREATE TABLE prod.t_ilc_predio_informalidad AS SELECT * FROM prod.ilc_predio_informalidad_;
CREATE TABLE prod.t_ilc_tramitesderechosterritoriales AS SELECT * FROM prod.ilc_tramitesderechosterritoriales_;
