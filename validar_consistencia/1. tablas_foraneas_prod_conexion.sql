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
CREATE SCHEMA IF NOT EXISTS prod_base;



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


IMPORT FOREIGN SCHEMA "colsmart_prod_base_owner"
  LIMIT TO (
    "u_manzana",
    "u_nomenclatura_domiciliaria",
    "u_nomenclatura_vial",
    "u_perimetro",
    "u_sector",
    "u_zona_homogenea_fisica",
    "u_zona_homogenea_geoeconomica",
    "r_nomenclatura_domiciliaria",
    "r_nomenclatura_vial",
    "r_sector",
    "r_vereda",
    "r_zona_homogenea_fisica",
    "r_zona_homogenea_geoeconomica"
  )
  FROM SERVER colsmart_prod_migra_srv
  INTO prod_base;


