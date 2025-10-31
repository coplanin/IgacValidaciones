SELECT * FROM colsmart_refresh_snapshots('colsmart_prod_owner', 'colsmart_prod_reader');

CREATE OR REPLACE FUNCTION colsmart_refresh_snapshots(
    p_source_schema text DEFAULT 'colsmart_prod_owner',
    p_target_schema text DEFAULT 'colsmart_prod_reader'
)
RETURNS TABLE(table_name text, row_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
  v_cnt bigint;
  v_tbl text;
  v_tables text[] := ARRAY[
    't_asignaciones',
    't_cr_datosphcondominio',
    't_cr_fuenteespacial',
    't_cr_terreno',
    't_cr_unidadconstruccion',
    't_extdireccion',
    't_ilc_caracteristicasunidadconstruccion',
    't_ilc_datosadicionaleslevantamientocatastral',
    't_ilc_derecho',
    't_ilc_estructuraavaluo',
    't_ilc_fuenteadministrativa',
    't_ilc_interesado',
    't_ilc_marcas',
    't_ilc_predio',
    't_ilc_predio_informalidad',
    't_ilc_tramitesderechosterritoriales',
    't_cr_predio_copropiedad'
  ];
BEGIN
  -- 1) DROP de snapshots existentes
  PERFORM 1;
  -- Lista explícita (incluye una que no se recrea: t_cr_predio_copropiedad)
	FOREACH v_tbl IN ARRAY v_tables LOOP
	    EXECUTE format('DROP TABLE IF EXISTS %I.%I CASCADE', p_target_schema, v_tbl);
	  END LOOP;

  -- 2) CREACIÓN de snapshots (última versión por OBJECTID y no borrado)
  -- helper para no repetir
  -- target_name, source_name (con sufijo _ en origen)
  PERFORM 1;
  -- t_asignaciones
  EXECUTE format($f$
    CREATE TABLE %I.t_asignaciones AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.asignaciones_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_cr_datosphcondominio AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.cr_datosphcondominio_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_cr_fuenteespacial AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.cr_fuenteespacial_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_cr_terreno AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.cr_terreno_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_cr_unidadconstruccion AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.cr_unidadconstruccion_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_extdireccion AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.extdireccion_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_caracteristicasunidadconstruccion AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_caracteristicasunidadconstruccion_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_datosadicionaleslevantamientocatastral AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_datosadicionaleslevantamientocatastral_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_derecho AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_derecho_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_estructuraavaluo AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_estructuraavaluo_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_fuenteadministrativa AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_fuenteadministrativa_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_interesado AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_interesado_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_marcas AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_marcas_
	  where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_predio AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_predio_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_predio_informalidad AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_predio_informalidad_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  EXECUTE format($f$
    CREATE TABLE %I.t_ilc_tramitesderechosterritoriales AS
    SELECT * FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY gdb_from_date DESC) AS rank
      FROM %I.ilc_tramitesderechosterritoriales_
		where gdb_branch_id=0
    ) t WHERE rank=1 AND gdb_is_delete=0
  $f$, p_target_schema, p_source_schema);

  -- 3) Llaves primarias (OBJECTID)
  PERFORM 1;
  EXECUTE format('ALTER TABLE %I.t_asignaciones ADD CONSTRAINT t_asignaciones_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_cr_datosphcondominio ADD CONSTRAINT t_cr_datosphcondominio_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_cr_fuenteespacial ADD CONSTRAINT t_cr_fuenteespacial_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_cr_terreno ADD CONSTRAINT t_cr_terreno_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_cr_unidadconstruccion ADD CONSTRAINT t_cr_unidadconstruccion_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_extdireccion ADD CONSTRAINT t_extdireccion_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_caracteristicasunidadconstruccion ADD CONSTRAINT t_ilc_caracteristicasunidadconstruccion_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_datosadicionaleslevantamientocatastral ADD CONSTRAINT t_ilc_datosadicionaleslevantamientocatastral_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_derecho ADD CONSTRAINT t_ilc_derecho_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_estructuraavaluo ADD CONSTRAINT t_ilc_estructuraavaluo_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_fuenteadministrativa ADD CONSTRAINT t_ilc_fuenteadministrativa_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_interesado ADD CONSTRAINT t_ilc_interesado_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_marcas ADD CONSTRAINT t_ilc_marcas_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_predio ADD CONSTRAINT t_ilc_predio_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_predio_informalidad ADD CONSTRAINT t_ilc_predio_informalidad_pk PRIMARY KEY (objectid)', p_target_schema);
  EXECUTE format('ALTER TABLE %I.t_ilc_tramitesderechosterritoriales ADD CONSTRAINT t_ilc_tramitesderechosterritoriales_pk PRIMARY KEY (objectid)', p_target_schema);

  -- 4) Índices únicos por GLOBALID (ignorando null/zero-guid)
  PERFORM 1;
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_asignaciones_globalid_uk
     ON %I.t_asignaciones (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_cr_datosphcondominio_globalid_uk
     ON %I.t_cr_datosphcondominio (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_cr_fuenteespacial_globalid_uk
     ON %I.t_cr_fuenteespacial (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_cr_terreno_globalid_uk
     ON %I.t_cr_terreno (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_cr_unidadconstruccion_globalid_uk
     ON %I.t_cr_unidadconstruccion (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_extdireccion_globalid_uk
     ON %I.t_extdireccion (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_caracteristicasunidadconstruccion_globalid_uk
     ON %I.t_ilc_caracteristicasunidadconstruccion (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_datosadicionaleslevantamientocatastral_globalid_uk
     ON %I.t_ilc_datosadicionaleslevantamientocatastral (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_derecho_globalid_uk
     ON %I.t_ilc_derecho (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_estructuraavaluo_globalid_uk
     ON %I.t_ilc_estructuraavaluo (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_fuenteadministrativa_globalid_uk
     ON %I.t_ilc_fuenteadministrativa (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_interesado_globalid_uk
     ON %I.t_ilc_interesado (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_marcas_globalid_uk
     ON %I.t_ilc_marcas (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_predio_globalid_uk
     ON %I.t_ilc_predio (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_predio_informalidad_globalid_uk
     ON %I.t_ilc_predio_informalidad (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);
  EXECUTE format(
    'CREATE UNIQUE INDEX IF NOT EXISTS t_ilc_tramitesderechosterritoriales_globalid_uk
     ON %I.t_ilc_tramitesderechosterritoriales (globalid)
     WHERE globalid IS NOT NULL AND globalid <> ''{00000000-0000-0000-0000-000000000000}''', p_target_schema);

  -- 5) Índices espaciales GiST (columna shape)
  PERFORM 1;
  EXECUTE format('CREATE INDEX IF NOT EXISTS t_ilc_predio_shape_gist ON %I.t_ilc_predio USING GIST (shape)', p_target_schema);
  EXECUTE format('CREATE INDEX IF NOT EXISTS t_ilc_marcas_shape_gist ON %I.t_ilc_marcas USING GIST (shape)', p_target_schema);
  EXECUTE format('CREATE INDEX IF NOT EXISTS t_cr_terreno_shape_gist ON %I.t_cr_terreno USING GIST (shape)', p_target_schema);
  EXECUTE format('CREATE INDEX IF NOT EXISTS t_cr_unidadconstruccion_shape_gist ON %I.t_cr_unidadconstruccion USING GIST (shape)', p_target_schema);

  -- 6) Informe final de cantidades (todas las tablas del esquema destino)
  FOR r IN
    SELECT c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = p_target_schema
      AND c.relkind IN ('r','p','f')
    ORDER BY c.relname
  LOOP
    EXECUTE format('SELECT count(*) FROM %I.%I', p_target_schema, r.table_name) INTO v_cnt;
    table_name := r.table_name;
    row_count  := v_cnt;
    RETURN NEXT;
  END LOOP;

  RETURN;
END;
$$;


