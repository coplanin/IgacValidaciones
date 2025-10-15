/* ============================================================
   Eliminar TABLAS LOCALES (snapshot) en prod_base
   ============================================================ */

BEGIN;

DROP TABLE IF EXISTS prod_base.t_u_manzana                          CASCADE;
DROP TABLE IF EXISTS prod_base.t_u_nomenclatura_domiciliaria        CASCADE;
DROP TABLE IF EXISTS prod_base.t_u_nomenclatura_vial                CASCADE;
DROP TABLE IF EXISTS prod_base.t_u_perimetro                        CASCADE;
DROP TABLE IF EXISTS prod_base.t_u_sector                           CASCADE;
DROP TABLE IF EXISTS prod_base.t_u_zona_homogenea_fisica            CASCADE;
DROP TABLE IF EXISTS prod_base.t_u_zona_homogenea_geoeconomica      CASCADE;

DROP TABLE IF EXISTS prod_base.t_r_nomenclatura_domiciliaria        CASCADE;
DROP TABLE IF EXISTS prod_base.t_r_nomenclatura_vial                CASCADE;
DROP TABLE IF EXISTS prod_base.t_r_sector                           CASCADE;
DROP TABLE IF EXISTS prod_base.t_r_vereda                           CASCADE;
DROP TABLE IF EXISTS prod_base.t_r_zona_homogenea_fisica            CASCADE;
DROP TABLE IF EXISTS prod_base.t_r_zona_homogenea_geoeconomica      CASCADE;

COMMIT;


/* ============================================================
   Crear TABLAS LOCALES (snapshot) desde foreign tables
   (sin WHERE ni ORDER BY)
   ============================================================ */

CREATE TABLE prod_base.t_u_manzana AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_manzana;

CREATE TABLE prod_base.t_u_nomenclatura_domiciliaria AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_nomenclatura_domiciliaria;

CREATE TABLE prod_base.t_u_nomenclatura_vial AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_nomenclatura_vial;

CREATE TABLE prod_base.t_u_perimetro AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_perimetro;

CREATE TABLE prod_base.t_u_sector AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_sector;

CREATE TABLE prod_base.t_u_zona_homogenea_fisica AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_zona_homogenea_fisica;

CREATE TABLE prod_base.t_u_zona_homogenea_geoeconomica AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.u_zona_homogenea_geoeconomica;

CREATE TABLE prod_base.t_r_nomenclatura_domiciliaria AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.r_nomenclatura_domiciliaria;

CREATE TABLE prod_base.t_r_nomenclatura_vial AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.r_nomenclatura_vial;

CREATE TABLE prod_base.t_r_sector AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.r_sector;

CREATE TABLE prod_base.t_r_vereda AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.r_vereda;

CREATE TABLE prod_base.t_r_zona_homogenea_fisica AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.r_zona_homogenea_fisica;

CREATE TABLE prod_base.t_r_zona_homogenea_geoeconomica AS
SELECT DISTINCT ON (objectid) *
FROM prod_base.r_zona_homogenea_geoeconomica;


/* =========================
   Llaves primarias por objectid
   ========================= */

ALTER TABLE prod_base.t_u_manzana                         ADD CONSTRAINT t_u_manzana_pk                        PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_u_nomenclatura_domiciliaria       ADD CONSTRAINT t_u_nomenclatura_domiciliaria_pk      PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_u_nomenclatura_vial               ADD CONSTRAINT t_u_nomenclatura_vial_pk              PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_u_perimetro                       ADD CONSTRAINT t_u_perimetro_pk                      PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_u_sector                          ADD CONSTRAINT t_u_sector_pk                         PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_u_zona_homogenea_fisica           ADD CONSTRAINT t_u_zona_homogenea_fisica_pk          PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_u_zona_homogenea_geoeconomica     ADD CONSTRAINT t_u_zona_homogenea_geoeconomica_pk    PRIMARY KEY (objectid);

ALTER TABLE prod_base.t_r_nomenclatura_domiciliaria       ADD CONSTRAINT t_r_nomenclatura_domiciliaria_pk      PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_r_nomenclatura_vial               ADD CONSTRAINT t_r_nomenclatura_vial_pk              PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_r_sector                          ADD CONSTRAINT t_r_sector_pk                         PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_r_vereda                          ADD CONSTRAINT t_r_vereda_pk                         PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_r_zona_homogenea_fisica           ADD CONSTRAINT t_r_zona_homogenea_fisica_pk          PRIMARY KEY (objectid);
ALTER TABLE prod_base.t_r_zona_homogenea_geoeconomica     ADD CONSTRAINT t_r_zona_homogenea_geoeconomica_pk    PRIMARY KEY (objectid);


/* =========================
   UNIQUE e índices por globalid
   (fuera de transacción por )
   ========================= */

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_manzana_globalid_uk
  ON prod_base.t_u_manzana (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_nomenclatura_domiciliaria_globalid_uk
  ON prod_base.t_u_nomenclatura_domiciliaria (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_nomenclatura_vial_globalid_uk
  ON prod_base.t_u_nomenclatura_vial (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_perimetro_globalid_uk
  ON prod_base.t_u_perimetro (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_sector_globalid_uk
  ON prod_base.t_u_sector (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_zona_homogenea_fisica_globalid_uk
  ON prod_base.t_u_zona_homogenea_fisica (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_u_zona_homogenea_geoeconomica_globalid_uk
  ON prod_base.t_u_zona_homogenea_geoeconomica (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_r_nomenclatura_domiciliaria_globalid_uk
  ON prod_base.t_r_nomenclatura_domiciliaria (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_r_nomenclatura_vial_globalid_uk
  ON prod_base.t_r_nomenclatura_vial (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_r_sector_globalid_uk
  ON prod_base.t_r_sector (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_r_vereda_globalid_uk
  ON prod_base.t_r_vereda (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_r_zona_homogenea_fisica_globalid_uk
  ON prod_base.t_r_zona_homogenea_fisica (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_r_zona_homogenea_geoeconomica_globalid_uk
  ON prod_base.t_r_zona_homogenea_geoeconomica (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';


/* =========================================
   Índices espaciales (PostGIS - GiST)
   (cambia 'shape' por 'geom' si aplica)
   ========================================= */

CREATE INDEX  IF NOT EXISTS t_u_manzana_shape_gist
  ON prod_base.t_u_manzana USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_u_nomenclatura_domiciliaria_shape_gist
  ON prod_base.t_u_nomenclatura_domiciliaria USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_u_nomenclatura_vial_shape_gist
  ON prod_base.t_u_nomenclatura_vial USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_u_perimetro_shape_gist
  ON prod_base.t_u_perimetro USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_u_sector_shape_gist
  ON prod_base.t_u_sector USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_u_zona_homogenea_fisica_shape_gist
  ON prod_base.t_u_zona_homogenea_fisica USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_u_zona_homogenea_geoeconomica_shape_gist
  ON prod_base.t_u_zona_homogenea_geoeconomica USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_r_nomenclatura_domiciliaria_shape_gist
  ON prod_base.t_r_nomenclatura_domiciliaria USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_r_nomenclatura_vial_shape_gist
  ON prod_base.t_r_nomenclatura_vial USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_r_sector_shape_gist
  ON prod_base.t_r_sector USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_r_vereda_shape_gist
  ON prod_base.t_r_vereda USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_r_zona_homogenea_fisica_shape_gist
  ON prod_base.t_r_zona_homogenea_fisica USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_r_zona_homogenea_geoeconomica_shape_gist
  ON prod_base.t_r_zona_homogenea_geoeconomica USING GIST (shape);
