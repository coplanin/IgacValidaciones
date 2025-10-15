

/* ============================================================
   Eliminar TABLAS LOCALES 
  ============================================================ */
BEGIN;
-- Snapshots en esquema prod
DROP TABLE IF EXISTS prod.t_asignaciones                               CASCADE;
DROP TABLE IF EXISTS prod.t_cr_datosphcondominio                        CASCADE;
DROP TABLE IF EXISTS prod.t_cr_fuenteespacial                           CASCADE;
DROP TABLE IF EXISTS prod.t_cr_terreno                                  CASCADE;
DROP TABLE IF EXISTS prod.t_cr_unidadconstruccion                       CASCADE;
DROP TABLE IF EXISTS prod.t_extdireccion                                 CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_caracteristicasunidadconstruccion        CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_datosadicionaleslevantamientocatastral   CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_derecho                                  CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_estructuraavaluo                         CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_fuenteadministrativa                     CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_interesado                               CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_marcas                                   CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_predio                                   CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_predio_informalidad                      CASCADE;
DROP TABLE IF EXISTS prod.t_ilc_tramitesderechosterritoriales            CASCADE;
DROP TABLE IF EXISTS prod.t_cr_predio_copropiedad            			 CASCADE;
COMMIT;


/* ============================================================
   Crear TABLAS LOCALES (snapshot) 
   ============================================================ */
CREATE TABLE prod.t_asignaciones AS 
SELECT DISTINCT ON (objectid) *
FROM prod.asignaciones_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_cr_datosphcondominio AS 
SELECT DISTINCT ON (objectid) *
FROM prod.cr_datosphcondominio_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_cr_fuenteespacial AS 
SELECT DISTINCT ON (objectid) *
FROM prod.cr_fuenteespacial_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_cr_terreno AS 
SELECT DISTINCT ON (objectid) *
FROM prod.cr_terreno_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_cr_unidadconstruccion AS 
SELECT DISTINCT ON (objectid) *
FROM prod.cr_unidadconstruccion_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_extdireccion AS 
SELECT DISTINCT ON (objectid) *
FROM prod.extdireccion_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_caracteristicasunidadconstruccion AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_caracteristicasunidadconstruccion_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_datosadicionaleslevantamientocatastral AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_datosadicionaleslevantamientocatastral_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_derecho AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_derecho_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_estructuraavaluo AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_estructuraavaluo_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_fuenteadministrativa AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_fuenteadministrativa_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_interesado AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_interesado_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_marcas AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_marcas_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_predio AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_predio_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_predio_informalidad AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_predio_informalidad_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;

CREATE TABLE prod.t_ilc_tramitesderechosterritoriales AS 
SELECT DISTINCT ON (objectid) *
FROM prod.ilc_tramitesderechosterritoriales_
WHERE gdb_branch_id = 0
  AND gdb_is_delete = 0  -- cambiar a "false" si es boolean
ORDER BY objectid, gdb_from_date DESC, gdb_archive_oid DESC;


select c.* 
from prod.t_cr_unidadconstruccion u
inner join prod.t_ilc_caracteristicasunidadconstruccion c
on u.globalid =c.unidadconstruccion_guid
where left(codigo,5)='13430';


select left(u.codigo,5),c.tipo_anexo ,count(*)
from prod.t_cr_unidadconstruccion u
inner join prod.t_ilc_caracteristicasunidadconstruccion c
on u.globalid =c.unidadconstruccion_guid
where  c.tipo_anexo is not null
group by left(u.codigo,5),c.tipo_anexo;


/* =========================
   llaves primarias
   ========================= */


ALTER TABLE prod.t_asignaciones ADD CONSTRAINT t_asignaciones_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_cr_datosphcondominio ADD CONSTRAINT t_cr_datosphcondominio_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_cr_fuenteespacial ADD CONSTRAINT t_cr_fuenteespacial_pk PRIMARY KEY (objectid);       
ALTER TABLE prod.t_cr_terreno ADD CONSTRAINT t_cr_terreno_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_cr_unidadconstruccion ADD CONSTRAINT t_cr_unidadconstruccion_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_extdireccion ADD CONSTRAINT t_extdireccion_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_caracteristicasunidadconstruccion ADD CONSTRAINT t_ilc_caracteristicasunidadconstruccion_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_datosadicionaleslevantamientocatastral  ADD CONSTRAINT t_ilc_datosadicionaleslevantamientocatastral_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_derecho  ADD CONSTRAINT t_ilc_derecho_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_estructuraavaluo  ADD CONSTRAINT t_ilc_estructuraavaluo_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_fuenteadministrativa   ADD CONSTRAINT t_ilc_fuenteadministrativa_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_interesado   ADD CONSTRAINT t_ilc_interesado_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_marcas  ADD CONSTRAINT t_ilc_marcas_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_predio  ADD CONSTRAINT t_ilc_predio_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_predio_informalidad  ADD CONSTRAINT t_ilc_predio_informalidad_pk PRIMARY KEY (objectid);
ALTER TABLE prod.t_ilc_tramitesderechosterritoriales  ADD CONSTRAINT t_ilc_tramitesderechosterritoriales_pk PRIMARY KEY (objectid);




/* =========================
   UNIQUE e indices por globalid
   ========================= */
CREATE UNIQUE INDEX  IF NOT EXISTS t_asignaciones_globalid_uk
  ON prod.t_asignaciones (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_cr_datosphcondominio_globalid_uk
  ON prod.t_cr_datosphcondominio (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_cr_fuenteespacial_globalid_uk
  ON prod.t_cr_fuenteespacial (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_cr_terreno_globalid_uk
  ON prod.t_cr_terreno (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_cr_unidadconstruccion_globalid_uk
  ON prod.t_cr_unidadconstruccion (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_extdireccion_globalid_uk
  ON prod.t_extdireccion (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_caracteristicasunidadconstruccion_globalid_uk
  ON prod.t_ilc_caracteristicasunidadconstruccion (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_datosadicionaleslevantamientocatastral_globalid_uk
  ON prod.t_ilc_datosadicionaleslevantamientocatastral (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_derecho_globalid_uk
  ON prod.t_ilc_derecho (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_estructuraavaluo_globalid_uk
  ON prod.t_ilc_estructuraavaluo (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_fuenteadministrativa_globalid_uk
  ON prod.t_ilc_fuenteadministrativa (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_interesado_globalid_uk
  ON prod.t_ilc_interesado (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_marcas_globalid_uk
  ON prod.t_ilc_marcas (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_predio_globalid_uk
  ON prod.t_ilc_predio (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_predio_informalidad_globalid_uk
  ON prod.t_ilc_predio_informalidad (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';

CREATE UNIQUE INDEX  IF NOT EXISTS t_ilc_tramitesderechosterritoriales_globalid_uk
  ON prod.t_ilc_tramitesderechosterritoriales (globalid)
  WHERE globalid IS NOT NULL AND globalid <> '{00000000-0000-0000-0000-000000000000}';


/* =========================================
    Índices espaciales (PostGIS - GiST)
   Tablas geográficas (shape -> cambia si es geom)
   ========================================= */
CREATE INDEX  IF NOT EXISTS t_ilc_predio_shape_gist
  ON prod.t_ilc_predio USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_ilc_marcas_shape_gist
  ON prod.t_ilc_marcas USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_cr_terreno_shape_gist
  ON prod.t_cr_terreno USING GIST (shape);

CREATE INDEX  IF NOT EXISTS t_cr_unidadconstruccion_shape_gist
  ON prod.t_cr_unidadconstruccion USING GIST (shape);






