/**
 * Migración tabla predio
 */

ALTER TABLE ladm.ilc_predio ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255);
TRUNCATE TABLE ladm.ilc_predio CASCADE;

DROP TABLE IF EXISTS tmp_predio_raw;
CREATE TEMP TABLE tmp_predio_raw AS
SELECT
  p.*,
  TRIM(p.tipo) AS tipo_trim,
  TRIM(p.condicion_predio) AS condicion_trim,
  TRIM(p.destinacion_economica) AS destinacion_trim,
  TRIM(p.numero_predial_nacional) AS numero_predial_nacional_clean,
  TRIM(p.matricula_inmobiliaria) AS matricula_clean,
  -- homologaciones tipo
  CASE
    WHEN TRIM(p.tipo) = 'Privado' THEN 'Predio.Privado.Privado'
    WHEN TRIM(p.tipo) = 'Publico_Baldio' THEN 'Predio.Publico.Baldio.Baldio'
    WHEN TRIM(p.tipo) = 'Publico_Fiscal_Patrimonial' THEN 'Predio.Publico.Fiscal_Patrimonial'
    WHEN TRIM(p.tipo) = 'Predio.Privado.Privado' THEN 'Predio.Privado.Privado'
    WHEN TRIM(LOWER(p.tipo)) IN ('particular', 'privado') THEN 'Predio.Privado.Privado'
    ELSE NULL
  END AS tipo_homologado,
  -- homologaciones condición
  CASE
    WHEN TRIM(p.condicion_predio) = 'Condominio_Unidad_Predial' THEN 'Condominio.Unidad_Predial'
    WHEN TRIM(p.condicion_predio) = 'Informal' THEN 'Informal'
    WHEN TRIM(p.condicion_predio) = 'Mejoras_Terreno_Ajeno_No_PH' THEN 'Informal'
    WHEN TRIM(p.condicion_predio) = 'NPH' THEN 'NPH'
    WHEN TRIM(p.condicion_predio) = 'PH_Unidad_Predial' THEN 'PH.Unidad_Predial'
    WHEN TRIM(p.condicion_predio) = 'Bien_Uso_Publico' THEN 'Bien_Uso_Publico'
    ELSE NULL
  END AS condicion_homologada,
  -- homologaciones destinación
  CASE
    WHEN TRIM(p.destinacion_economica) = 'Lote_Urbanizable_No_Construido' THEN 'Lote_Urbanizado_No_Construido'
    WHEN TRIM(p.destinacion_economica) = 'Servicios_Especiales' THEN NULL
    ELSE TRIM(p.destinacion_economica)
  END AS destinacion_homologada,
  -- código municipio
  CASE 
    WHEN LEFT(TRIM(p.numero_predial_nacional), 5) ~ '^[0-9]+$' 
    THEN LEFT(TRIM(p.numero_predial_nacional), 5)::INTEGER
    ELSE NULL
  END AS mp_codigo,
  -- validaciones
  (TRIM(p.matricula_inmobiliaria) ~ '^[0-9]+$'
    AND LENGTH(TRIM(p.matricula_inmobiliaria)) <= 10
    AND TRIM(p.matricula_inmobiliaria)::BIGINT BETWEEN 1 AND 2147483647
  ) AS matricula_valida,
  (LEFT(TRIM(p.numero_predial_nacional),5) ~ '^[0-9]+$') AS codigo_municipio_valido,
  (LENGTH(TRIM(p.numero_predial_nacional)) = 30) AS numero_predial_largo_valido
FROM preprod.t_ilc_predio p;

-- Índices para acelerar joins
CREATE INDEX IF NOT EXISTS idx_tmp_predio_mp_codigo ON tmp_predio_raw (mp_codigo);
CREATE INDEX IF NOT EXISTS idx_tmp_predio_codigo_orip ON tmp_predio_raw (codigo_orip);
CREATE INDEX IF NOT EXISTS idx_tmp_predio_num_predial_clean ON tmp_predio_raw (numero_predial_nacional_clean);


INSERT INTO ladm.ilc_predio (
    t_ili_tid,
    departamento,
    municipio,
    codigo_orip,
    matricula_inmobiliaria,
    area_catastral_terreno,
    numero_predial_nacional,
    tipo,
    condicion_predio,
    destinacion_economica,
    area_registral_m2,
    nombre,
    comienzo_vida_util_version,
    fin_vida_util_version,
    espacio_de_nombres,
    id_operacion_predio,
    local_id
)
SELECT 
    uuid_generate_v4(),
    LEFT(m.mpcodigo::TEXT, 2),
    RIGHT(m.mpcodigo::TEXT, 3),
    p.codigo_orip,
    CASE 
      WHEN p.matricula_valida THEN p.matricula_clean::INTEGER
      ELSE NULL
    END,
    p.area_catastral_terreno,
    p.numero_predial_nacional_clean,
    pt.t_id,
    ct.t_id,
    det.t_id,
    p.area_registral_m2,
    NULL,
    NOW(),
    NULL,
    'ilc_predio',
    p.id_operacion,     
    p.objectid
FROM tmp_predio_raw p
JOIN ladm.ilc_prediotipo pt 
  ON pt.ilicode = COALESCE(p.tipo_homologado, p.tipo_trim)
JOIN ladm.ilc_condicionprediotipo ct 
  ON ct.ilicode = COALESCE(p.condicion_homologada, p.condicion_trim)
JOIN ladm.ilc_destinacioneconomicatipo det 
  ON det.ilicode = COALESCE(p.destinacion_homologada, p.destinacion_trim)
JOIN preprod.municipios m 
  ON m.mpcodigo = p.mp_codigo
WHERE 
    p.mp_codigo IS NOT NULL
    AND p.area_catastral_terreno IS NOT NULL
    AND p.numero_predial_largo_valido
    AND p.matricula_valida;

DROP TABLE IF EXISTS preprod.t_predios_rechazados;

CREATE TABLE preprod.t_predios_rechazados AS
WITH con_municipios AS (
  SELECT 
    ph.*,
    m.mpcodigo IS NOT NULL AS municipio_encontrado
  FROM tmp_predio_raw ph
  LEFT JOIN preprod.municipios m ON m.mpcodigo = ph.mp_codigo
),
rechazados AS (
  SELECT *,
    array_remove(array[
      CASE WHEN tipo_homologado IS NULL THEN 'tipo no homologado' ELSE NULL END,
      CASE WHEN condicion_homologada IS NULL THEN 'condición no homologada' ELSE NULL END,
      CASE WHEN destinacion_homologada IS NULL THEN 'destinación no homologada' ELSE NULL END,
      CASE WHEN mp_codigo IS NULL THEN 'código municipal no válido' ELSE NULL END,
      CASE WHEN municipio_encontrado = FALSE THEN 'municipio no encontrado' ELSE NULL END,
      CASE WHEN area_catastral_terreno IS NULL THEN 'área catastral nula' ELSE NULL END,
      CASE WHEN NOT numero_predial_largo_valido THEN 'número predial no tiene 30 dígitos' ELSE NULL END,
      CASE WHEN NOT matricula_valida THEN 'matrícula inmobiliaria inválida' ELSE NULL END
    ], NULL) AS causas
  FROM con_municipios
)
SELECT 
  r.objectid,
  r.codigo_orip,
  r.matricula_clean AS matricula_inmobiliaria,
  r.area_catastral_terreno,
  r.numero_predial_nacional_clean AS numero_predial_nacional,
  r.tipo,
  r.condicion_predio,
  r.destinacion_economica,
  r.area_registral_m2,
  r.tipo_homologado,
  r.condicion_homologada,
  r.destinacion_homologada,
  r.mp_codigo,
  r.municipio_encontrado,
  array_to_string(r.causas, ', ') AS detalle
FROM rechazados r
WHERE array_length(causas, 1) > 0;



/**
 * 
 * Migracion tabla ilc_caracteristicasunidadconstruccion
 * 
 */
ALTER TABLE ladm.ilc_caracteristicasunidadconstruccion
  ADD COLUMN IF NOT EXISTS id_empate varchar(255);
CREATE INDEX IF NOT EXISTS ilc_caract_uc_idx_idempate
  ON ladm.ilc_caracteristicasunidadconstruccion (id_empate);
TRUNCATE TABLE ladm.ilc_caracteristicasunidadconstruccion CASCADE;
TRUNCATE TABLE preprod.t_caracteristicas_rechazadas RESTART IDENTITY;
DROP TABLE IF EXISTS tmp_uso_map_id;
WITH fix AS (
  SELECT * FROM (VALUES
    ('Anexo_Cocheras_Banieras_Porquerizas','Anexo.Cocheras_Marraneras_Porquerizas'),
    ('Institucional_Puesto_De_Salud','Institucional.Puestos_de_Salud'),
    ('Comercial_Teatro_Cinema_En_PH','Comercial.Teatro_Cinemas_en_PH'),
    ('Comercial_Pensiones_Residencias','Comercial.Pensiones_y_Residencias'),
    ('Institucional_Bibliotecas','Institucional.Biblioteca'),
    ('Residencial_Apartamentos_4_y_mas_Pisos_en_PH','Residencial.Apartamentos_4_y_mas_pisos_en_PH'),
    ('Residencial_Apartamentos_Mas_De_4_Pisos','Residencial.Apartamentos_4_y_mas_pisos'),
    ('Residencial_Vivienda_Hasta_3_Pisos_En_PH','Residencial.Vivienda_Hasta_3_Pisos_En_PH'),
    ('Residencial_Vivienda_Recreacional_En_PH','Residencial.Vivienda_Recreacional'),
    ('Comercial_Restaurante_En_PH','Comercial.Restaurantes_en_PH'),
    ('Residencial_Garajes_En_PH','Residencial.Garajes_En_PH'),
    ('Industrial_Industria_En_PH','Industrial.Industrias_en_PH'),
    ('Sin_Definir', NULL)
  ) AS v(uso_raw, uso_fix)
),
uso_map AS (
  SELECT
    u.uso_raw,
    COALESCE(
      f.uso_fix,
      REGEXP_REPLACE(REPLACE(REPLACE(u.uso_raw,'_De_','_de_'),'_En_','_en_'), '^([^_]+)_','\1.')
    ) AS uso_norm
  FROM (SELECT DISTINCT uso AS uso_raw FROM preprod.t_ilc_caracteristicasunidadconstruccion) u
  LEFT JOIN fix f USING (uso_raw)
)
SELECT
  um.uso_raw,
  COALESCE(c_exact.t_id, c_norm.t_id) AS uso_t_id
INTO TEMP TABLE tmp_uso_map_id
FROM uso_map um
LEFT JOIN ladm.cr_usouconstipo c_exact ON c_exact.ilicode = um.uso_raw
LEFT JOIN ladm.cr_usouconstipo c_norm  ON c_norm.ilicode  = um.uso_norm;

-- 3) Un (1) registro por objectid
DROP TABLE IF EXISTS tmp_caracteristicas_unicas;
CREATE TEMP TABLE tmp_caracteristicas_unicas AS
SELECT *
FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY t.objectid ORDER BY t.id_caracteristicas_unidad_cons) AS rn
  FROM preprod.t_ilc_caracteristicasunidadconstruccion t
) x
WHERE rn = 1;

-- 4) Un (1) UC por id_caracteristicasunidadconstru
DROP TABLE IF EXISTS tmp_uc_unica;
CREATE TEMP TABLE tmp_uc_unica AS
SELECT *
FROM (
  SELECT cu.*,
         ROW_NUMBER() OVER (PARTITION BY cu.id_caracteristicasunidadconstru ORDER BY cu.objectid) AS rn
  FROM preprod.t_cr_unidadconstruccion cu
) y
WHERE rn = 1;


DROP TABLE IF EXISTS tmp_base;
CREATE TEMP TABLE tmp_base AS
SELECT
  icuc.*,
  ucu.objectid              AS uc_objectid,
  ucu.etiqueta,
  ucu.anio_construccion,
  ucu.area_construccion,
  ucu.area_privada_construida,
  dut.t_id                  AS tipo_uc_t_id,
  umi.uso_t_id              AS uso_uc_t_id,
  icuc.objectid             AS local_id
FROM tmp_caracteristicas_unicas icuc
LEFT JOIN tmp_uc_unica ucu
       ON ucu.id_caracteristicasunidadconstru = icuc.id_caracteristicas_unidad_cons
LEFT JOIN ladm.cr_unidadconstrucciontipo dut
       ON dut.ilicode = icuc.tipo_unidad_construccion
LEFT JOIN tmp_uso_map_id umi
       ON umi.uso_raw = icuc.uso;

-- Etiquetado 
DROP TABLE IF EXISTS tmp_etiquetado;
CREATE TEMP TABLE tmp_etiquetado AS
SELECT
  b.*,
  (
    tipo_uc_t_id IS NOT NULL
    AND uso_uc_t_id  IS NOT NULL
    AND anio_construccion IS NOT NULL
    AND anio_construccion BETWEEN 1512 AND 2500
    AND area_construccion IS NOT NULL
    AND area_construccion BETWEEN 0 AND 99999999999999.9
    AND total_plantas IS NOT NULL
    AND total_plantas BETWEEN 0 AND 150
  ) AS es_valido
FROM tmp_base b;

--INSERT válidos 
INSERT INTO ladm.ilc_caracteristicasunidadconstruccion (
  t_ili_tid, identificador, tipo_unidad_construccion,
  total_plantas, uso, anio_construccion,
  area_construida, area_privada_construida, observaciones,
  usos_tradicionales_culturales,
  comienzo_vida_util_version, fin_vida_util_version,
  espacio_de_nombres, local_id, id_empate
)
SELECT DISTINCT ON (e.local_id)
  uuid_generate_v4(),
  CASE WHEN length(e.etiqueta) > 20 THEN left(e.etiqueta,20) ELSE e.etiqueta END,
  e.tipo_uc_t_id,
  e.total_plantas,
  e.uso_uc_t_id,
  e.anio_construccion,
  e.area_construccion,
  e.area_privada_construida,
  e.observaciones,
  NULLIF(REGEXP_REPLACE(e.usos_tradicionales_culturales,'\D','','g'),'')::bigint,
  NOW(),
  'infinity'::timestamp,
  'ilc_caracteristicasunidadconstruccion',
  e.local_id,
  e.id_caracteristicas_unidad_cons
FROM tmp_etiquetado e
WHERE e.es_valido
ORDER BY e.local_id, e.id_caracteristicas_unidad_cons;

--  Rechazados 
WITH rej AS (
  SELECT DISTINCT ON (e.local_id)
    e.local_id,
    e.id_caracteristicas_unidad_cons,
    e.tipo_uc_t_id,
    e.total_plantas,
    e.uso,
    e.usos_tradicionales_culturales,
    e.etiqueta,
    e.anio_construccion,
    e.area_construccion,
    e.area_privada_construida,
    ARRAY_REMOVE(ARRAY[
      CASE WHEN e.tipo_uc_t_id IS NULL                               THEN 'tipo UC no encontrado' END,
      CASE WHEN e.uso_uc_t_id  IS NULL                               THEN 'uso no encontrado' END,
      CASE WHEN e.anio_construccion IS NULL                          THEN 'año construcción nulo' END,
      CASE WHEN e.anio_construccion IS NOT NULL
           AND e.anio_construccion NOT BETWEEN 1512 AND 2500          THEN 'año construcción inválido' END,
      CASE WHEN e.area_construccion IS NULL                          THEN 'área construcción nula' END,
      CASE WHEN e.area_construccion IS NOT NULL
           AND e.area_construccion NOT BETWEEN 0 AND 99999999999999.9 THEN 'área construcción inválida' END,
      CASE WHEN e.total_plantas IS NULL                              THEN 'total plantas nulo' END,
      CASE WHEN e.total_plantas IS NOT NULL
           AND e.total_plantas NOT BETWEEN 0 AND 150                  THEN 'total plantas inválido' END,
      CASE WHEN e.uc_objectid IS NULL                                THEN 'unidad construcción no encontrada' END
    ], NULL)::text[] AS causas_rechazo
  FROM tmp_etiquetado e
  WHERE NOT e.es_valido
  ORDER BY e.local_id, e.id_caracteristicas_unidad_cons
)
INSERT INTO preprod.t_caracteristicas_rechazadas (
  local_id,
  id_caracteristicas_unidad_cons,
  tipo_unidad_construccion,
  total_plantas,
  uso,
  usos_tradicionales_culturales,
  identificador,
  anio_construccion,
  area_construccion,
  area_privada_construida,
  causas_rechazo
)
SELECT
  rej.local_id,
  rej.id_caracteristicas_unidad_cons,   -- ← aquí estaba el typo
  rej.tipo_uc_t_id,
  rej.total_plantas,
  rej.uso,
  rej.usos_tradicionales_culturales,
  COALESCE(rej.etiqueta, rej.id_caracteristicas_unidad_cons::text),
  rej.anio_construccion,
  rej.area_construccion,
  rej.area_privada_construida,
  rej.causas_rechazo
FROM rej;

UPDATE ladm.ilc_caracteristicasunidadconstruccion
SET comienzo_vida_util_version = NOW(),
    fin_vida_util_version = NULL;



/**
 * 
 * Migracion tabla Unidad construccion
 * 
 */

ALTER TABLE ladm.cr_unidadconstruccion
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS id_predio bigint;
CREATE INDEX IF NOT EXISTS cruc_src_idop_idx
  ON preprod.t_cr_unidadconstruccion (id_operacion_predio);
CREATE INDEX IF NOT EXISTS ilc_predio_idop_idx
  ON ladm.ilc_predio (id_operacion_predio);

TRUNCATE TABLE ladm.cr_unidadconstruccion CASCADE;

WITH
dim2d   AS (
  SELECT t_id FROM ladm.col_dimensiontipo
  WHERE ilicode = 'Dim2D' LIMIT 1
),
rasante AS (
  SELECT t_id FROM ladm.col_relacionsuperficietipo
  WHERE ilicode = 'En_Rasante' LIMIT 1
),

-- Mapa id_operacion_predio -> t_id (predio) determinístico
predio_map AS (
  SELECT btrim(id_operacion_predio::text) AS id_op,
         MIN(t_id) AS predio_t_id
  FROM ladm.ilc_predio
  GROUP BY 1
),

caract_map AS (
  SELECT id_empate, MIN(t_id) AS caract_t_id
  FROM   ladm.ilc_caracteristicasunidadconstruccion
  GROUP  BY id_empate
),
planta_map AS (
  SELECT ilicode::text AS planta_key, MIN(t_id) AS planta_t_id
  FROM   ladm.cr_construccionplantatipo
  GROUP  BY ilicode
),

base AS (
  SELECT
      src.objectid,
      src.id_caracteristicasunidadconstru,
      src.tipo_planta,
      src.planta_ubicacion,
      src.altura,
      src.shape,
      src.etiqueta,
      btrim(src.id_operacion_predio::text) AS id_operacion_predio,   -- <<< aquí
      pm.predio_t_id                         AS id_predio,            -- <<< y aquí
      cm.caract_t_id,
      pl.planta_t_id,
      (SELECT t_id FROM dim2d)   AS dim2d_t_id,
      (SELECT t_id FROM rasante) AS rasante_t_id,
      CASE
        WHEN src.shape IS NULL THEN NULL
        WHEN ST_SRID(src.shape) = 9377
             AND GeometryType(src.shape) LIKE 'MULTIPOLYGON%'
             AND ST_ZMin(src.shape) IS NOT NULL
        THEN src.shape
        ELSE ST_Multi(
               ST_Force3DZ(
                 ST_SetSRID(src.shape, 9377)
               )
             )
      END AS geom_mpz
  FROM preprod.t_cr_unidadconstruccion src
  LEFT JOIN predio_map pm
         ON pm.id_op = btrim(src.id_operacion_predio::text)
  LEFT JOIN caract_map cm
         ON cm.id_empate = src.id_caracteristicasunidadconstru
  LEFT JOIN planta_map pl
         ON pl.planta_key = src.tipo_planta::text
),

-- válidos completos
empatados AS (
  SELECT * FROM base
  WHERE geom_mpz    IS NOT NULL
    AND caract_t_id IS NOT NULL
    AND planta_t_id IS NOT NULL
),

-- inserta válidos
ins_valid AS (
  INSERT INTO ladm.cr_unidadconstruccion (
      t_ili_tid,
      tipo_planta,
      planta_ubicacion,
      altura,
      geometria,
      cr_caracteristicasunidadconstruccion,
      dimension,
      etiqueta,
      relacion_superficie,
      comienzo_vida_util_version,
      fin_vida_util_version,
      espacio_de_nombres,
      local_id,
      id_operacion_predio,   -- <<< nuevo
      id_predio              -- <<< nuevo (FK a ilc_predio)
  )
  SELECT
      uuid_generate_v4(),
      e.planta_t_id,
      e.planta_ubicacion,
      e.altura,
      e.geom_mpz,
      e.caract_t_id,
      e.dim2d_t_id,
      e.etiqueta,
      e.rasante_t_id,
      NOW(),
      NULL::timestamp,
      'cr_unidadconstruccion',
      e.objectid,
      e.id_operacion_predio,
      e.id_predio
  FROM empatados e
  RETURNING 1
),

-- no válidos con causa (agregamos id_operacion_predio para auditoría)
no_empatan AS (
  SELECT
      b.objectid,
      b.id_caracteristicasunidadconstru,
      b.tipo_planta,
      b.planta_ubicacion,
      b.altura,
      b.shape,
      b.etiqueta,
      b.id_operacion_predio,
      CASE
        WHEN b.geom_mpz IS NULL THEN 'geometría inválida o nula'
        WHEN b.caract_t_id IS NULL AND b.planta_t_id IS NULL THEN 'id_empate y tipo_planta no encontrados'
        WHEN b.caract_t_id IS NULL THEN 'id_empate no encontrado'
        ELSE 'tipo_planta no encontrado'
      END AS causa
  FROM base b
  WHERE geom_mpz    IS NULL
     OR caract_t_id IS NULL
     OR planta_t_id IS NULL
)

-- vuelca no válidos
INSERT INTO preprod.t_cr_unidadconstruccion_no_empate (
    objectid,
    id_caracteristicasunidadconstru,
    tipo_planta,
    planta_ubicacion,
    altura,
    shape,
    etiqueta,
    causa
)
SELECT
    n.objectid,
    n.id_caracteristicasunidadconstru,
    n.tipo_planta,
    n.planta_ubicacion,
    n.altura,
    n.shape,
    n.etiqueta,
    n.causa
FROM no_empatan n;


/**
 * Migracion tabla terreno
 *
 * 
 */
INSERT INTO ladm.cr_terreno (
    t_ili_tid,
    geometria,
    dimension,
    etiqueta,
    relacion_superficie,
    comienzo_vida_util_version,
    fin_vida_util_version,
    espacio_de_nombres,
    local_id,
    cod_match
)
SELECT
    uuid_generate_v4() AS t_ili_tid,
    ST_Force3D(ST_Multi(shape)) AS geometria,
    (SELECT t_id FROM ladm.col_dimensiontipo WHERE ilicode = 'Dim2D') AS dimension,
    etiqueta,
    (SELECT t_id FROM ladm.col_relacionsuperficietipo WHERE ilicode = 'En_Rasante') AS relacion_superficie,
    NOW() AS comienzo_vida_util_version,
    NULL::timestamp AS fin_vida_util_version,
    'cr_terreno' AS espacio_de_nombres,
    objectid::varchar AS local_id,
    id_operacion_predio AS cod_match
FROM 
    preprod.cr_terreno;
    
/**
 * Migracion tabla ladm.cuc_tipologiaconstruccion
 *
 * 
 */

ALTER TABLE ladm.cuc_tipologiaconstruccion 
  ADD COLUMN IF NOT EXISTS id_match bigint;

TRUNCATE TABLE ladm.cuc_tipologiaconstruccion CASCADE;
DROP TABLE IF EXISTS tmp_tipologia_map;
DROP TABLE IF EXISTS tmp_tipologia_no_hom;

CREATE TEMP TABLE tmp_tipologia_map AS
SELECT
  t.*,
  t.objectid AS id_match,
  CASE
    WHEN t.tipo_tipologia LIKE 'Institucional_Tipo_%'      
      THEN 'Institucional.' || t.tipo_tipologia
    WHEN t.tipo_tipologia LIKE 'Institucional_Religioso_%' 
      THEN 'Institucional.' || regexp_replace(t.tipo_tipologia, '^Institucional_Religioso_', 'Religioso_')
    WHEN t.tipo_tipologia LIKE 'Institucional_Salud_%'     
      THEN 'Institucional.' || regexp_replace(t.tipo_tipologia, '^Institucional_Salud_', 'Salud_')
    WHEN t.tipo_tipologia LIKE 'ED_%'                      
      THEN 'ED.' || t.tipo_tipologia
    ELSE regexp_replace(t.tipo_tipologia, '^([^_]+)_', '\1.', 'g')
  END AS tipo_tipologia_hom,
  t.conservacion_tipologia AS conservacion_hom
FROM preprod.t_ilc_caracteristicasunidadconstruccion t
WHERE t.tipo_tipologia IS NOT NULL 
  AND t.conservacion_tipologia IS NOT NULL;

INSERT INTO ladm.cuc_tipologiaconstruccion (
  t_ili_tid,
  tipo_tipologia,
  conservacion,
  id_match
)
SELECT
  uuid_generate_v4(),
  dom_tipo.t_id,
  dom_cons.t_id,
  t.id_match
FROM tmp_tipologia_map t
JOIN ladm.cuc_tipologiatipo                dom_tipo ON dom_tipo.ilicode = t.tipo_tipologia_hom
JOIN ladm.cuc_estadoconservaciontipologiatipo dom_cons ON dom_cons.ilicode = t.conservacion_hom;

DELETE FROM ladm.cuc_tipologiaconstruccion c
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_caracteristicasunidadconstruccion i
  WHERE i.local_id::bigint = c.id_match
);
    
/**
 * Migracion tabla ladm.cuc_tipologianoconvencional
 *
 * 
 */

ALTER TABLE ladm.cuc_tipologianoconvencional 
  ADD COLUMN IF NOT EXISTS id_match bigint;

TRUNCATE TABLE ladm.cuc_tipologianoconvencional CASCADE;

CREATE TABLE IF NOT EXISTS preprod.cuc_tipologianoconvencional_rechazados (
  tipo_anexo             text,
  tipo_anexo_hom         text,
  conservacion_anexo     text,
  id_match               bigint,
  motivo                 text
);
TRUNCATE TABLE preprod.cuc_tipologianoconvencional_rechazados;
DROP TABLE IF EXISTS tmp_anexo_map;
DROP TABLE IF EXISTS preprod.tmp_anexo_no_hopm;
CREATE TEMP TABLE tmp_anexo_map AS
SELECT
  t.*,
  t.objectid AS id_match,
  CASE
    WHEN tipo_anexo = 'Albercas_Baniaderas_Tipo_40' THEN 'Albercas_Baniaderas.Sencilla_Tipo_40'
    WHEN tipo_anexo = 'Albercas_Baniaderas_Tipo_60' THEN 'Albercas_Baniaderas.Medio_Tipo_60'
    WHEN tipo_anexo = 'Albercas_Baniaderas_Tipo_80' THEN 'Albercas_Baniaderas.Plus_Tipo_80'
    WHEN tipo_anexo = 'Beneficiaderos_Tipo_40' THEN 'Beneficiaderos.Sencilla_Tipo_40'
    WHEN tipo_anexo = 'Beneficiaderos_Tipo_60' THEN 'Beneficiaderos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Beneficiaderos_Tipo_80' THEN 'Beneficiaderos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Carreteras_Tipo_60' THEN 'Carreteras.Zona_Dura_Adoquin_Trafico_Liviano_Tipo_60'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_20' THEN 'Cimientos_Estructura_Muros_Placabase.Simples_Tipo_20'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_40' THEN 'Cimientos_Estructura_Muros_Placabase.Simples_Placa_Tipo_40'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_60' THEN 'Cimientos_Estructura_Muros_Placabase.Muro_Tipo_60'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_80' THEN 'Cimientos_Estructura_Muros_Placabase.Placa_Muro_Tipo_80'
    WHEN tipo_anexo = 'Cocheras_Marraneras_Porquerizas_Tipo_20' THEN 'Cocheras_Marraneras_Porquerizas.Sencilla_Tipo_20'
    WHEN tipo_anexo = 'Cocheras_Marraneras_Porquerizas_Tipo_40' THEN 'Cocheras_Marraneras_Porquerizas.Media_Tipo_40'
    WHEN tipo_anexo = 'Cocheras_Marraneras_Porquerizas_Tipo_80' THEN 'Cocheras_Marraneras_Porquerizas.Tecnificada_Tipo_80'
    WHEN tipo_anexo = 'Corrales_Tipo_20' THEN 'Corrales.Sencillo_Tipo_20'
    WHEN tipo_anexo = 'Corrales_Tipo_40' THEN 'Corrales.Medio_Tipo_40'
    WHEN tipo_anexo = 'Corrales_Tipo_80' THEN 'Corrales.Tecnificado_Tipo_80'
    WHEN tipo_anexo = 'Establos_Pesebreras_Tipo_20' THEN 'Establos_Pesebreras.Sencillo_Tipo_20'
    WHEN tipo_anexo = 'Establos_Pesebreras_Tipo_60' THEN 'Establos_Pesebreras.Medio_Tipo_60'
    WHEN tipo_anexo = 'Establos_Pesebreras_Tipo_80' THEN 'Establos_Pesebreras.Tecnificado_Tipo_80'
    WHEN tipo_anexo = 'Galpones_Gallineros_Tipo_40' THEN 'Galpones_Gallineros.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Galpones_Gallineros_Tipo_60' THEN 'Galpones_Gallineros.Medio_Tipo_60'
    WHEN tipo_anexo = 'Galpones_Gallineros_Tipo_80' THEN 'Galpones_Gallineros.Tecnificado_Tipo_80'
    WHEN tipo_anexo = 'Kioskos_Tipo_40' THEN 'Kioscos.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Kioskos_Tipo_60' THEN 'Kioscos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Kioskos_Tipo_80' THEN 'Kioscos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Marquesinas_Tipo_40' THEN 'Marquesinas_Patios_Cubiertos.Sencilla_Tipo_40'
    WHEN tipo_anexo = 'Marquesinas_Tipo_60' THEN 'Marquesinas_Patios_Cubiertos.Media_Tipo_60'
    WHEN tipo_anexo = 'Marquesinas_Tipo_80' THEN 'Marquesinas_Patios_Cubiertos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Piscinas_Tipo_40' THEN 'Piscinas.Pequena_Tipo_40'
    WHEN tipo_anexo = 'Piscinas_Tipo_50' THEN 'Piscinas.Mediana_Tipo_50'
    WHEN tipo_anexo = 'Piscinas_Tipo_60' THEN 'Piscinas.Grande_Tipo_60'
    WHEN tipo_anexo = 'Piscinas_Tipo_80' THEN 'Piscinas.Prefabricada_Tipo_80'
    WHEN tipo_anexo = 'Pozos_Tipo_40' THEN 'Pozos.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Pozos_Tipo_60' THEN 'Pozos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Secaderos_Tipo_40' THEN 'Secaderos.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Secaderos_Tipo_60' THEN 'Secaderos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Secaderos_Tipo_80' THEN 'Secaderos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Silos_Tipo_80' THEN 'Silos.En_Acero_Galvanizado_Tipo_80'
    WHEN tipo_anexo = 'Tanques_Tipo_20' THEN 'Tanques.Sencillo_Sin_Revestir_Tipo_20'
    WHEN tipo_anexo = 'Tanques_Tipo_40' THEN 'Tanques.Medio_Tipo_40'
    WHEN tipo_anexo = 'Tanques_Tipo_60' THEN 'Tanques.Elevados_Plus_60'
    WHEN tipo_anexo = 'Toboganes_Tipo_60' THEN 'Toboganes.Medio_Tipo_60'
    WHEN tipo_anexo = 'Toboganes_Tipo_80' THEN 'Toboganes.Plus_Tipo_80'
    WHEN tipo_anexo = 'TorresEnfriamiento_Tipo_60' THEN 'Torres_Enfriamiento.Torres_Enfriamiento_Tipo_60'
    ELSE NULL
  END AS tipo_anexo_hom
FROM preprod.t_ilc_caracteristicasunidadconstruccion t;  -- sin filtros de NULL

-- 4) INSERT válidos (exige todo OK)
INSERT INTO ladm.cuc_tipologianoconvencional (
  t_ili_tid,
  tipo_anexo,
  conservacion_anexo,
  id_match
)
SELECT
  uuid_generate_v4(),
  dom_anexo.t_id,
  dom_cons.t_id,
  t.id_match
FROM tmp_anexo_map t
JOIN ladm.cuc_anexotipo                       AS dom_anexo ON dom_anexo.ilicode = t.tipo_anexo_hom
JOIN ladm.cuc_estadoconservaciontipologiatipo AS dom_cons  ON dom_cons.ilicode  = t.conservacion_anexo
WHERE t.tipo_anexo_hom IS NOT NULL
  AND t.conservacion_anexo IS NOT NULL;
CREATE TABLE preprod.tmp_anexo_no_hopm AS
SELECT
  t.tipo_anexo,
  t.tipo_anexo_hom,
  t.conservacion_anexo,
  t.id_match,
  dom_anexo.t_id AS tipo_anexo_t_id,
  dom_cons.t_id  AS conservacion_t_id,
  CASE
    WHEN t.conservacion_anexo IS NULL    THEN 'conservacion_anexo NULL'
    WHEN t.tipo_anexo_hom IS NULL        THEN 'sin regla de homologación (tipo_anexo_hom NULL)'
    WHEN dom_anexo.t_id IS NULL 
         AND dom_cons.t_id IS NULL       THEN 'ilicode tipo_anexo y conservacion NO existen'
    WHEN dom_anexo.t_id IS NULL          THEN 'ilicode tipo_anexo NO existe'
    WHEN dom_cons.t_id  IS NULL          THEN 'ilicode conservacion_anexo NO existe'
    ELSE 'desconocido'
  END AS motivo
FROM tmp_anexo_map t
LEFT JOIN ladm.cuc_anexotipo                       dom_anexo ON dom_anexo.ilicode = t.tipo_anexo_hom
LEFT JOIN ladm.cuc_estadoconservaciontipologiatipo dom_cons  ON dom_cons.ilicode  = t.conservacion_anexo
WHERE t.tipo_anexo IS NOT NULL
  AND NOT (
    t.tipo_anexo_hom IS NOT NULL
    AND t.conservacion_anexo IS NOT NULL
    AND dom_anexo.t_id IS NOT NULL
    AND dom_cons.t_id  IS NOT NULL
  );
DELETE FROM ladm.cuc_tipologianoconvencional c
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_caracteristicasunidadconstruccion i
  WHERE NULLIF(ltrim(regexp_replace(i.local_id::text, '\D','','g'), '0'), '')::bigint = c.id_match
);
DELETE FROM preprod.tmp_anexo_no_hopm r
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_caracteristicasunidadconstruccion i
  WHERE NULLIF(ltrim(regexp_replace(i.local_id::text, '\D','','g'), '0'), '')::bigint = r.id_match
);


/**
 * Migracion tabla ladm.cuc_calificacion_unidadconstruccion
 *
 * 
 */
 truncate table ladm.cuc_calificacion_unidadconstruccion;
INSERT INTO ladm.cuc_calificacion_unidadconstruccion (
    t_ili_tid,
    ilc_caracteristicasunidadconstruccion,
    cuc_clfccnndcnstrccion_cuc_tipologiaconstruccion,
    cuc_clfccnndcnstrccion_cuc_calificacionconvencional,
    cuc_clfccnndcnstrccion_cuc_tipologianoconvencional
)
SELECT
    uuid_generate_v4() AS t_ili_tid,
    car.t_id           AS ilc_caracteristicasunidadconstruccion,
    tc.t_id            AS cuc_clfccnndcnstrccion_cuc_tipologiaconstruccion,
    NULL::bigint       AS cuc_clfccnndcnstrccion_cuc_calificacionconvencional,
    tnc.t_id           AS cuc_clfccnndcnstrccion_cuc_tipologianoconvencional
FROM ladm.ilc_caracteristicasunidadconstruccion AS car
LEFT JOIN ladm.cuc_tipologiaconstruccion AS tc
    ON tc.id_match::text = car.local_id::text
LEFT JOIN ladm.cuc_tipologianoconvencional AS tnc
    ON tnc.id_match::text = car.local_id::text;

 /**
 * Migracion tabla ladm.ilc_estructuraavaluo_rechazado
 *
 * 
 */
 
CREATE TABLE IF NOT EXISTS preprod.ilc_estructuraavaluo_rechazados (
  id_operacion_predio             text,
  fecha_avaluo_catastral          text,
  valor_comercial                 numeric(16,1),
  avaluo_catastral                numeric(16,1),
  valor_comercial_terreno         numeric(16,1),
  avaluo_catastral_terreno        numeric(16,1),
  valor_comercial_total_unidadesc numeric(16,1),
  avaluo_catastral_total_unidades numeric(16,1),
  autoestimacion_src              text,
  autoestimacion_bool             boolean,
  predio_t_id                     bigint,
  causas                          text[]
);
TRUNCATE TABLE preprod.ilc_estructuraavaluo_rechazados;

DROP TABLE IF EXISTS tmp_src;
CREATE TEMP TABLE tmp_src AS
SELECT
  pre.*,
  p.t_id AS predio_t_id,
  CASE
    WHEN pre.autoestimacion IS NULL THEN NULL
    WHEN pre.autoestimacion ~* '^(si|sí|s|y|yes|on|true|t|1)$'  THEN TRUE
    WHEN pre.autoestimacion ~* '^(no|n|off|false|f|0)$'         THEN FALSE
    ELSE NULL
  END AS auto_bool,
  pre.fecha_avaluo_catastral::date AS fecha_cat_date
FROM preprod.t_ilc_estructuraavaluo pre
LEFT JOIN ladm.ilc_predio p
  ON p.id_operacion_predio = pre.id_operacion_predio;

DROP TABLE IF EXISTS tmp_val;
CREATE TEMP TABLE tmp_val AS
SELECT
  s.*,
  ARRAY_REMOVE(ARRAY[
    -- FK
    CASE WHEN s.predio_t_id IS NULL THEN 'sin match en ladm.ilc_predio por id_operacion_predio' END,
    -- NOT NULL obligatorios
    CASE WHEN s.fecha_cat_date IS NULL THEN 'fecha_avaluo_catastral NULL' END,
    CASE WHEN s.avaluo_catastral IS NULL THEN 'avaluo_catastral NULL' END,
    CASE WHEN s.auto_bool IS NULL THEN 'autoestimacion inválida o NULL' END,
    CASE WHEN s.valor_comercial                  IS NOT NULL AND NOT (s.valor_comercial                  >= 0 AND s.valor_comercial                  <= 999999999999999) THEN 'valor_comercial fuera de rango [0,999999999999999]' END,
    CASE WHEN s.avaluo_catastral                 IS NOT NULL AND NOT (s.avaluo_catastral                 >= 0 AND s.avaluo_catastral                 <= 999999999999999) THEN 'avaluo_catastral fuera de rango [0,999999999999999]' END,
    CASE WHEN s.valor_comercial_terreno          IS NOT NULL AND NOT (s.valor_comercial_terreno          >= 0 AND s.valor_comercial_terreno          <= 999999999999999) THEN 'valor_comercial_terreno fuera de rango [0,999999999999999]' END,
    CASE WHEN s.avaluo_catastral_terreno         IS NOT NULL AND NOT (s.avaluo_catastral_terreno         >= 0 AND s.avaluo_catastral_terreno         <= 999999999999999) THEN 'avaluo_catastral_terreno fuera de rango [0,999999999999999]' END,
    CASE WHEN s.valor_comercial_total_unidadesc  IS NOT NULL AND NOT (s.valor_comercial_total_unidadesc  >= 0 AND s.valor_comercial_total_unidadesc  <= 999999999999999) THEN 'valor_comercial_total_unidadesconstruccion fuera de rango [0,999999999999999]' END,
    CASE WHEN s.avaluo_catastral_total_unidades  IS NOT NULL AND NOT (s.avaluo_catastral_total_unidades  >= 0 AND s.avaluo_catastral_total_unidades  <= 999999999999999) THEN 'avaluo_catastral_total_unidadesconstruccion fuera de rango [0,999999999999999]' END
  ], NULL)::text[] AS causas
FROM tmp_src s;

DROP TABLE IF EXISTS tmp_ok;
CREATE TEMP TABLE tmp_ok AS
SELECT * FROM tmp_val WHERE array_length(causas,1) IS NULL;

DROP TABLE IF EXISTS tmp_bad;
CREATE TEMP TABLE tmp_bad AS
SELECT * FROM tmp_val WHERE array_length(causas,1) IS NOT NULL;

INSERT INTO ladm.ilc_estructuraavaluo (
  t_seq,
  fecha_avaluo_catastral,
  valor_comercial,
  avaluo_catastral,
  valor_comercial_terreno,
  avaluo_catastral_terreno,
  valor_comercial_total_unidadesconstruccion,
  avaluo_catastral_total_unidadesconstruccion,
  autoestimacion,
  ilc_predio_avaluo
)
SELECT
  NULL,
  o.fecha_cat_date,
  o.valor_comercial,
  o.avaluo_catastral,
  o.valor_comercial_terreno,
  o.avaluo_catastral_terreno,
  o.valor_comercial_total_unidadesc,
  o.avaluo_catastral_total_unidades,
  o.auto_bool,
  o.predio_t_id
FROM tmp_ok o;

INSERT INTO preprod.ilc_estructuraavaluo_rechazados (
  id_operacion_predio,
  fecha_avaluo_catastral,
  valor_comercial,
  avaluo_catastral,
  valor_comercial_terreno,
  avaluo_catastral_terreno,
  valor_comercial_total_unidadesc,
  avaluo_catastral_total_unidades,
  autoestimacion_src,
  autoestimacion_bool,
  predio_t_id,
  causas
)
SELECT
  b.id_operacion_predio,
  b.fecha_avaluo_catastral,
  b.valor_comercial,
  b.avaluo_catastral,
  b.valor_comercial_terreno,
  b.avaluo_catastral_terreno,
  b.valor_comercial_total_unidadesc,
  b.avaluo_catastral_total_unidades,
  b.autoestimacion,
  b.auto_bool,
  b.predio_t_id,
  b.causas
FROM tmp_bad b;


/**
 * Migracion tabla ladm.ilc_interesado
 *
 * 
 */

ALTER TABLE ladm.ilc_interesado
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS derecho_guid varchar(38);

TRUNCATE TABLE ladm.ilc_interesado CASCADE;

DROP TABLE IF EXISTS preprod.interesado_no_match;
CREATE TABLE preprod.interesado_no_match (
  objectid text,
  id_operacion_predio text,
  tipo_src text,
  tipo_documento_src text,
  sexo_src text,
  grupo_etnico_src text,
  autorreco_campesino_src text,
  documento_identidad text,
  primer_nombre text,
  segundo_nombre text,
  primer_apellido text,
  segundo_apellido text,
  razon_social text,
  nombre text,
  motivo text
);

WITH
src AS (
  SELECT *
  FROM preprod.ilc_interesado
),

tipo_id AS (
  SELECT s.objectid, d.t_id AS tipo_t_id
  FROM src s
  LEFT JOIN ladm.cr_interesadotipo d ON d.ilicode = s.tipo::text
),
tdoc_id AS (
  SELECT s.objectid, d.t_id AS tipo_documento_t_id
  FROM src s
  LEFT JOIN ladm.cr_documentotipo d ON d.ilicode = s.tipo_documento::text
),

sexo_id AS (
  SELECT s.objectid,
         COALESCE(dom1.t_id, dom2.t_id) AS sexo_t_id
  FROM src s
  LEFT JOIN ladm.cr_sexotipo dom1 ON dom1.ilicode = s.sexo::text
  LEFT JOIN ladm.cr_sexotipo dom2 ON dom2.ilicode = 'Sin_Determinar'
       AND (s.sexo IN ('Indeterminado','No_Clasificable') OR s.sexo IS NULL)
),
grp_norm AS (
  SELECT s.objectid,
         CASE
           WHEN s.grupo_etnico IS NULL THEN 'Sin_Determinar'
           WHEN s.grupo_etnico = 'Etnico_Indigena'             THEN 'Etnico.Indigena'
           WHEN s.grupo_etnico = 'Etnico_Negro_Afrocolombiano' THEN 'Etnico.Negro_Afrocolombiano'
           WHEN s.grupo_etnico = 'Palenquero'                  THEN 'Etnico.Palenquero'
           WHEN s.grupo_etnico = 'Ninguno'                     THEN 'Ninguno'
           WHEN s.grupo_etnico LIKE 'Etnico_%'
                THEN regexp_replace(s.grupo_etnico, '^([^_]+)_', '\1.')
           ELSE s.grupo_etnico
         END AS grp_ilicode
  FROM src s
),
grupo_id AS (
  SELECT g.objectid, d.t_id AS grupo_etnico_t_id
  FROM grp_norm g
  LEFT JOIN ladm.ilc_autorreconocimientoetnicotipo d ON d.ilicode = g.grp_ilicode
),
campesino AS (
  SELECT s.objectid,
         CASE
           WHEN s.autorreco_campesino IS NULL THEN NULL
           WHEN s.autorreco_campesino ~* '^(si|sí|s|y|yes|on|true|t|1)$' THEN TRUE
           WHEN s.autorreco_campesino ~* '^(no|n|off|false|f|0)$'        THEN FALSE
           ELSE NULL
         END AS autor_bool
  FROM src s
),
j AS (
  SELECT
    s.*,
    t.tipo_t_id,
    td.tipo_documento_t_id,
    sx.sexo_t_id,
    ge.grupo_etnico_t_id,
    c.autor_bool
  FROM src s
  LEFT JOIN tipo_id  t  ON t.objectid  = s.objectid
  LEFT JOIN tdoc_id  td ON td.objectid = s.objectid
  LEFT JOIN sexo_id  sx ON sx.objectid = s.objectid
  LEFT JOIN grupo_id ge ON ge.objectid = s.objectid
  LEFT JOIN campesino c ON c.objectid  = s.objectid
),
validos AS (
  SELECT *
  FROM j
  WHERE tipo_t_id IS NOT NULL
    AND tipo_documento_t_id IS NOT NULL
    AND autor_bool IS NOT NULL
    AND documento_identidad IS NOT NULL AND btrim(documento_identidad) <> ''
    AND objectid IS NOT NULL
),
rechazados AS (
  SELECT * ,
         CASE
           WHEN tipo_t_id IS NULL            THEN 'Tipo (NOT NULL) sin match'
           WHEN tipo_documento_t_id IS NULL  THEN 'Tipo documento (NOT NULL) sin match'
           WHEN autor_bool IS NULL           THEN 'Autorreconocimiento campesino (NOT NULL) inválido/NULL'
           WHEN documento_identidad IS NULL OR btrim(documento_identidad) = '' THEN 'Documento identidad (NOT NULL) nulo/vacío'
           WHEN objectid IS NULL             THEN 'local_id (NOT NULL) nulo'
         END AS motivo
  FROM j
  WHERE tipo_t_id IS NULL
     OR tipo_documento_t_id IS NULL
     OR autor_bool IS NULL
     OR documento_identidad IS NULL OR btrim(documento_identidad) = ''
     OR objectid IS NULL
),
ins_bad AS (
  INSERT INTO preprod.interesado_no_match (
    objectid, id_operacion_predio, tipo_src, tipo_documento_src, sexo_src, grupo_etnico_src,
    autorreco_campesino_src, documento_identidad, primer_nombre, segundo_nombre,
    primer_apellido, segundo_apellido, razon_social, nombre, motivo
  )
  SELECT
    r.objectid::text, r.id_operacion_predio, r.tipo, r.tipo_documento, r.sexo, r.grupo_etnico,
    r.autorreco_campesino, r.documento_identidad, r.primer_nombre, r.segundo_nombre,
    r.primer_apellido, r.segundo_apellido, r.razon_social, r.nombre, r.motivo
  FROM rechazados r
  RETURNING 1
),
ins_ok AS (
  INSERT INTO ladm.ilc_interesado (
    tipo, tipo_documento, documento_identidad,
    primer_nombre, segundo_nombre, primer_apellido, segundo_apellido,
    sexo, grupo_etnico, autorreconocimientocampesino,
    razon_social, nombre,
    comienzo_vida_util_version, fin_vida_util_version,
    espacio_de_nombres, local_id,
    id_operacion_predio,
    derecho_guid
  )
  SELECT
    v.tipo_t_id,
    v.tipo_documento_t_id,
    v.documento_identidad,
    v.primer_nombre,
    v.segundo_nombre,
    v.primer_apellido,
    v.segundo_apellido,
    v.sexo_t_id,            
    v.grupo_etnico_t_id,     
    v.autor_bool,
    v.razon_social,
    v.nombre,
    NOW(), NULL,
    'ilc_interesado',
    v.objectid::text,
    v.id_operacion_predio,
    NULLIF(lower(regexp_replace(v.derecho_guid::text, '[{}]', '', 'g')), '')::varchar(38)
  FROM validos v
  RETURNING 1
)
SELECT
  (SELECT COUNT(*) FROM ins_ok)  AS insertados,
  (SELECT COUNT(*) FROM ins_bad) AS rechazados;


/**
 * Migracion agrupación
 *
 * 
 */
drop table if exists preprod.tmp_grupo_interesados cascade;

create table preprod.tmp_grupo_interesados as 
WITH norm AS (
  SELECT
      t.id_operacion_predio,
      lower(regexp_replace(coalesce(t.tipo_documento::text,''), '[^A-Za-z]+', '', 'g')) AS doc_norm
  FROM preprod.t_ilc_interesado t
  WHERE t.id_operacion_predio IS NOT NULL
),
classed AS (
  SELECT
    id_operacion_predio,
    CASE
      WHEN doc_norm = 'nit' THEN 'empresarial'
      WHEN doc_norm IN (
        'cedulaciudadania','secuencial','tarjetaidentidad',
        'registrocivil','pasaporte','cedulaextranjeria','cedulaextrangeria'
      )
        OR doc_norm LIKE 'registroc%'   -- captura "registrocviil" y variantes
      THEN 'civil'
      ELSE 'otro'
    END AS doc_class
  FROM norm
),
agg AS (
  SELECT
    id_operacion_predio,
    bool_or(doc_class = 'civil')        AS has_civil,
    bool_or(doc_class = 'empresarial')  AS has_empresarial,
    count(*)                                            AS interesados_total,
    count(*) FILTER (WHERE doc_class = 'civil')         AS civil_count,
    count(*) FILTER (WHERE doc_class = 'empresarial')   AS empresarial_count,
    count(*) FILTER (WHERE doc_class = 'otro')          AS otros_count
  FROM classed
  GROUP BY id_operacion_predio
  HAVING count(*) > 1                      -- ← solo grupos con más de 1 interesado
)
SELECT
  id_operacion_predio,
  CASE
    WHEN has_civil AND has_empresarial THEN 'Grupo_Mixto'
    WHEN has_empresarial               THEN 'Grupo_Empresarial'
    WHEN has_civil                     THEN 'Grupo_Civil'
    ELSE 'Sin_Clasificar'
  END AS tipo,
  interesados_total,
  civil_count,
  empresarial_count,
  otros_count
FROM agg
ORDER BY id_operacion_predio;
--tabla real
truncate table ladm.cr_agrupacioninteresados cascade;
INSERT INTO ladm.cr_agrupacioninteresados (
  tipo,                      -- FK: ladm.col_grupointeresadotipo.t_id
  nombre,
  comienzo_vida_util_version,
  fin_vida_util_version,
  espacio_de_nombres,
  local_id
)
SELECT
  d.t_id                           AS tipo,
  NULL::varchar                    AS nombre,
  now()                            AS comienzo_vida_util_version,
  NULL::timestamp                  AS fin_vida_util_version,
  'cr_agrupacioninteresados'       AS espacio_de_nombres,
  tgi.id_operacion_predio          AS local_id
FROM preprod.tmp_grupo_interesados AS tgi
JOIN ladm.col_grupointeresadotipo  AS d
  ON d.ilicode = tgi.tipo;         


/**
 * Migracion colmiembros
 *
 * 
 */

INSERT INTO ladm.col_miembros (
  t_id,
  t_ili_tid,
  interesado_ilc_interesado,
  interesado_cr_agrupacioninteresados,
  agrupacion,
  participacion
)
SELECT
  nextval('ladm.t_ili2db_seq')        AS t_id,
  uuid_generate_v4()::text            AS t_ili_tid,
  i.t_id                              AS interesado_ilc_interesado,
  NULL::bigint                        AS interesado_cr_agrupacioninteresados, -- miembro simple
  g.t_id                              AS agrupacion,
  NULL::numeric                       AS participacion                         -- o asigna %
FROM ladm.cr_agrupacioninteresados g
JOIN ladm.ilc_interesado i
  ON i.id_operacion_predio::text = g.local_id::text
LEFT JOIN ladm.col_miembros m
  ON m.interesado_ilc_interesado = i.t_id
 AND m.agrupacion               = g.t_id
WHERE m.interesado_ilc_interesado IS NULL; 


/**
 * Migracion ilc_interesadocontacto
 *
 * 
 */


INSERT INTO ladm.ilc_interesadocontacto (
  t_ili_tid,
  telefono,
  domicilio_notificacion,
  direccion_residencia,
  correo_electronico,
  autoriza_notificacion_correo,
  departamento,
  municipio,
  cr_interesado
)
SELECT
  uuid_generate_v4(),                                              -- t_ili_tid
  NULLIF(regexp_replace(coalesce(src.telefono,''), '\D', '', 'g'),'')::numeric
    AS telefono,                                                   -- limpia y castea a numeric
  src.domicilio_notificacion,                                      -- ajusta/castea si tu destino es boolean
  src.direccion_residencia,
  src.correo_electronico,
  CASE                                                               -- normaliza a boolean si viene como texto/num
    WHEN lower(coalesce(src.autoriza_notificacion_correo::text,'')) IN ('1','t','true','sí','si','s','y','yes') THEN TRUE
    WHEN lower(coalesce(src.autoriza_notificacion_correo::text,'')) IN ('0','f','false','no','n')                 THEN FALSE
    ELSE NULL
  END AS autoriza_notificacion_correo,
  src.departamento,                                                -- si en destino es numérico: usa ::int
  src.municipio,                                                   -- si en destino es numérico: usa ::int
  dest.t_id                                                        -- FK al interesado
FROM preprod.t_ilc_interesado src
JOIN ladm.ilc_interesado dest
  ON dest.local_id::text = src.objectid::text
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_interesadocontacto c
  WHERE c.cr_interesado = dest.t_id
  );

  /**
 * Migracion Derecho
 *
 * 
 */

 ALTER TABLE ladm.ilc_derecho
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS interesado_guid   varchar(38),
  ADD COLUMN IF NOT EXISTS guid_derecho      varchar(38);

INSERT INTO ladm.ilc_derecho (
  t_ili_tid,
  tipo,
  posesion_ancestral_y_o_tradicional,
  fecha_inicio_tenencia,
  descripcion,
  unidad,
  comienzo_vida_util_version,
  fin_vida_util_version,
  espacio_de_nombres,
  local_id,
  id_operacion_predio,
  interesado_guid,
  guid_derecho
)
SELECT
  uuid_generate_v4(),
  cat.t_id,
  CASE
    WHEN lower(coalesce(d.posecion_ancestral_y_o_tradicio::text,'')) IN ('1','t','true','sí','si','s','y','yes') THEN TRUE
    WHEN lower(coalesce(d.posecion_ancestral_y_o_tradicio::text,'')) IN ('0','f','false','no','n')               THEN FALSE
    ELSE FALSE
  END,
  COALESCE(d.fecha_inicio_tenencia, CURRENT_DATE),
  NULL::varchar,
  NULL::bigint,
  now(),
  NULL::timestamp,
  'ilc_derecho',
  d.objectid,
  d.id_operacion_predio,
  lower(regexp_replace(d.interesado_guid::text, '[{}]', '', 'g')) AS interesado_guid,
  lower(regexp_replace(d.globalid::text,        '[{}]', '', 'g')) AS guid_derecho
FROM preprod.t_ilc_derecho d
LEFT JOIN ladm.ilc_derechocatastraltipo cat
  ON cat.ilicode = CASE
                     WHEN lower(trim(d.tipo)) IN ('sin definir','sin_definir') THEN 'Dominio'
                     ELSE d.tipo
                   END
WHERE NOT EXISTS (
  SELECT 1 FROM ladm.ilc_derecho x WHERE x.local_id::text = d.objectid::text
);



/**
 * Migracion col_rrrinteresado
 *
 * 
 */

DROP TABLE IF EXISTS tmp_grp, tmp_i, tmp_d, tmp_j, tmp_rrr_op;

CREATE TEMP TABLE tmp_grp ON COMMIT DROP AS
SELECT btrim(local_id::text) AS id_op, MIN(t_id) AS grp_id
FROM ladm.cr_agrupacioninteresados
GROUP BY 1;
CREATE INDEX ON tmp_grp (id_op);

CREATE TEMP TABLE tmp_i ON COMMIT DROP AS
SELECT
  t_id                             AS interesado_tid,
  btrim(id_operacion_predio::text) AS id_op,
  lower(translate(coalesce(derecho_guid::text,''), '{}','')) AS guid_norm
FROM ladm.ilc_interesado
WHERE id_operacion_predio IS NOT NULL;
CREATE INDEX ON tmp_i (id_op);
CREATE INDEX ON tmp_i (guid_norm);

CREATE TEMP TABLE tmp_d ON COMMIT DROP AS
SELECT
  t_id                             AS rrr_tid,
  btrim(id_operacion_predio::text) AS id_op,
  lower(translate(coalesce(guid_derecho::text,''), '{}','')) AS guid_norm
FROM ladm.ilc_derecho
WHERE id_operacion_predio IS NOT NULL;
CREATE INDEX ON tmp_d (id_op);
CREATE INDEX ON tmp_d (guid_norm);

CREATE TEMP TABLE tmp_j ON COMMIT DROP AS
SELECT
  i.id_op,
  i.interesado_tid,
  d.rrr_tid
FROM tmp_i i
JOIN tmp_d d ON d.guid_norm = i.guid_norm;
CREATE INDEX ON tmp_j (id_op);

CREATE TEMP TABLE tmp_rrr_op ON COMMIT DROP AS
SELECT id_op, MIN(rrr_tid) AS rrr_tid
FROM tmp_j
GROUP BY id_op;
CREATE INDEX ON tmp_rrr_op (id_op);

INSERT INTO ladm.col_rrrinteresado (t_ili_tid, rrr, interesado_ilc_interesado, interesado_cr_agrupacioninteresados)
SELECT uuid_generate_v4()::text, r.rrr_tid, NULL::bigint, g.grp_id
FROM tmp_rrr_op r
JOIN tmp_grp    g USING (id_op)
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.col_rrrinteresado x
  WHERE x.rrr = r.rrr_tid
    AND x.interesado_cr_agrupacioninteresados = g.grp_id
);

INSERT INTO ladm.col_rrrinteresado (t_ili_tid, rrr, interesado_ilc_interesado, interesado_cr_agrupacioninteresados)
SELECT uuid_generate_v4()::text, j.rrr_tid, j.interesado_tid, NULL::bigint
FROM tmp_j j
LEFT JOIN tmp_grp g USING (id_op)
WHERE g.grp_id IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM ladm.col_rrrinteresado x
    WHERE x.rrr = j.rrr_tid
      AND x.interesado_ilc_interesado = j.interesado_tid
  );

/**
 * Migracion extinteresado
 *
 * 
 */

TRUNCATE TABLE ladm.extinteresado CASCADE;
ALTER TABLE ladm.extinteresado
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255);
TRUNCATE TABLE ladm.extinteresado CASCADE;

WITH grupos_unicos AS (
  SELECT
    btrim(local_id::text) AS id_operacion_predio,
    MIN(t_id)             AS grp_id
  FROM ladm.cr_agrupacioninteresados
  GROUP BY 1
)
INSERT INTO ladm.extinteresado (
  nombre,
  documento_escaneado,
  extredserviciosfisica_ext_interesado_administrador_id,
  cr_agrupacionintersdos_ext_pid,
  ilc_interesado_ext_pid,
  id_operacion_predio
)
SELECT
  NULL::varchar  AS nombre,
  NULL::varchar  AS documento_escaneado,
  NULL::bigint   AS extredserviciosfisica_ext_interesado_administrador_id,
  g.grp_id       AS cr_agrupacionintersdos_ext_pid,
  NULL::bigint   AS ilc_interesado_ext_pid,
  g.id_operacion_predio::varchar(255) AS id_operacion_predio
FROM grupos_unicos g
UNION ALL
SELECT
  NULLIF(btrim(i.nombre::text),'') AS nombre,
  NULL::varchar                    AS documento_escaneado,
  NULL::bigint                     AS extredserviciosfisica_ext_interesado_administrador_id,
  NULL::bigint                     AS cr_agrupacionintersdos_ext_pid,
  i.t_id                           AS ilc_interesado_ext_pid,
  btrim(i.id_operacion_predio::text)::varchar(255) AS id_operacion_predio
FROM ladm.ilc_interesado i
LEFT JOIN grupos_unicos g
  ON g.id_operacion_predio = btrim(i.id_operacion_predio::text)
WHERE g.grp_id IS NULL;



/**
 * iilc_fuenteadministrativa
 *
 * 
 */

ALTER TABLE ladm.ilc_fuenteadministrativa
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS derecho_guid uuid;
CREATE INDEX IF NOT EXISTS col_fuenteadm_ilicode_idx
  ON ladm.col_fuenteadministrativatipo (ilicode);
CREATE INDEX IF NOT EXISTS col_estadodisp_ilicode_idx
  ON ladm.col_estadodisponibilidadtipo (ilicode);
CREATE INDEX IF NOT EXISTS ci_formapresent_ilicode_idx
  ON ladm.ci_forma_presentacion_codigo (ilicode);

INSERT INTO ladm.ilc_fuenteadministrativa (
  tipo,                         -- FK -> col_fuenteadministrativatipo.t_id
  ente_emisor,
  observacion,
  numero_fuente,
  estado_disponibilidad,        -- FK -> col_estadodisponibilidadtipo.t_id
  tipo_principal,               -- FK -> ci_forma_presentacion_codigo.t_id
  fecha_documento_fuente,
  espacio_de_nombres,
  local_id,
  id_operacion_predio,
  derecho_guid
)
SELECT
  cft.t_id                                                  AS tipo,
  s.ente_emisor,
  null,
  s.numero_fuente,
  ed.t_id                                                   AS estado_disponibilidad,
  fp.t_id                                                   AS tipo_principal,
  s.fecha_documento_fuente,
  'ilc_fuenteadministrativa'                                AS espacio_de_nombres,
  s.objectid::varchar(255)                                  AS local_id,
  s.id_operacion_predio::varchar(255)                       AS id_operacion_predio,
  NULLIF(s.derecho_guid::text,'')::uuid                     AS derecho_guid
FROM preprod.t_ilc_fuenteadministrativa s
-- estado = 'Disponible'
JOIN ladm.col_estadodisponibilidadtipo ed
  ON ed.ilicode = 'Disponible'
-- forma presentación = 'Documento'
LEFT JOIN ladm.ci_forma_presentacion_codigo fp
  ON fp.ilicode = 'Documento'
-- tipo homologado
LEFT JOIN ladm.col_fuenteadministrativatipo cft
  ON cft.ilicode = COALESCE((
       CASE COALESCE(UPPER(TRIM(s.tipo)), UPPER(TRIM(s.numero_fuente)))
         WHEN 'ESCRITURA'                 THEN 'Documento_Fuente.Escritura_Publica'
         WHEN 'OFICIO'                    THEN 'Documento_Fuente.Acto_Administrativo'
         WHEN 'SENTENCIA'                 THEN 'Documento_Fuente.Sentencia_Judicial'
         WHEN 'RESOLUCION'                THEN 'Documento_Fuente.Acto_Administrativo'
         WHEN 'RESOLUCION ADMINISTRATIVA' THEN 'Documento_Fuente.Acto_Administrativo'
         WHEN 'AUTO'                      THEN 'Fuente_Informativa_Intercultural.Auto'
         WHEN 'CERTIFICADO'               THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'SUCESION'                  THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'DOCUMENTO'                 THEN 'Documento_Fuente.Documento_Privado'
         WHEN 'ACTA'                      THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'DESPACHO COMISORIO'        THEN 'Documento_Fuente.Acto_Administrativo'
         WHEN 'ACTA DE CONCILIACION'      THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'DECLARACIONES'             THEN 'Sin_Documento'
         WHEN 'PARTICION'                 THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'JUICIO DE SUCESION'        THEN 'Documento_Fuente.Sentencia_Judicial'
         WHEN 'JUICIO PERTENENCIA'        THEN 'Documento_Fuente.Sentencia_Judicial'
         WHEN 'PROHIBICION'               THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'PROVIDENCIA'               THEN 'Documento_Fuente.Sentencia_Judicial'
         WHEN 'REMATE'                    THEN 'Documento_Fuente.Sentencia_Judicial'
         WHEN 'SIN INFORMACION'           THEN 'Sin_Documento'
         WHEN 'DILIGENCIA'                THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'EXTRACTO'                  THEN 'Documento_Fuente.Otro_Documento_fuente'
         WHEN 'HOJAS DE CERTIFICADO'      THEN 'Documento_Fuente.Otro_Documento_fuente'
         ELSE 'Sin_Documento'
       END
     ), 'Sin_Documento');


/**
 * col_rrfuente
 *
 * 
 */

WITH f AS (
  SELECT
    t_id               AS fuente_t_id,
    derecho_guid::uuid AS derecho_uuid
  FROM ladm.ilc_fuenteadministrativa
  WHERE derecho_guid IS NOT NULL
),
d AS (
  SELECT
    t_id               AS derecho_t_id,
    guid_derecho::uuid AS derecho_uuid
  FROM ladm.ilc_derecho
  WHERE guid_derecho ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
)
INSERT INTO ladm.col_rrrfuente (
    t_ili_tid,
    fuente_administrativa,
    rrr
)
SELECT
    uuid_generate_v4()           AS t_ili_tid,
    f.fuente_t_id                 AS fuente_administrativa,
    d.derecho_t_id                 AS rrr
FROM f
JOIN d USING (derecho_uuid)
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.col_rrrfuente x
  WHERE x.fuente_administrativa = f.fuente_t_id
    AND x.rrr                   = d.derecho_t_id
);


/**
 * extdireccion
 *
 * 
 */
TRUNCATE TABLE ladm.extdireccion CASCADE;

-- Fuente normalizada
DROP TABLE IF EXISTS tmp_extdir_src;
CREATE UNLOGGED TABLE tmp_extdir_src AS
SELECT
  p.*,
  btrim(p.id_operacion_predio::text) AS id_op_norm,
  CASE 
    WHEN upper(trim(p.es_direccion_principal)) IN ('SI','S','TRUE','T','1') THEN TRUE
    WHEN upper(trim(p.es_direccion_principal)) IN ('NO','N','FALSE','F','0') THEN FALSE
    ELSE NULL
  END AS es_principal_bool,
  CASE
    WHEN p.localizacion IS NULL OR trim(p.localizacion) = '' THEN NULL
    WHEN p.localizacion ~* '^\s*POINT(\s+Z(M)?|\s*)\s*\('
      THEN ST_SetSRID(ST_Force3D(ST_GeomFromText(trim(p.localizacion))), 9377)
    ELSE NULL
  END AS geom_wkt
FROM preprod.t_extdireccion p;

CREATE INDEX tmp_extdir_src_idop_idx ON tmp_extdir_src (id_op_norm);
ANALYZE tmp_extdir_src;

-- Mapas por id_operacion_predio
DROP TABLE IF EXISTS map_ei;
CREATE UNLOGGED TABLE map_ei AS
SELECT btrim(id_operacion_predio::text) AS id_op_norm, MIN(t_id) AS t_id
FROM ladm.extinteresado
GROUP BY 1;
CREATE INDEX map_ei_idop_idx ON map_ei (id_op_norm);
ANALYZE map_ei;

DROP TABLE IF EXISTS map_t;
CREATE UNLOGGED TABLE map_t AS
SELECT btrim(cod_match::text) AS id_op_norm, MIN(t_id) AS t_id
FROM ladm.cr_terreno
GROUP BY 1;
CREATE INDEX map_t_idop_idx ON map_t (id_op_norm);
ANALYZE map_t;

-- UC: enlazamos por (local_id ↔ objectid) y/o por (id_predio ↔ ilc_predio.t_id)
DROP TABLE IF EXISTS map_uc;
CREATE UNLOGGED TABLE map_uc AS
WITH src_link AS (
  SELECT btrim(src.id_operacion_predio::text) AS id_op_norm, uc.t_id
  FROM ladm.cr_unidadconstruccion uc
  JOIN preprod.t_cr_unidadconstruccion src
    ON src.objectid::text = uc.local_id::text
  WHERE src.id_operacion_predio IS NOT NULL
),
predio_link AS (
  SELECT btrim(p.id_operacion_predio::text) AS id_op_norm, uc.t_id
  FROM ladm.cr_unidadconstruccion uc
  JOIN ladm.ilc_predio p
    ON p.t_id::text = uc.id_predio::text   -- << evita BIGINT vs VARCHAR
  WHERE p.id_operacion_predio IS NOT NULL
),
all_uc AS (
  SELECT * FROM src_link
  UNION ALL
  SELECT * FROM predio_link
)
SELECT id_op_norm, MIN(t_id) AS t_id
FROM all_uc
GROUP BY id_op_norm;
CREATE INDEX map_uc_idop_idx ON map_uc (id_op_norm);
ANALYZE map_uc;

DROP TABLE IF EXISTS map_pr;
CREATE UNLOGGED TABLE map_pr AS
SELECT btrim(id_operacion_predio::text) AS id_op_norm, MIN(t_id) AS t_id
FROM ladm.ilc_predio
GROUP BY 1;
CREATE INDEX map_pr_idop_idx ON map_pr (id_op_norm);
ANALYZE map_pr;

-- Carga final
INSERT INTO ladm.extdireccion (
  tipo_direccion,
  es_direccion_principal,
  localizacion,
  codigo_postal,
  clase_via_principal,
  valor_via_principal,
  letra_via_principal,
  letra_via_generadora,
  sector_ciudad,
  valor_via_generadora,
  numero_predio,
  sector_predio,
  complemento,
  nombre_predio,
  extunidadedificcnfsica_ext_direccion_id,
  extinteresado_ext_direccion_id,
  cr_terreno_ext_direccion_id,
  cr_unidadconstruccion_ext_direccion_id,
  ilc_predio_direccion
)
SELECT
  td.t_id,
  s.es_principal_bool,
  s.geom_wkt,
  s.codigo_postal,
  cv.t_id,
  s.valor_via_principal,
  s.letra_via_principal,
  s.letra_via_generadora,
  sc.t_id,
  s.valor_via_generadora,
  s.numero_predio,
  sp.t_id,
  s.complemento,
  s.nombre_predio,
  NULL::bigint,
  ei.t_id,
  t.t_id,
  uc.t_id,
  pr.t_id
FROM tmp_extdir_src s
JOIN ladm.extdireccion_tipo_direccion td
  ON td.ilicode = s.tipo_direccion::text
LEFT JOIN ladm.extdireccion_clase_via_principal cv
  ON cv.ilicode = s.clase_via_principal::text
LEFT JOIN ladm.extdireccion_sector_ciudad sc
  ON sc.ilicode = s.sector_ciudad::text
LEFT JOIN ladm.extdireccion_sector_predio sp
  ON sp.ilicode = s.sector_predio::text
LEFT JOIN map_ei ei ON ei.id_op_norm = s.id_op_norm
LEFT JOIN map_t  t  ON t.id_op_norm  = s.id_op_norm
LEFT JOIN map_uc uc ON uc.id_op_norm = s.id_op_norm
LEFT JOIN map_pr pr ON pr.id_op_norm = s.id_op_norm;

-- Limpieza
DROP TABLE IF EXISTS tmp_extdir_src;
DROP TABLE IF EXISTS map_ei;
DROP TABLE IF EXISTS map_t;
DROP TABLE IF EXISTS map_uc;
DROP TABLE IF EXISTS map_pr;



AHOR APARA SOGAMOSO 



/**
 * Migración tabla predio (solo NPN que inician por 15759)
 */

ALTER TABLE ladm.ilc_predio
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255);

TRUNCATE TABLE ladm.ilc_predio CASCADE;

DROP TABLE IF EXISTS tmp_predio_raw;
CREATE TEMP TABLE tmp_predio_raw AS
SELECT
  p.*,
  TRIM(p.tipo) AS tipo_trim,
  TRIM(p.condicion_predio) AS condicion_trim,
  TRIM(p.destinacion_economica) AS destinacion_trim,
  TRIM(p.numero_predial_nacional) AS numero_predial_nacional_clean,
  TRIM(p.matricula_inmobiliaria) AS matricula_clean,
  -- homologaciones tipo
  CASE
    WHEN TRIM(p.tipo) = 'Privado' THEN 'Predio.Privado.Privado'
    WHEN TRIM(p.tipo) = 'Publico_Baldio' THEN 'Predio.Publico.Baldio.Baldio'
    WHEN TRIM(p.tipo) = 'Publico_Fiscal_Patrimonial' THEN 'Predio.Publico.Fiscal_Patrimonial'
    WHEN TRIM(p.tipo) = 'Predio.Privado.Privado' THEN 'Predio.Privado.Privado'
    WHEN TRIM(LOWER(p.tipo)) IN ('particular', 'privado') THEN 'Predio.Privado.Privado'
    ELSE NULL
  END AS tipo_homologado,
  -- homologaciones condición
  CASE
    WHEN TRIM(p.condicion_predio) = 'Condominio_Unidad_Predial' THEN 'Condominio.Unidad_Predial'
    WHEN TRIM(p.condicion_predio) = 'Informal' THEN 'Informal'
    WHEN TRIM(p.condicion_predio) = 'Mejoras_Terreno_Ajeno_No_PH' THEN 'Informal'
    WHEN TRIM(p.condicion_predio) = 'NPH' THEN 'NPH'
    WHEN TRIM(p.condicion_predio) = 'PH_Unidad_Predial' THEN 'PH.Unidad_Predial'
    WHEN TRIM(p.condicion_predio) = 'Bien_Uso_Publico' THEN 'Bien_Uso_Publico'
    ELSE NULL
  END AS condicion_homologada,
  -- homologaciones destinación
  CASE
    WHEN TRIM(p.destinacion_economica) = 'Lote_Urbanizable_No_Construido' THEN 'Lote_Urbanizado_No_Construido'
    WHEN TRIM(p.destinacion_economica) = 'Servicios_Especiales' THEN NULL
    ELSE TRIM(p.destinacion_economica)
  END AS destinacion_homologada,
  -- código municipio
  CASE 
    WHEN LEFT(TRIM(p.numero_predial_nacional), 5) ~ '^[0-9]+$' 
      THEN LEFT(TRIM(p.numero_predial_nacional), 5)::INTEGER
    ELSE NULL
  END AS mp_codigo,
  -- validaciones
  (TRIM(p.matricula_inmobiliaria) ~ '^[0-9]+$'
    AND LENGTH(TRIM(p.matricula_inmobiliaria)) <= 10
    AND TRIM(p.matricula_inmobiliaria)::BIGINT BETWEEN 1 AND 2147483647
  ) AS matricula_valida,
  (LEFT(TRIM(p.numero_predial_nacional),5) ~ '^[0-9]+$') AS codigo_municipio_valido,
  (LENGTH(TRIM(p.numero_predial_nacional)) = 30) AS numero_predial_largo_valido
FROM preprod.t_ilc_predio p
WHERE TRIM(p.numero_predial_nacional) LIKE '15759%';  -- <== Filtro NPN

-- Índices para acelerar joins
CREATE INDEX IF NOT EXISTS idx_tmp_predio_mp_codigo ON tmp_predio_raw (mp_codigo);
CREATE INDEX IF NOT EXISTS idx_tmp_predio_codigo_orip ON tmp_predio_raw (codigo_orip);
CREATE INDEX IF NOT EXISTS idx_tmp_predio_num_predial_clean ON tmp_predio_raw (numero_predial_nacional_clean);

-- INSERT principal (solo predios filtrados por 15759 desde la tmp)
INSERT INTO ladm.ilc_predio (
    t_ili_tid,
    departamento,
    municipio,
    codigo_orip,
    matricula_inmobiliaria,
    area_catastral_terreno,
    numero_predial_nacional,
    tipo,
    condicion_predio,
    destinacion_economica,
    area_registral_m2,
    nombre,
    comienzo_vida_util_version,
    fin_vida_util_version,
    espacio_de_nombres,
    id_operacion_predio,
    local_id
)
SELECT 
    uuid_generate_v4(),
    LEFT(m.mpcodigo::TEXT, 2),
    RIGHT(m.mpcodigo::TEXT, 3),
    p.codigo_orip,
    CASE 
      WHEN p.matricula_valida THEN p.matricula_clean::INTEGER
      ELSE NULL
    END,
    p.area_catastral_terreno,
    p.numero_predial_nacional_clean,
    pt.t_id,
    ct.t_id,
    det.t_id,
    p.area_registral_m2,
    NULL,
    NOW(),
    NULL,
    'ilc_predio',
    p.id_operacion,
    p.objectid
FROM tmp_predio_raw p
JOIN ladm.ilc_prediotipo pt 
  ON pt.ilicode = COALESCE(p.tipo_homologado, p.tipo_trim)
JOIN ladm.ilc_condicionprediotipo ct 
  ON ct.ilicode = COALESCE(p.condicion_homologada, p.condicion_trim)
JOIN ladm.ilc_destinacioneconomicatipo det 
  ON det.ilicode = COALESCE(p.destinacion_homologada, p.destinacion_trim)
JOIN preprod.municipios m 
  ON m.mpcodigo = p.mp_codigo
WHERE 
    p.mp_codigo IS NOT NULL
    AND p.area_catastral_terreno IS NOT NULL
    AND p.numero_predial_largo_valido
    AND p.matricula_valida;

-- Rechazados (solo dentro del universo 15759, porque parte de tmp_predio_raw)
DROP TABLE IF EXISTS preprod.t_predios_rechazados;

CREATE TABLE preprod.t_predios_rechazados AS
WITH con_municipios AS (
  SELECT 
    ph.*,
    m.mpcodigo IS NOT NULL AS municipio_encontrado
  FROM tmp_predio_raw ph
  LEFT JOIN preprod.municipios m ON m.mpcodigo = ph.mp_codigo
),
rechazados AS (
  SELECT *,
    array_remove(array[
      CASE WHEN tipo_homologado IS NULL THEN 'tipo no homologado' ELSE NULL END,
      CASE WHEN condicion_homologada IS NULL THEN 'condición no homologada' ELSE NULL END,
      CASE WHEN destinacion_homologada IS NULL THEN 'destinación no homologada' ELSE NULL END,
      CASE WHEN mp_codigo IS NULL THEN 'código municipal no válido' ELSE NULL END,
      CASE WHEN municipio_encontrado = FALSE THEN 'municipio no encontrado' ELSE NULL END,
      CASE WHEN area_catastral_terreno IS NULL THEN 'área catastral nula' ELSE NULL END,
      CASE WHEN NOT numero_predial_largo_valido THEN 'número predial no tiene 30 dígitos' ELSE NULL END,
      CASE WHEN NOT matricula_valida THEN 'matrícula inmobiliaria inválida' ELSE NULL END
    ], NULL) AS causas
  FROM con_municipios
)
SELECT 
  r.objectid,
  r.codigo_orip,
  r.matricula_clean AS matricula_inmobiliaria,
  r.area_catastral_terreno,
  r.numero_predial_nacional_clean AS numero_predial_nacional,
  r.tipo,
  r.condicion_predio,
  r.destinacion_economica,
  r.area_registral_m2,
  r.tipo_homologado,
  r.condicion_homologada,
  r.destinacion_homologada,
  r.mp_codigo,
  r.municipio_encontrado,
  array_to_string(r.causas, ', ') AS detalle
FROM rechazados r
WHERE array_length(causas, 1) > 0;

---- Terreno

ALTER TABLE ladm.cr_terreno
ADD COLUMN IF NOT EXISTS cod_match varchar(255);
INSERT INTO ladm.cr_terreno ( t_ili_tid, geometria, dimension, etiqueta, relacion_superficie, comienzo_vida_util_version, fin_vida_util_version, espacio_de_nombres, local_id, cod_match ) SELECT uuid_generate_v4() AS t_ili_tid, ST_Force3D(ST_Multi(shape)) AS geometria, (SELECT t_id FROM ladm.col_dimensiontipo WHERE ilicode = 'Dim2D') AS dimension, etiqueta, (SELECT t_id FROM ladm.col_relacionsuperficietipo WHERE ilicode = 'En_Rasante') AS relacion_superficie, NOW() AS comienzo_vida_util_version, NULL::timestamp AS fin_vida_util_version, 'cr_terreno' AS espacio_de_nombres, objectid::varchar AS local_id, id_operacion_predio AS cod_match FROM preprod.cr_terreno;

---DELETE FROM ladm.cr_terreno t
WHERE NOT EXISTS (
    SELECT 1
    FROM ladm.ilc_predio p
    WHERE p.id_operacion_predio::text = t.cod_match::text
);


--- caracteristicas


/**
 * 
 * Migracion tabla ilc_caracteristicasunidadconstruccion
 * 
 */
ALTER TABLE ladm.ilc_caracteristicasunidadconstruccion
  ADD COLUMN IF NOT EXISTS id_empate varchar(255);
CREATE INDEX IF NOT EXISTS ilc_caract_uc_idx_idempate
  ON ladm.ilc_caracteristicasunidadconstruccion (id_empate);
TRUNCATE TABLE ladm.ilc_caracteristicasunidadconstruccion CASCADE;
TRUNCATE TABLE preprod.t_caracteristicas_rechazadas RESTART IDENTITY;
DROP TABLE IF EXISTS tmp_uso_map_id;
WITH fix AS (
  SELECT * FROM (VALUES
    ('Anexo_Cocheras_Banieras_Porquerizas','Anexo.Cocheras_Marraneras_Porquerizas'),
    ('Institucional_Puesto_De_Salud','Institucional.Puestos_de_Salud'),
    ('Comercial_Teatro_Cinema_En_PH','Comercial.Teatro_Cinemas_en_PH'),
    ('Comercial_Pensiones_Residencias','Comercial.Pensiones_y_Residencias'),
    ('Institucional_Bibliotecas','Institucional.Biblioteca'),
    ('Residencial_Apartamentos_4_y_mas_Pisos_en_PH','Residencial.Apartamentos_4_y_mas_pisos_en_PH'),
    ('Residencial_Apartamentos_Mas_De_4_Pisos','Residencial.Apartamentos_4_y_mas_pisos'),
    ('Residencial_Vivienda_Hasta_3_Pisos_En_PH','Residencial.Vivienda_Hasta_3_Pisos_En_PH'),
    ('Residencial_Vivienda_Recreacional_En_PH','Residencial.Vivienda_Recreacional'),
    ('Comercial_Restaurante_En_PH','Comercial.Restaurantes_en_PH'),
    ('Residencial_Garajes_En_PH','Residencial.Garajes_En_PH'),
    ('Industrial_Industria_En_PH','Industrial.Industrias_en_PH'),
    ('Sin_Definir', NULL)
  ) AS v(uso_raw, uso_fix)
),
uso_map AS (
  SELECT
    u.uso_raw,
    COALESCE(
      f.uso_fix,
      REGEXP_REPLACE(REPLACE(REPLACE(u.uso_raw,'_De_','_de_'),'_En_','_en_'), '^([^_]+)_','\1.')
    ) AS uso_norm
  FROM (SELECT DISTINCT uso AS uso_raw FROM preprod.t_ilc_caracteristicasunidadconstruccion) u
  LEFT JOIN fix f USING (uso_raw)
)
SELECT
  um.uso_raw,
  COALESCE(c_exact.t_id, c_norm.t_id) AS uso_t_id
INTO TEMP TABLE tmp_uso_map_id
FROM uso_map um
LEFT JOIN ladm.cr_usouconstipo c_exact ON c_exact.ilicode = um.uso_raw
LEFT JOIN ladm.cr_usouconstipo c_norm  ON c_norm.ilicode  = um.uso_norm;

-- 3) Un (1) registro por objectid
DROP TABLE IF EXISTS tmp_caracteristicas_unicas;
CREATE TEMP TABLE tmp_caracteristicas_unicas AS
SELECT *
FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY t.objectid ORDER BY t.id_caracteristicas_unidad_cons) AS rn
  FROM preprod.t_ilc_caracteristicasunidadconstruccion t
) x
WHERE rn = 1;

-- 4) Un (1) UC por id_caracteristicasunidadconstru
DROP TABLE IF EXISTS tmp_uc_unica;
CREATE TEMP TABLE tmp_uc_unica AS
SELECT *
FROM (
  SELECT cu.*,
         ROW_NUMBER() OVER (PARTITION BY cu.id_caracteristicasunidadconstru ORDER BY cu.objectid) AS rn
  FROM preprod.t_cr_unidadconstruccion cu
) y
WHERE rn = 1;


DROP TABLE IF EXISTS tmp_base;
CREATE TEMP TABLE tmp_base AS
SELECT
  icuc.*,
  ucu.objectid              AS uc_objectid,
  ucu.etiqueta,
  ucu.anio_construccion,
  ucu.area_construccion,
  ucu.area_privada_construida,
  dut.t_id                  AS tipo_uc_t_id,
  umi.uso_t_id              AS uso_uc_t_id,
  icuc.objectid             AS local_id
FROM tmp_caracteristicas_unicas icuc
LEFT JOIN tmp_uc_unica ucu
       ON ucu.id_caracteristicasunidadconstru = icuc.id_caracteristicas_unidad_cons
LEFT JOIN ladm.cr_unidadconstrucciontipo dut
       ON dut.ilicode = icuc.tipo_unidad_construccion
LEFT JOIN tmp_uso_map_id umi
       ON umi.uso_raw = icuc.uso;

-- Etiquetado 
DROP TABLE IF EXISTS tmp_etiquetado;
CREATE TEMP TABLE tmp_etiquetado AS
SELECT
  b.*,
  (
    tipo_uc_t_id IS NOT NULL
    AND uso_uc_t_id  IS NOT NULL
    AND anio_construccion IS NOT NULL
    AND anio_construccion BETWEEN 1512 AND 2500
    AND area_construccion IS NOT NULL
    AND area_construccion BETWEEN 0 AND 99999999999999.9
    AND total_plantas IS NOT NULL
    AND total_plantas BETWEEN 0 AND 150
  ) AS es_valido
FROM tmp_base b;

--INSERT válidos 
INSERT INTO ladm.ilc_caracteristicasunidadconstruccion (
  t_ili_tid, identificador, tipo_unidad_construccion,
  total_plantas, uso, anio_construccion,
  area_construida, area_privada_construida, observaciones,
  usos_tradicionales_culturales,
  comienzo_vida_util_version, fin_vida_util_version,
  espacio_de_nombres, local_id, id_empate
)
SELECT DISTINCT ON (e.local_id)
  uuid_generate_v4(),
  CASE WHEN length(e.etiqueta) > 20 THEN left(e.etiqueta,20) ELSE e.etiqueta END,
  e.tipo_uc_t_id,
  e.total_plantas,
  e.uso_uc_t_id,
  e.anio_construccion,
  e.area_construccion,
  e.area_privada_construida,
  e.observaciones,
  NULLIF(REGEXP_REPLACE(e.usos_tradicionales_culturales,'\D','','g'),'')::bigint,
  NOW(),
  'infinity'::timestamp,
  'ilc_caracteristicasunidadconstruccion',
  e.local_id,
  e.id_caracteristicas_unidad_cons
FROM tmp_etiquetado e
WHERE e.es_valido
ORDER BY e.local_id, e.id_caracteristicas_unidad_cons;

--  Rechazados 
WITH rej AS (
  SELECT DISTINCT ON (e.local_id)
    e.local_id,
    e.id_caracteristicas_unidad_cons,
    e.tipo_uc_t_id,
    e.total_plantas,
    e.uso,
    e.usos_tradicionales_culturales,
    e.etiqueta,
    e.anio_construccion,
    e.area_construccion,
    e.area_privada_construida,
    ARRAY_REMOVE(ARRAY[
      CASE WHEN e.tipo_uc_t_id IS NULL                               THEN 'tipo UC no encontrado' END,
      CASE WHEN e.uso_uc_t_id  IS NULL                               THEN 'uso no encontrado' END,
      CASE WHEN e.anio_construccion IS NULL                          THEN 'año construcción nulo' END,
      CASE WHEN e.anio_construccion IS NOT NULL
           AND e.anio_construccion NOT BETWEEN 1512 AND 2500          THEN 'año construcción inválido' END,
      CASE WHEN e.area_construccion IS NULL                          THEN 'área construcción nula' END,
      CASE WHEN e.area_construccion IS NOT NULL
           AND e.area_construccion NOT BETWEEN 0 AND 99999999999999.9 THEN 'área construcción inválida' END,
      CASE WHEN e.total_plantas IS NULL                              THEN 'total plantas nulo' END,
      CASE WHEN e.total_plantas IS NOT NULL
           AND e.total_plantas NOT BETWEEN 0 AND 150                  THEN 'total plantas inválido' END,
      CASE WHEN e.uc_objectid IS NULL                                THEN 'unidad construcción no encontrada' END
    ], NULL)::text[] AS causas_rechazo
  FROM tmp_etiquetado e
  WHERE NOT e.es_valido
  ORDER BY e.local_id, e.id_caracteristicas_unidad_cons
)
INSERT INTO preprod.t_caracteristicas_rechazadas (
  local_id,
  id_caracteristicas_unidad_cons,
  tipo_unidad_construccion,
  total_plantas,
  uso,
  usos_tradicionales_culturales,
  identificador,
  anio_construccion,
  area_construccion,
  area_privada_construida,
  causas_rechazo
)
SELECT
  rej.local_id,
  rej.id_caracteristicas_unidad_cons,   -- ← aquí estaba el typo
  rej.tipo_uc_t_id,
  rej.total_plantas,
  rej.uso,
  rej.usos_tradicionales_culturales,
  COALESCE(rej.etiqueta, rej.id_caracteristicas_unidad_cons::text),
  rej.anio_construccion,
  rej.area_construccion,
  rej.area_privada_construida,
  rej.causas_rechazo
FROM rej;

UPDATE ladm.ilc_caracteristicasunidadconstruccion
SET comienzo_vida_util_version = NOW(),
    fin_vida_util_version = NULL;



  -- unidad


-- 1) Nueva columna 3D
ALTER TABLE preprod.t_cr_unidadconstruccion
  ADD COLUMN IF NOT EXISTS shape_mpz public.geometry(MultiPolygonZ, 9377);
UPDATE preprod.t_cr_unidadconstruccion
SET shape_mpz = CASE
  WHEN shape IS NULL OR ST_IsEmpty(shape) THEN NULL
  ELSE (
    ST_Force3DZ(
      ST_Multi(
        ST_CollectionExtract(
          ST_MakeValid(
            CASE
              WHEN COALESCE(ST_SRID(shape),0) IN (0, 9377) THEN ST_SetSRID(shape, 9377)
              WHEN ST_SRID(shape) = 9377 THEN shape
              ELSE ST_Transform(shape, 9377)
            END
          ), 3
        )
      )
    )
  )::public.geometry(MultiPolygonZ, 9377)
END;

BEGIN;

-- Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Columnas nuevas en destino
ALTER TABLE ladm.cr_unidadconstruccion
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS id_predio bigint;

-- Asegura tipo EXACTO: public.geometry(MultiPolygonZ, 9377)
ALTER TABLE ladm.cr_unidadconstruccion
  ALTER COLUMN geometria TYPE public.geometry(MultiPolygonZ, 9377)
  USING (
    CASE
      WHEN geometria IS NULL THEN NULL
      ELSE
        ST_Force3DZ(
          ST_Multi(
            ST_CollectionExtract(ST_SetSRID(geometria, 9377), 3)
          )
        )::public.geometry(MultiPolygonZ, 9377)
    END
  );

-- (Opcional pero recomendado) FK al predio; NOT VALID para no bloquear la carga
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'cr_uc_predio_fk'
  ) THEN
    ALTER TABLE ladm.cr_unidadconstruccion
      ADD CONSTRAINT cr_uc_predio_fk
      FOREIGN KEY (id_predio) REFERENCES ladm.ilc_predio(t_id) NOT VALID;
  END IF;
END$$;

-- Índices útiles
CREATE INDEX IF NOT EXISTS cruc_src_idop_idx
  ON preprod.t_cr_unidadconstruccion (id_operacion_predio);
CREATE INDEX IF NOT EXISTS ilc_predio_idop_idx
  ON ladm.ilc_predio (id_operacion_predio);
CREATE INDEX IF NOT EXISTS cr_uc_geom_gist
  ON ladm.cr_unidadconstruccion USING GIST (geometria);

-- Limpiar destino
TRUNCATE TABLE ladm.cr_unidadconstruccion CASCADE;

WITH
dim2d   AS (
  SELECT t_id FROM ladm.col_dimensiontipo
  WHERE ilicode = 'Dim2D' LIMIT 1
),
rasante AS (
  SELECT t_id FROM ladm.col_relacionsuperficietipo
  WHERE ilicode = 'En_Rasante' LIMIT 1
),

-- Mapa id_operacion_predio -> t_id (predio) determinístico
predio_map AS (
  SELECT btrim(id_operacion_predio::text) AS id_op,
         MIN(t_id) AS predio_t_id
  FROM ladm.ilc_predio
  GROUP BY 1
),

caract_map AS (
  SELECT id_empate, MIN(t_id) AS caract_t_id
  FROM   ladm.ilc_caracteristicasunidadconstruccion
  GROUP  BY id_empate
),

planta_map AS (
  SELECT ilicode::text AS planta_key, MIN(t_id) AS planta_t_id
  FROM   ladm.cr_construccionplantatipo
  GROUP  BY ilicode
),

base AS (
  SELECT
      src.objectid,
      src.id_caracteristicasunidadconstru,
      src.tipo_planta,
      src.planta_ubicacion,
      src.altura,
      src.shape,
      src.etiqueta,
      btrim(src.id_operacion_predio::text) AS id_operacion_predio,
      pm.predio_t_id                         AS id_predio,
      cm.caract_t_id,
      pl.planta_t_id,
      (SELECT t_id FROM dim2d)   AS dim2d_t_id,
      (SELECT t_id FROM rasante) AS rasante_t_id,

      -- Geometría: forzar MultiPolygonZ 9377. este lo hice antes d eactualizar
      CASE
        WHEN src.shape IS NULL OR ST_IsEmpty(src.shape) THEN NULL
        WHEN NOT ST_IsValid(ST_SetSRID(src.shape, 9377)) THEN NULL
        ELSE (
          ST_Force3DZ(
            ST_Multi(
              ST_CollectionExtract(ST_SetSRID(src.shape, 9377), 3)
            )
          )::public.geometry(MultiPolygonZ, 9377)
        )
      END AS geom_mpz
  FROM preprod.t_cr_unidadconstruccion src
  LEFT JOIN predio_map  pm ON pm.id_op     = btrim(src.id_operacion_predio::text)
  LEFT JOIN caract_map  cm ON cm.id_empate = src.id_caracteristicasunidadconstru
  LEFT JOIN planta_map  pl ON pl.planta_key = src.tipo_planta::text
),


empatados AS (
  SELECT * FROM base
  WHERE geom_mpz    IS NOT NULL
    AND caract_t_id IS NOT NULL
    AND planta_t_id IS NOT NULL
),

ins_valid AS (
  INSERT INTO ladm.cr_unidadconstruccion (
      t_ili_tid,
      tipo_planta,
      planta_ubicacion,
      altura,
      geometria,                               -- geometry(MultiPolygonZ,9377)
      cr_caracteristicasunidadconstruccion,
      dimension,
      etiqueta,
      relacion_superficie,
      comienzo_vida_util_version,
      fin_vida_util_version,
      espacio_de_nombres,
      local_id,
      id_operacion_predio,
      id_predio
  )
  SELECT
      uuid_generate_v4(),
      e.planta_t_id,
      e.planta_ubicacion,
      e.altura,
      e.geom_mpz,
      e.caract_t_id,
      e.dim2d_t_id,
      e.etiqueta,
      e.rasante_t_id,
      NOW(),
      NULL::timestamp,
      'cr_unidadconstruccion',
      e.objectid,
      e.id_operacion_predio,
      e.id_predio
  FROM empatados e
  RETURNING 1
),


no_empatan AS (
  SELECT
      b.objectid,
      b.id_caracteristicasunidadconstru,
      b.tipo_planta,
      b.planta_ubicacion,
      b.altura,
      b.shape,
      b.etiqueta,
      b.id_operacion_predio,
      CASE
        WHEN b.shape IS NULL OR ST_IsEmpty(b.shape) THEN 'shape nulo o vacío'
        WHEN NOT ST_IsValid(ST_SetSRID(b.shape, 9377)) THEN 'geometría inválida (ST_IsValid=FALSE)'
        WHEN b.caract_t_id IS NULL AND b.planta_t_id IS NULL THEN 'id_empate y tipo_planta no encontrados'
        WHEN b.caract_t_id IS NULL THEN 'id_empate no encontrado'
        WHEN b.planta_t_id IS NULL THEN 'tipo_planta no encontrado'
        ELSE 'no convertible a MultiPolygonZ'
      END AS causa
  FROM base b
  WHERE geom_mpz    IS NULL
     OR caract_t_id IS NULL
     OR planta_t_id IS NULL
)

INSERT INTO preprod.t_cr_unidadconstruccion_no_empate (
    objectid,
    id_caracteristicasunidadconstru,
    tipo_planta,
    planta_ubicacion,
    altura,
    shape,
    etiqueta,
    id_operacion_predio,
    causa
)
SELECT
    n.objectid,
    n.id_caracteristicasunidadconstru,
    n.tipo_planta,
    n.planta_ubicacion,
    n.altura,
    n.shape,
    n.etiqueta,
    n.id_operacion_predio,
    n.causa
FROM no_empatan n;

COMMIT;


----caractyeristicas 

BEGIN;

CREATE INDEX IF NOT EXISTS ilc_caract_tid_idx
  ON ladm.ilc_caracteristicasunidadconstruccion (t_id);
CREATE INDEX IF NOT EXISTS cr_uc_caract_txt_idx
  ON ladm.cr_unidadconstruccion ((btrim(cr_caracteristicasunidadconstruccion::text)));

CREATE TEMP TABLE _caract_ref AS
SELECT DISTINCT (btrim(uc.cr_caracteristicasunidadconstruccion::text))::bigint AS ref_tid
FROM ladm.cr_unidadconstruccion uc
WHERE uc.cr_caracteristicasunidadconstruccion IS NOT NULL
  AND btrim(uc.cr_caracteristicasunidadconstruccion::text) ~ '^[0-9]+$';

CREATE TEMP TABLE _caract_orphans AS
SELECT c.t_id
FROM ladm.ilc_caracteristicasunidadconstruccion c
LEFT JOIN _caract_ref r ON r.ref_tid = c.t_id
WHERE r.ref_tid IS NULL;

SELECT COUNT(*) AS total_a_borrar FROM _caract_orphans;


DELETE FROM ladm.ilc_caracteristicasunidadconstruccion c
USING _caract_orphans o
WHERE c.t_id = o.t_id;

COMMIT;


--datosadicionales

INSERT INTO ladm.ilc_datosadicionaleslevantamientocatastral (
    t_ili_tid,
    observaciones,
    fecha_visita_predial,
    resultado_visita,
    comodato,
    beneficio_comunidades_indigenas,
    ilc_predio
)
SELECT
    uuid_generate_v4() AS t_ili_tid,
    NULL AS observaciones,
    NULL AS fecha_visita_predial,
    rv.t_id AS resultado_visita,   -- "Exitoso" desde catálogo
    FALSE AS comodato,
    FALSE AS beneficio_comunidades_indigenas,
    p.t_id AS ilc_predio
FROM ladm.ilc_predio p
JOIN ladm.ilc_resultadovisitatipo rv
    ON rv.ilicode = 'Exitoso'
WHERE NOT EXISTS (
    SELECT 1
    FROM ladm.ilc_datosadicionaleslevantamientocatastral d
    WHERE d.ilc_predio = p.t_id
);

--cosas de unidad de construcción

/**
 * Migracion tabla ladm.cuc_tipologiaconstruccion
 *
 * 
 */

ALTER TABLE ladm.cuc_tipologiaconstruccion 
  ADD COLUMN IF NOT EXISTS id_match bigint;

TRUNCATE TABLE ladm.cuc_tipologiaconstruccion CASCADE;
DROP TABLE IF EXISTS tmp_tipologia_map;
DROP TABLE IF EXISTS tmp_tipologia_no_hom;

CREATE TEMP TABLE tmp_tipologia_map AS
SELECT
  t.*,
  t.objectid AS id_match,
  CASE
    WHEN t.tipo_tipologia LIKE 'Institucional_Tipo_%'      
      THEN 'Institucional.' || t.tipo_tipologia
    WHEN t.tipo_tipologia LIKE 'Institucional_Religioso_%' 
      THEN 'Institucional.' || regexp_replace(t.tipo_tipologia, '^Institucional_Religioso_', 'Religioso_')
    WHEN t.tipo_tipologia LIKE 'Institucional_Salud_%'     
      THEN 'Institucional.' || regexp_replace(t.tipo_tipologia, '^Institucional_Salud_', 'Salud_')
    WHEN t.tipo_tipologia LIKE 'ED_%'                      
      THEN 'ED.' || t.tipo_tipologia
    ELSE regexp_replace(t.tipo_tipologia, '^([^_]+)_', '\1.', 'g')
  END AS tipo_tipologia_hom,
  t.conservacion_tipologia AS conservacion_hom
FROM preprod.t_ilc_caracteristicasunidadconstruccion t
WHERE t.tipo_tipologia IS NOT NULL 
  AND t.conservacion_tipologia IS NOT NULL;

INSERT INTO ladm.cuc_tipologiaconstruccion (
  t_ili_tid,
  tipo_tipologia,
  conservacion,
  id_match
)
SELECT
  uuid_generate_v4(),
  dom_tipo.t_id,
  dom_cons.t_id,
  t.id_match
FROM tmp_tipologia_map t
JOIN ladm.cuc_tipologiatipo                dom_tipo ON dom_tipo.ilicode = t.tipo_tipologia_hom
JOIN ladm.cuc_estadoconservaciontipologiatipo dom_cons ON dom_cons.ilicode = t.conservacion_hom;

DELETE FROM ladm.cuc_tipologiaconstruccion c
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_caracteristicasunidadconstruccion i
  WHERE i.local_id::bigint = c.id_match
);
    
/**
 * Migracion tabla ladm.cuc_tipologianoconvencional
 *
 * 
 */

ALTER TABLE ladm.cuc_tipologianoconvencional 
  ADD COLUMN IF NOT EXISTS id_match bigint;

TRUNCATE TABLE ladm.cuc_tipologianoconvencional CASCADE;

CREATE TABLE IF NOT EXISTS preprod.cuc_tipologianoconvencional_rechazados (
  tipo_anexo             text,
  tipo_anexo_hom         text,
  conservacion_anexo     text,
  id_match               bigint,
  motivo                 text
);
TRUNCATE TABLE preprod.cuc_tipologianoconvencional_rechazados;
DROP TABLE IF EXISTS tmp_anexo_map;
DROP TABLE IF EXISTS preprod.tmp_anexo_no_hopm;
CREATE TEMP TABLE tmp_anexo_map AS
SELECT
  t.*,
  t.objectid AS id_match,
  CASE
    WHEN tipo_anexo = 'Albercas_Baniaderas_Tipo_40' THEN 'Albercas_Baniaderas.Sencilla_Tipo_40'
    WHEN tipo_anexo = 'Albercas_Baniaderas_Tipo_60' THEN 'Albercas_Baniaderas.Medio_Tipo_60'
    WHEN tipo_anexo = 'Albercas_Baniaderas_Tipo_80' THEN 'Albercas_Baniaderas.Plus_Tipo_80'
    WHEN tipo_anexo = 'Beneficiaderos_Tipo_40' THEN 'Beneficiaderos.Sencilla_Tipo_40'
    WHEN tipo_anexo = 'Beneficiaderos_Tipo_60' THEN 'Beneficiaderos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Beneficiaderos_Tipo_80' THEN 'Beneficiaderos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Carreteras_Tipo_60' THEN 'Carreteras.Zona_Dura_Adoquin_Trafico_Liviano_Tipo_60'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_20' THEN 'Cimientos_Estructura_Muros_Placabase.Simples_Tipo_20'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_40' THEN 'Cimientos_Estructura_Muros_Placabase.Simples_Placa_Tipo_40'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_60' THEN 'Cimientos_Estructura_Muros_Placabase.Muro_Tipo_60'
    WHEN tipo_anexo = 'Cimientos_Estructura_Muros_Placabase_Tipo_80' THEN 'Cimientos_Estructura_Muros_Placabase.Placa_Muro_Tipo_80'
    WHEN tipo_anexo = 'Cocheras_Marraneras_Porquerizas_Tipo_20' THEN 'Cocheras_Marraneras_Porquerizas.Sencilla_Tipo_20'
    WHEN tipo_anexo = 'Cocheras_Marraneras_Porquerizas_Tipo_40' THEN 'Cocheras_Marraneras_Porquerizas.Media_Tipo_40'
    WHEN tipo_anexo = 'Cocheras_Marraneras_Porquerizas_Tipo_80' THEN 'Cocheras_Marraneras_Porquerizas.Tecnificada_Tipo_80'
    WHEN tipo_anexo = 'Corrales_Tipo_20' THEN 'Corrales.Sencillo_Tipo_20'
    WHEN tipo_anexo = 'Corrales_Tipo_40' THEN 'Corrales.Medio_Tipo_40'
    WHEN tipo_anexo = 'Corrales_Tipo_80' THEN 'Corrales.Tecnificado_Tipo_80'
    WHEN tipo_anexo = 'Establos_Pesebreras_Tipo_20' THEN 'Establos_Pesebreras.Sencillo_Tipo_20'
    WHEN tipo_anexo = 'Establos_Pesebreras_Tipo_60' THEN 'Establos_Pesebreras.Medio_Tipo_60'
    WHEN tipo_anexo = 'Establos_Pesebreras_Tipo_80' THEN 'Establos_Pesebreras.Tecnificado_Tipo_80'
    WHEN tipo_anexo = 'Galpones_Gallineros_Tipo_40' THEN 'Galpones_Gallineros.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Galpones_Gallineros_Tipo_60' THEN 'Galpones_Gallineros.Medio_Tipo_60'
    WHEN tipo_anexo = 'Galpones_Gallineros_Tipo_80' THEN 'Galpones_Gallineros.Tecnificado_Tipo_80'
    WHEN tipo_anexo = 'Kioskos_Tipo_40' THEN 'Kioscos.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Kioskos_Tipo_60' THEN 'Kioscos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Kioskos_Tipo_80' THEN 'Kioscos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Marquesinas_Tipo_40' THEN 'Marquesinas_Patios_Cubiertos.Sencilla_Tipo_40'
    WHEN tipo_anexo = 'Marquesinas_Tipo_60' THEN 'Marquesinas_Patios_Cubiertos.Media_Tipo_60'
    WHEN tipo_anexo = 'Marquesinas_Tipo_80' THEN 'Marquesinas_Patios_Cubiertos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Piscinas_Tipo_40' THEN 'Piscinas.Pequena_Tipo_40'
    WHEN tipo_anexo = 'Piscinas_Tipo_50' THEN 'Piscinas.Mediana_Tipo_50'
    WHEN tipo_anexo = 'Piscinas_Tipo_60' THEN 'Piscinas.Grande_Tipo_60'
    WHEN tipo_anexo = 'Piscinas_Tipo_80' THEN 'Piscinas.Prefabricada_Tipo_80'
    WHEN tipo_anexo = 'Pozos_Tipo_40' THEN 'Pozos.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Pozos_Tipo_60' THEN 'Pozos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Secaderos_Tipo_40' THEN 'Secaderos.Sencillo_Tipo_40'
    WHEN tipo_anexo = 'Secaderos_Tipo_60' THEN 'Secaderos.Medio_Tipo_60'
    WHEN tipo_anexo = 'Secaderos_Tipo_80' THEN 'Secaderos.Plus_Tipo_80'
    WHEN tipo_anexo = 'Silos_Tipo_80' THEN 'Silos.En_Acero_Galvanizado_Tipo_80'
    WHEN tipo_anexo = 'Tanques_Tipo_20' THEN 'Tanques.Sencillo_Sin_Revestir_Tipo_20'
    WHEN tipo_anexo = 'Tanques_Tipo_40' THEN 'Tanques.Medio_Tipo_40'
    WHEN tipo_anexo = 'Tanques_Tipo_60' THEN 'Tanques.Elevados_Plus_60'
    WHEN tipo_anexo = 'Toboganes_Tipo_60' THEN 'Toboganes.Medio_Tipo_60'
    WHEN tipo_anexo = 'Toboganes_Tipo_80' THEN 'Toboganes.Plus_Tipo_80'
    WHEN tipo_anexo = 'TorresEnfriamiento_Tipo_60' THEN 'Torres_Enfriamiento.Torres_Enfriamiento_Tipo_60'
    ELSE NULL
  END AS tipo_anexo_hom
FROM preprod.t_ilc_caracteristicasunidadconstruccion t;  -- sin filtros de NULL

-- 4) INSERT válidos (exige todo OK)
INSERT INTO ladm.cuc_tipologianoconvencional (
  t_ili_tid,
  tipo_anexo,
  conservacion_anexo,
  id_match
)
SELECT
  uuid_generate_v4(),
  dom_anexo.t_id,
  dom_cons.t_id,
  t.id_match
FROM tmp_anexo_map t
JOIN ladm.cuc_anexotipo                       AS dom_anexo ON dom_anexo.ilicode = t.tipo_anexo_hom
JOIN ladm.cuc_estadoconservaciontipologiatipo AS dom_cons  ON dom_cons.ilicode  = t.conservacion_anexo
WHERE t.tipo_anexo_hom IS NOT NULL
  AND t.conservacion_anexo IS NOT NULL;
CREATE TABLE preprod.tmp_anexo_no_hopm AS
SELECT
  t.tipo_anexo,
  t.tipo_anexo_hom,
  t.conservacion_anexo,
  t.id_match,
  dom_anexo.t_id AS tipo_anexo_t_id,
  dom_cons.t_id  AS conservacion_t_id,
  CASE
    WHEN t.conservacion_anexo IS NULL    THEN 'conservacion_anexo NULL'
    WHEN t.tipo_anexo_hom IS NULL        THEN 'sin regla de homologación (tipo_anexo_hom NULL)'
    WHEN dom_anexo.t_id IS NULL 
         AND dom_cons.t_id IS NULL       THEN 'ilicode tipo_anexo y conservacion NO existen'
    WHEN dom_anexo.t_id IS NULL          THEN 'ilicode tipo_anexo NO existe'
    WHEN dom_cons.t_id  IS NULL          THEN 'ilicode conservacion_anexo NO existe'
    ELSE 'desconocido'
  END AS motivo
FROM tmp_anexo_map t
LEFT JOIN ladm.cuc_anexotipo                       dom_anexo ON dom_anexo.ilicode = t.tipo_anexo_hom
LEFT JOIN ladm.cuc_estadoconservaciontipologiatipo dom_cons  ON dom_cons.ilicode  = t.conservacion_anexo
WHERE t.tipo_anexo IS NOT NULL
  AND NOT (
    t.tipo_anexo_hom IS NOT NULL
    AND t.conservacion_anexo IS NOT NULL
    AND dom_anexo.t_id IS NOT NULL
    AND dom_cons.t_id  IS NOT NULL
  );
DELETE FROM ladm.cuc_tipologianoconvencional c
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_caracteristicasunidadconstruccion i
  WHERE NULLIF(ltrim(regexp_replace(i.local_id::text, '\D','','g'), '0'), '')::bigint = c.id_match
);
DELETE FROM preprod.tmp_anexo_no_hopm r
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_caracteristicasunidadconstruccion i
  WHERE NULLIF(ltrim(regexp_replace(i.local_id::text, '\D','','g'), '0'), '')::bigint = r.id_match
);


/**
 * Migracion tabla ladm.cuc_calificacion_unidadconstruccion
 *
 * 
 */
 truncate table ladm.cuc_calificacion_unidadconstruccion;
INSERT INTO ladm.cuc_calificacion_unidadconstruccion (
    t_ili_tid,
    ilc_caracteristicasunidadconstruccion,
    cuc_clfccnndcnstrccion_cuc_tipologiaconstruccion,
    cuc_clfccnndcnstrccion_cuc_calificacionconvencional,
    cuc_clfccnndcnstrccion_cuc_tipologianoconvencional
)
SELECT
    uuid_generate_v4() AS t_ili_tid,
    car.t_id           AS ilc_caracteristicasunidadconstruccion,
    tc.t_id            AS cuc_clfccnndcnstrccion_cuc_tipologiaconstruccion,
    NULL::bigint       AS cuc_clfccnndcnstrccion_cuc_calificacionconvencional,
    tnc.t_id           AS cuc_clfccnndcnstrccion_cuc_tipologianoconvencional
FROM ladm.ilc_caracteristicasunidadconstruccion AS car
LEFT JOIN ladm.cuc_tipologiaconstruccion AS tc
    ON tc.id_match::text = car.local_id::text
LEFT JOIN ladm.cuc_tipologianoconvencional AS tnc
    ON tnc.id_match::text = car.local_id::text;


--ahora eliminar lo que no tiene predio 


BEGIN;

-- 1) Detectar duplicados y rankear (rn=1 se conserva)
WITH ranked AS (
  SELECT
    uc.t_id AS uc_tid,
    uc.cr_caracteristicasunidadconstruccion AS caract_tid,
    ROW_NUMBER() OVER (
      PARTITION BY uc.cr_caracteristicasunidadconstruccion
      ORDER BY uc.t_id
    ) AS rn
  FROM ladm.cr_unidadconstruccion uc
  WHERE uc.cr_caracteristicasunidadconstruccion IS NOT NULL
),
-- 2) Mapa de reasignación: por cada característica, el 'keeper' y sus duplicados
keepers AS (
  SELECT caract_tid, uc_tid AS uc_keep
  FROM ranked
  WHERE rn = 1
),
dups AS (
  SELECT r.caract_tid, r.uc_tid AS uc_delete, k.uc_keep
  FROM ranked r
  JOIN keepers k USING (caract_tid)
  WHERE r.rn > 1
)
-- 3) (Opcional) Ver qué se va a tocar
SELECT * FROM dups ORDER BY caract_tid, uc_delete;

-- 4) Reasignar referencias en tablas hijas conocidas
--    (ejemplo: extdireccion → cr_unidadconstruccion_ext_direccion_id)
WITH ranked AS (
  SELECT
    uc.t_id AS uc_tid,
    uc.cr_caracteristicasunidadconstruccion AS caract_tid,
    ROW_NUMBER() OVER (
      PARTITION BY uc.cr_caracteristicasunidadconstruccion
      ORDER BY uc.t_id
    ) AS rn
  FROM ladm.cr_unidadconstruccion uc
  WHERE uc.cr_caracteristicasunidadconstruccion IS NOT NULL
),
keepers AS (
  SELECT caract_tid, uc_tid AS uc_keep
  FROM ranked
  WHERE rn = 1
),
dups AS (
  SELECT r.caract_tid, r.uc_tid AS uc_delete, k.uc_keep
  FROM ranked r
  JOIN keepers k USING (caract_tid)
  WHERE r.rn > 1
)
UPDATE ladm.extdireccion e
SET cr_unidadconstruccion_ext_direccion_id = d.uc_keep
FROM dups d
WHERE e.cr_unidadconstruccion_ext_direccion_id = d.uc_delete;

-- 6) Borrar las UC duplicadas (ya reasignadas)
WITH ranked AS (
  SELECT
    uc.t_id AS uc_tid,
    uc.cr_caracteristicasunidadconstruccion AS caract_tid,
    ROW_NUMBER() OVER (
      PARTITION BY uc.cr_caracteristicasunidadconstruccion
      ORDER BY uc.t_id
    ) AS rn
  FROM ladm.cr_unidadconstruccion uc
  WHERE uc.cr_caracteristicasunidadconstruccion IS NOT NULL
),
a_borrar AS (
  SELECT uc_tid
  FROM ranked
  WHERE rn > 1
)
DELETE FROM ladm.cr_unidadconstruccion uc
USING a_borrar d
WHERE uc.t_id = d.uc_tid;

COMMIT;

--- arreglos para calificaico´n
BEGIN;

DROP TABLE IF EXISTS tmp_uc_faltantes;
CREATE TEMP TABLE tmp_uc_faltantes AS
SELECT 
    i.t_id              AS caract_tid,
    p.objectid::bigint  AS objectid
FROM ladm.ilc_caracteristicasunidadconstruccion i
JOIN preprod.t_ilc_caracteristicasunidadconstruccion p
  ON NULLIF(ltrim(regexp_replace(i.local_id::text,'\D','','g'),'0'),'')::bigint = p.objectid::bigint
LEFT JOIN ladm.cuc_tipologianoconvencional t
  ON t.id_match = p.objectid::bigint
WHERE p.tipo_anexo IS NOT NULL
  AND t.id_match IS NULL;

ALTER TABLE ladm.extdireccion
  DROP CONSTRAINT IF EXISTS extdireccion_cr_nddcnstrccn_xt_drccn_id_fkey;
ALTER TABLE ladm.extdireccion
  ADD CONSTRAINT extdireccion_cr_nddcnstrccn_xt_drccn_id_fkey
  FOREIGN KEY (cr_unidadconstruccion_ext_direccion_id)
  REFERENCES ladm.cr_unidadconstruccion(t_id)
  ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ladm.cuc_calificacion_unidadconstruccion
  DROP CONSTRAINT IF EXISTS cuc_califccn_nddcnstrccion_ilc_crctrstcsnddcnstrccion_fkey;
ALTER TABLE ladm.cuc_calificacion_unidadconstruccion
  ADD CONSTRAINT cuc_califccn_nddcnstrccion_ilc_crctrstcsnddcnstrccion_fkey
  FOREIGN KEY (ilc_caracteristicasunidadconstruccion)
  REFERENCES ladm.ilc_caracteristicasunidadconstruccion(t_id)
  ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED;

DELETE FROM ladm.cr_unidadconstruccion uc
USING tmp_uc_faltantes f
WHERE uc.cr_caracteristicasunidadconstruccion = f.caract_tid;

DELETE FROM ladm.ilc_caracteristicasunidadconstruccion i
USING tmp_uc_faltantes f
WHERE i.t_id = f.caract_tid;

COMMIT;

DROP TABLE IF EXISTS tmp_uc_faltantes;

DELETE FROM ladm.cuc_calificacion_unidadconstruccion
WHERE cuc_clfccnndcnstrccion_cuc_calificacionconvencional IS NULL
   OR cuc_clfccnndcnstrccion_cuc_tipologiaconstruccion IS NULL
   OR cuc_clfccnndcnstrccion_cuc_tipologianoconvencional IS NULL;

-- interesados 

-- A) RELACIÓN predio ↔ interesado (si ya existe, sáltalo)
DROP TABLE IF EXISTS preprod.t_predio_interesado_rel CASCADE;
CREATE TABLE preprod.t_predio_interesado_rel AS
SELECT DISTINCT
    i.t_id                         AS interesado_tid,
    i.documento_identidad,
    dt.ilicode                     AS tipo_documento_ilicode,
    p                               AS id_operacion_predio
FROM ladm.ilc_interesado i
JOIN ladm.cr_documentotipo dt
  ON dt.t_id = i.tipo_documento
JOIN preprod.t_interesado_predio_comun_agg a
  ON a.documento_identidad = i.documento_identidad
LEFT JOIN LATERAL unnest(a.predios) AS p ON TRUE
WHERE p IS NOT NULL;  -- evita filas con predio nulo

CREATE INDEX IF NOT EXISTS predio_interesado_predio_idx
  ON preprod.t_predio_interesado_rel (id_operacion_predio);
CREATE INDEX IF NOT EXISTS predio_interesado_tid_idx
  ON preprod.t_predio_interesado_rel (interesado_tid);
CREATE INDEX IF NOT EXISTS predio_interesado_doc_idx
  ON preprod.t_predio_interesado_rel (documento_identidad);


-- B) RESUMEN POR PREDIO (sin arrays, sin CSV)
DROP TABLE IF EXISTS preprod.t_agrupacion_por_predio CASCADE;
CREATE TABLE preprod.t_agrupacion_por_predio AS
WITH agg AS (
  SELECT
    r.id_operacion_predio                                        AS predio,
    COUNT(DISTINCT r.interesado_tid)                             AS n_interesados,
    COUNT(DISTINCT CASE WHEN r.tipo_documento_ilicode = 'NIT'
                        THEN r.interesado_tid END)               AS n_empresariales,
    COUNT(DISTINCT CASE WHEN r.tipo_documento_ilicode <> 'NIT'
                        THEN r.interesado_tid END)               AS n_civiles
  FROM preprod.t_predio_interesado_rel r
  GROUP BY r.id_operacion_predio
)
SELECT
  predio                                  AS nombre_agrupacion,
  n_interesados,
  n_empresariales,
  n_civiles,
  CASE
    WHEN n_empresariales > 0 AND n_civiles > 0 THEN 'Grupo_Mixto'
    WHEN n_empresariales > 0 AND n_civiles = 0 THEN 'Grupo_Empresarial'
    WHEN n_empresariales = 0 AND n_civiles > 0 THEN 'Grupo_Civil'
    ELSE 'Sin_Interesados'
  END AS tipo_potday
FROM agg;

CREATE INDEX IF NOT EXISTS agrup_predio_nombre_idx
  ON preprod.t_agrupacion_por_predio (nombre_agrupacion);
CREATE INDEX IF NOT EXISTS agrup_predio_tipopotday_idx
  ON preprod.t_agrupacion_por_predio (tipo_potday);


-- C) MIEMBROS POR PREDIO (una fila por documento / interesado)
DROP TABLE IF EXISTS preprod.t_agrupacion_miembros CASCADE;
CREATE TABLE preprod.t_agrupacion_miembros AS
WITH clasif AS (
  SELECT
    r.id_operacion_predio AS predio,
    COUNT(DISTINCT CASE WHEN r.tipo_documento_ilicode = 'NIT'
                        THEN r.interesado_tid END) AS n_empresariales,
    COUNT(DISTINCT CASE WHEN r.tipo_documento_ilicode <> 'NIT'
                        THEN r.interesado_tid END) AS n_civiles
  FROM preprod.t_predio_interesado_rel r
  GROUP BY r.id_operacion_predio
),
tipo AS (
  SELECT
    predio,
    CASE
      WHEN n_empresariales > 0 AND n_civiles > 0 THEN 'Grupo_Mixto'
      WHEN n_empresariales > 0 AND n_civiles = 0 THEN 'Grupo_Empresarial'
      WHEN n_empresariales = 0 AND n_civiles > 0 THEN 'Grupo_Civil'
      ELSE 'Sin_Interesados'
    END AS tipo_potday
  FROM clasif
)
SELECT DISTINCT
    r.id_operacion_predio          AS predio,
    r.interesado_tid,
    r.documento_identidad,
    r.tipo_documento_ilicode,
    t.tipo_potday                  -- se repite por miembro (como pediste)
FROM preprod.t_predio_interesado_rel r
JOIN tipo t
  ON t.predio = r.id_operacion_predio
ORDER BY predio, interesado_tid;

CREATE INDEX IF NOT EXISTS agrup_miembros_predio_idx
  ON preprod.t_agrupacion_miembros (predio);
CREATE INDEX IF NOT EXISTS agrup_miembros_tid_idx
  ON preprod.t_agrupacion_miembros (interesado_tid);


--- ahora si insert 

-- Limpiar destino
ALTER TABLE ladm.ilc_interesado
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS derecho_guid varchar(38);

TRUNCATE TABLE ladm.ilc_interesado CASCADE;

DROP TABLE IF EXISTS preprod.interesado_no_match;
CREATE TABLE preprod.interesado_no_match (
  objectid text,
  id_operacion_predio text,
  tipo_src text,
  tipo_documento_src text,
  sexo_src text,
  grupo_etnico_src text,
  autorreco_campesino_src text,
  documento_identidad text,
  primer_nombre text,
  segundo_nombre text,
  primer_apellido text,
  segundo_apellido text,
  razon_social text,
  nombre text,
  motivo text
);

WITH
src AS (
  SELECT *
  FROM preprod.t_interesado_predio_comun_agg
),
tipo_id AS (
  SELECT s.documento_identidad, d.t_id AS tipo_t_id
  FROM src s
  LEFT JOIN ladm.cr_interesadotipo d ON d.ilicode = s.tipo::text
),
tdoc_id AS (
  SELECT s.documento_identidad, d.t_id AS tipo_documento_t_id
  FROM src s
  LEFT JOIN ladm.cr_documentotipo d ON d.ilicode = s.tipo_documento::text
),
sexo_id AS (
  SELECT s.documento_identidad,
         COALESCE(dom1.t_id, dom2.t_id) AS sexo_t_id
  FROM src s
  LEFT JOIN ladm.cr_sexotipo dom1 ON dom1.ilicode = s.sexo::text
  LEFT JOIN ladm.cr_sexotipo dom2 ON dom2.ilicode = 'Sin_Determinar'
       AND (s.sexo IN ('Indeterminado','No_Clasificable') OR s.sexo IS NULL)
),
grp_norm AS (
  SELECT s.documento_identidad,
         CASE
           WHEN s.grupo_etnico IS NULL THEN 'Sin_Determinar'
           WHEN s.grupo_etnico = 'Etnico_Indigena'             THEN 'Etnico.Indigena'
           WHEN s.grupo_etnico = 'Etnico_Negro_Afrocolombiano' THEN 'Etnico.Negro_Afrocolombiano'
           WHEN s.grupo_etnico = 'Palenquero'                  THEN 'Etnico.Palenquero'
           WHEN s.grupo_etnico = 'Ninguno'                     THEN 'Ninguno'
           WHEN s.grupo_etnico LIKE 'Etnico_%'
                THEN regexp_replace(s.grupo_etnico, '^([^_]+)_', '\1.')
           ELSE s.grupo_etnico
         END AS grp_ilicode
  FROM src s
),
grupo_id AS (
  SELECT g.documento_identidad, d.t_id AS grupo_etnico_t_id
  FROM grp_norm g
  LEFT JOIN ladm.ilc_autorreconocimientoetnicotipo d ON d.ilicode = g.grp_ilicode
),
campesino AS (
  SELECT s.documento_identidad,
         CASE
           WHEN s.autorreco_campesino IS NULL THEN NULL
           WHEN s.autorreco_campesino ~* '^(si|sí|s|y|yes|on|true|t|1)$' THEN TRUE
           WHEN s.autorreco_campesino ~* '^(no|n|off|false|f|0)$'        THEN FALSE
           ELSE NULL
         END AS autor_bool
  FROM src s
),
j AS (
  SELECT
    s.*,
    t.tipo_t_id,
    td.tipo_documento_t_id,
    sx.sexo_t_id,
    ge.grupo_etnico_t_id,
    c.autor_bool
  FROM src s
  LEFT JOIN tipo_id  t  ON t.documento_identidad  = s.documento_identidad
  LEFT JOIN tdoc_id  td ON td.documento_identidad = s.documento_identidad
  LEFT JOIN sexo_id  sx ON sx.documento_identidad = s.documento_identidad
  LEFT JOIN grupo_id ge ON ge.documento_identidad = s.documento_identidad
  LEFT JOIN campesino c ON c.documento_identidad  = s.documento_identidad
),
validos AS (
  SELECT *
  FROM j
  WHERE tipo_t_id IS NOT NULL
    AND tipo_documento_t_id IS NOT NULL
    AND autor_bool IS NOT NULL
    AND documento_identidad IS NOT NULL AND btrim(documento_identidad) <> ''
),
rechazados AS (
  SELECT * ,
         CASE
           WHEN tipo_t_id IS NULL            THEN 'Tipo (NOT NULL) sin match'
           WHEN tipo_documento_t_id IS NULL  THEN 'Tipo documento (NOT NULL) sin match'
           WHEN autor_bool IS NULL           THEN 'Autorreconocimiento campesino (NOT NULL) inválido/NULL'
           WHEN documento_identidad IS NULL OR btrim(documento_identidad) = '' THEN 'Documento identidad (NOT NULL) nulo/vacío'
         END AS motivo
  FROM j
  WHERE tipo_t_id IS NULL
     OR tipo_documento_t_id IS NULL
     OR autor_bool IS NULL
     OR documento_identidad IS NULL OR btrim(documento_identidad) = ''
),
ins_bad AS (
  INSERT INTO preprod.interesado_no_match (
    objectid, id_operacion_predio, tipo_src, tipo_documento_src, sexo_src, grupo_etnico_src,
    autorreco_campesino_src, documento_identidad, primer_nombre, segundo_nombre,
    primer_apellido, segundo_apellido, razon_social, nombre, motivo
  )
  SELECT
    r.documento_identidad AS objectid,
    string_agg(p, ',') AS id_operacion_predio,
    r.tipo, r.tipo_documento, r.sexo, r.grupo_etnico,
    r.autorreco_campesino, r.documento_identidad,
    r.primer_nombre, r.segundo_nombre,
    r.primer_apellido, r.segundo_apellido,
    r.razon_social, r.nombre, r.motivo
  FROM rechazados r
  LEFT JOIN LATERAL unnest(r.predios) AS p ON true
  GROUP BY r.documento_identidad, r.tipo, r.tipo_documento, r.sexo, r.grupo_etnico,
           r.autorreco_campesino, r.primer_nombre, r.segundo_nombre, r.primer_apellido,
           r.segundo_apellido, r.razon_social, r.nombre, r.motivo
  RETURNING 1
),
ins_ok AS (
  INSERT INTO ladm.ilc_interesado (
    tipo, tipo_documento, documento_identidad,
    primer_nombre, segundo_nombre, primer_apellido, segundo_apellido,
    sexo, grupo_etnico, autorreconocimientocampesino,
    razon_social, nombre,
    comienzo_vida_util_version, fin_vida_util_version,
    espacio_de_nombres, local_id,
    derecho_guid
  )
  SELECT
    v.tipo_t_id,
    v.tipo_documento_t_id,
    v.documento_identidad,
    v.primer_nombre,
    v.segundo_nombre,
    v.primer_apellido,
    v.segundo_apellido,
    v.sexo_t_id,
    v.grupo_etnico_t_id,
    v.autor_bool,
    v.razon_social,
    v.nombre,
    NOW(), NULL,
    'ilc_interesado',
    v.documento_identidad,
    v.id::text  -- derecho_guid = identificador creado en la tabla agregada
  FROM validos v
  RETURNING 1
)
SELECT
  (SELECT COUNT(*) FROM ins_ok)  AS insertados,
  (SELECT COUNT(*) FROM ins_bad) AS rechazados;



-- agrupaicon 
-- Habilita UUID v4 si hace falta
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

WITH per_predio AS (
  SELECT
    d.predio::text                           AS predio_txt,
    COUNT(DISTINCT d.interesado_tid)         AS n_interesados,
    BOOL_OR(d.tipo_documento_ilicode = 'NIT')      AS hay_nit,
    BOOL_OR(d.tipo_documento_ilicode <> 'NIT')     AS hay_no_nit
  FROM preprod.t_documentos_por_predio d
  GROUP BY d.predio
),
tipo AS (
  SELECT
    predio_txt,
    n_interesados,
    CASE
      WHEN hay_nit AND hay_no_nit THEN 'Grupo_Mixto'
      WHEN hay_nit THEN 'Grupo_Empresarial'
      WHEN hay_no_nit THEN 'Grupo_Civil'
      ELSE 'Sin_Interesados'
    END AS tipo_potday
  FROM per_predio
),
base AS (
  -- **Solo predios con > 1 interesado**
  SELECT predio_txt, tipo_potday
  FROM tipo
  WHERE n_interesados > 1
),
to_ins AS (
  SELECT
    uuid_generate_v4()                       AS t_ili_tid,
    gti.t_id                                 AS tipo,   -- mapeo por ilicode
    NULL::text                               AS nombre,
    NOW()                                    AS comienzo_vida_util_version,
    NULL::timestamp                          AS fin_vida_util_version,
    'cr_agrupacioninteresados'::text         AS espacio_de_nombres,
    b.predio_txt                             AS local_id
  FROM base b
  JOIN ladm.col_grupointeresadotipo gti
    ON gti.ilicode = b.tipo_potday
  LEFT JOIN ladm.cr_agrupacioninteresados ex
    ON ex.local_id = b.predio_txt
  WHERE ex.t_id IS NULL
)
INSERT INTO ladm.cr_agrupacioninteresados (
  t_ili_tid, tipo, nombre,
  comienzo_vida_util_version, fin_vida_util_version,
  espacio_de_nombres, local_id
)
SELECT
  t_ili_tid, tipo, nombre,
  comienzo_vida_util_version, fin_vida_util_version,
  espacio_de_nombres, local_id
FROM to_ins
RETURNING t_id, t_ili_tid, local_id, tipo;

---col_miembros

-- Habilita UUID v4 si hace falta
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

WITH base AS (
  -- Un registro por (predio, documento NORMALIZADO)
  SELECT DISTINCT
    d.predio::text                               AS predio_txt,
    NULLIF(btrim(d.documento_identidad), '')     AS doc_norm
  FROM preprod.t_documentos_por_predio d
),
-- 1 solo t_id por documento: el menor t_id (ajusta criterio si quieres)
i AS (
  SELECT
    x.doc_norm,
    MIN(x.t_id) AS interesado_tid
  FROM (
    SELECT NULLIF(btrim(i.documento_identidad), '') AS doc_norm,
           i.t_id
    FROM ladm.ilc_interesado i
    WHERE i.documento_identidad IS NOT NULL AND btrim(i.documento_identidad) <> ''
  ) x
  GROUP BY x.doc_norm
),
-- Empate (predio, t_id) usando doc normalizado
i_predio AS (
  SELECT b.predio_txt, i.interesado_tid
  FROM base b
  JOIN i ON i.doc_norm = b.doc_norm
),
-- Agrupación por predio (local_id = predio)
g AS (
  SELECT a.local_id::text AS predio_txt, a.t_id AS agrupacion_tid
  FROM ladm.cr_agrupacioninteresados a
),
to_ins AS (
  SELECT DISTINCT
    uuid_generate_v4()          AS t_ili_tid,
    ip.interesado_tid           AS interesado_ilc_interesado,
    NULL::bigint                AS interesado_cr_agrupacioninteresados,
    g.agrupacion_tid            AS agrupacion,
    NULL::numeric               AS participacion
  FROM i_predio ip
  JOIN g ON g.predio_txt = ip.predio_txt
  LEFT JOIN ladm.col_miembros ex
    ON ex.interesado_ilc_interesado = ip.interesado_tid
   AND ex.agrupacion = g.agrupacion_tid
  WHERE ex.t_id IS NULL
)
INSERT INTO ladm.col_miembros (
  t_ili_tid,
  interesado_ilc_interesado,
  interesado_cr_agrupacioninteresados,
  agrupacion,
  participacion
)
SELECT t_ili_tid, interesado_ilc_interesado, interesado_cr_agrupacioninteresados, agrupacion, participacion
FROM to_ins
RETURNING t_id, agrupacion, interesado_ilc_interesado;

-- inetresado contacto

-- Habilita UUID v4 si es necesario
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

INSERT INTO ladm.ilc_interesadocontacto (
    t_ili_tid,
    telefono,
    domicilio_notificacion,
    direccion_residencia,
    correo_electronico,
    autoriza_notificacion_correo,
    departamento,
    municipio,
    cr_interesado
)
SELECT
    uuid_generate_v4() AS t_ili_tid,
    NULLIF(t.telefono, '')::numeric, -- 🔹 conversión segura
    t.domicilio_notificacion,
    t.direccion_residencia,
    t.correo_electronico,
    CASE 
        WHEN LOWER(t.autoriza_notificacion_correo) IN ('true','t','1','si','sí') THEN TRUE
        WHEN LOWER(t.autoriza_notificacion_correo) IN ('false','f','0','no') THEN FALSE
        ELSE FALSE -- fuerza a FALSE si no es boolean válido
    END,
    t.departamento,
    t.municipio,
    i.t_id AS cr_interesado
FROM preprod.t_ilc_interesado t
JOIN ladm.ilc_interesado i
  ON i.documento_identidad = t.documento_identidad
 AND (
       i.nombre = t.nombre
       OR (i.primer_nombre = t.primer_nombre AND i.primer_apellido = t.primer_apellido)
     );


DELETE FROM ladm.ilc_interesadocontacto a
USING ladm.ilc_interesadocontacto b
WHERE a.cr_interesado = b.cr_interesado
  AND a.t_id > b.t_id;


--- derecho
-- Extensión para UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Asegura columnas en destino
ALTER TABLE ladm.ilc_derecho
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255),
  ADD COLUMN IF NOT EXISTS interesado_guid     varchar(38),
  ADD COLUMN IF NOT EXISTS guid_derecho        varchar(38);

-- Inserta desde agg con expansión de derechos_csv
-- Extensión para UUID si no existe
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

INSERT INTO ladm.ilc_derecho (
    t_ili_tid,
    tipo,
    posesion_ancestral_y_o_tradicional,
    fecha_inicio_tenencia,
    descripcion,
    unidad,
    comienzo_vida_util_version,
    fin_vida_util_version,
    espacio_de_nombres,
    local_id,
    id_operacion_predio,
    interesado_guid,
    guid_derecho
)
WITH dominio AS (
  SELECT t_id AS t_dom
  FROM ladm.ilc_derechocatastraltipo
  WHERE ilicode = 'Dominio'
  LIMIT 1
),
pairs AS (
  SELECT
    p.id::varchar AS interesado_guid,
    pr.predio::varchar AS id_operacion_predio,
    lower(regexp_replace(trim(dr.derecho), '[{}]', '', 'g')) AS guid_derecho_norm
  FROM preprod.t_interesado_predio_comun_agg p
  JOIN LATERAL unnest(p.predios) WITH ORDINALITY AS pr(predio, idx) ON TRUE
  JOIN LATERAL unnest(string_to_array(p.derechos_csv, ',')) WITH ORDINALITY AS dr(derecho, idx)
    ON pr.idx = dr.idx
),
src AS (
  SELECT
    pr.interesado_guid,
    pr.id_operacion_predio,
    pr.guid_derecho_norm,
    d.objectid,
    COALESCE(
      (
        SELECT t_id
        FROM ladm.ilc_derechocatastraltipo
        WHERE ilicode = COALESCE(
                          CASE
                            WHEN lower(trim(d.tipo)) IN ('sin definir','sin_definir') THEN 'Dominio'
                            ELSE d.tipo
                          END,
                          'Dominio'
                        )
        LIMIT 1
      ),
      (SELECT t_dom FROM dominio)
    ) AS tipo_t_id,
    CASE
      WHEN lower(coalesce(d.posecion_ancestral_y_o_tradicio::text,'')) IN ('1','t','true','sí','si','s','y','yes') THEN TRUE
      WHEN lower(coalesce(d.posecion_ancestral_y_o_tradicio::text,'')) IN ('0','f','false','no','n')               THEN FALSE
      ELSE FALSE
    END AS pos_ancestral,
    COALESCE(d.fecha_inicio_tenencia, CURRENT_DATE) AS fecha_ini
  FROM pairs pr
  JOIN preprod.t_ilc_derecho d
    ON lower(regexp_replace(d.globalid::text,'[{}]','','g')) = pr.guid_derecho_norm
)
SELECT
  uuid_generate_v4()               AS t_ili_tid,
  s.tipo_t_id                      AS tipo,
  s.pos_ancestral                  AS posesion_ancestral_y_o_tradicional,
  s.fecha_ini                      AS fecha_inicio_tenencia,
  NULL::varchar                    AS descripcion,
  NULL::bigint                     AS unidad,
  NOW()                            AS comienzo_vida_util_version,
  NULL::timestamp                  AS fin_vida_util_version,
  'ilc_derecho'                    AS espacio_de_nombres,
  s.objectid                       AS local_id,
  s.id_operacion_predio            AS id_operacion_predio,
  s.interesado_guid                AS interesado_guid,
  s.guid_derecho_norm              AS guid_derecho
FROM src s
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.ilc_derecho x
  WHERE x.guid_derecho = s.guid_derecho_norm
    AND x.id_operacion_predio = s.id_operacion_predio
);

DO $$
DECLARE
    filas_borradas bigint;
BEGIN
  LOOP
    WITH dups AS (
      SELECT a.ctid
      FROM ladm.ilc_derecho a
      JOIN (
        SELECT interesado_guid, MIN(t_id) AS min_tid
        FROM ladm.ilc_derecho
        WHERE interesado_guid IS NOT NULL
        GROUP BY interesado_guid
      ) b
        ON a.interesado_guid = b.interesado_guid
      WHERE a.t_id <> b.min_tid
      LIMIT 50000
    )
    DELETE FROM ladm.ilc_derecho t
    USING dups
    WHERE t.ctid = dups.ctid;

    GET DIAGNOSTICS filas_borradas = ROW_COUNT;
    EXIT WHEN filas_borradas = 0;
  END LOOP;
END $$;


----rrrinteresados

-- Recomendado: índices para velocidad
CREATE INDEX IF NOT EXISTS ilc_interesado_derecho_guid_idx ON ladm.ilc_interesado(derecho_guid);
CREATE INDEX IF NOT EXISTS agg_id_idx                       ON preprod.t_interesado_predio_comun_agg(id);
CREATE INDEX IF NOT EXISTS ilc_derecho_guid_idx             ON ladm.ilc_derecho(guid_derecho);
CREATE INDEX IF NOT EXISTS col_rrri_rrr_int_idx             ON ladm.col_rrrinteresado(rrr, interesado_ilc_interesado);

-- Inserción
WITH pares AS (
  SELECT
    p.id::varchar AS interesado_guid,
    pr.idx,
    lower(regexp_replace(trim(dr.derecho),'[{}]','','g')) AS derecho_guid_norm
  FROM preprod.t_interesado_predio_comun_agg p
  JOIN LATERAL unnest(p.predios) WITH ORDINALITY       AS pr(predio, idx) ON TRUE
  JOIN LATERAL unnest(string_to_array(p.derechos_csv, ',')) WITH ORDINALITY AS dr(derecho, idx)
    ON pr.idx = dr.idx
),
src AS (
  SELECT
    i.t_id  AS interesado_tid,
    d.t_id  AS rrr_tid
  FROM ladm.ilc_interesado i
  JOIN pares pa
    ON i.derecho_guid = pa.interesado_guid       -- << i.derecho_guid es el ID de agg
  JOIN ladm.ilc_derecho d
    ON d.guid_derecho = pa.derecho_guid_norm     -- << derecho real al que se asocia
)
INSERT INTO ladm.col_rrrinteresado (
  t_ili_tid,
  rrr,
  interesado_ilc_interesado,
  interesado_cr_agrupacioninteresados
)
SELECT
  uuid_generate_v4(),
  s.rrr_tid,
  s.interesado_tid,
  NULL::bigint
FROM src s
WHERE NOT EXISTS (
  SELECT 1
  FROM ladm.col_rrrinteresado x
  WHERE x.rrr = s.rrr_tid
    AND x.interesado_ilc_interesado = s.interesado_tid
);


BEGIN;

-- A. Eliminar duplicados completos (misma rrr, mismo interesado)
WITH duplicados AS (
  SELECT
    t_id,
    ROW_NUMBER() OVER (PARTITION BY rrr, interesado_cr_agrupacioninteresados, interesado_ilc_interesado ORDER BY t_id) AS rn
  FROM ladm.col_rrrinteresado
)
DELETE FROM ladm.col_rrrinteresado
WHERE t_id IN (
  SELECT t_id FROM duplicados WHERE rn > 1
);

-- B. Eliminar relaciones con interesado_ilc_interesado si ya existe la agrupación para el mismo RRR
WITH rrr_con_grp AS (
  SELECT DISTINCT rrr
  FROM ladm.col_rrrinteresado
  WHERE interesado_cr_agrupacioninteresados IS NOT NULL
),
to_del AS (
  SELECT c.ctid
  FROM ladm.col_rrrinteresado c
  JOIN rrr_con_grp g ON c.rrr = g.rrr
  WHERE c.interesado_ilc_interesado IS NOT NULL
)
DELETE FROM ladm.col_rrrinteresado
WHERE ctid IN (SELECT ctid FROM to_del);

-- C. Deduplicar agrupaciones: mantener solo una fila por rrr
WITH grp_rank AS (
  SELECT
    t_id,
    ROW_NUMBER() OVER (PARTITION BY rrr ORDER BY t_id) AS rn
  FROM ladm.col_rrrinteresado
  WHERE interesado_cr_agrupacioninteresados IS NOT NULL
)
DELETE FROM ladm.col_rrrinteresado
WHERE t_id IN (
  SELECT t_id FROM grp_rank WHERE rn > 1
);

-- D. Deduplicar interesados individuales: mantener solo una fila por rrr
WITH ind_rank AS (
  SELECT
    t_id,
    ROW_NUMBER() OVER (PARTITION BY rrr ORDER BY t_id) AS rn
  FROM ladm.col_rrrinteresado
  WHERE interesado_cr_agrupacioninteresados IS NULL
    AND interesado_ilc_interesado IS NOT NULL
)
DELETE FROM ladm.col_rrrinteresado
WHERE t_id IN (
  SELECT t_id FROM ind_rank WHERE rn > 1
);

COMMIT;


--- extinteresado
INSERT INTO ladm.extinteresado (
  t_id,
  t_seq,
  nombre,
  documento_escaneado,
  extredserviciosfisica_ext_interesado_administrador_id,
  cr_agrupacionintersdos_ext_pid,
  ilc_interesado_ext_pid
)
SELECT
  nextval('ladm.t_ili2db_seq') AS t_id,
  NULL AS t_seq,
  NULL AS nombre,
  NULL AS documento_escaneado,
  NULL AS extredserviciosfisica_ext_interesado_administrador_id,
  c.interesado_cr_agrupacioninteresados AS cr_agrupacionintersdos_ext_pid,
  c.interesado_ilc_interesado AS ilc_interesado_ext_pid
FROM ladm.col_rrrinteresado c
WHERE c.interesado_ilc_interesado IS NOT NULL
   OR c.interesado_cr_agrupacioninteresados IS NOT NULL;



--extinteresado

INSERT INTO ladm.extinteresado (
  t_id,
  t_seq,
  nombre,
  documento_escaneado,
  extredserviciosfisica_ext_interesado_administrador_id,
  cr_agrupacionintersdos_ext_pid,
  ilc_interesado_ext_pid
)
SELECT
  nextval('ladm.t_ili2db_seq') AS t_id,
  NULL AS t_seq,
  NULL AS nombre,
  NULL AS documento_escaneado,
  NULL AS extredserviciosfisica_ext_interesado_administrador_id,
  c.interesado_cr_agrupacioninteresados AS cr_agrupacionintersdos_ext_pid,
  c.interesado_ilc_interesado AS ilc_interesado_ext_pid
FROM ladm.col_rrrinteresado c
WHERE c.interesado_ilc_interesado IS NOT NULL
   OR c.interesado_cr_agrupacioninteresados IS NOT NULL;

DELETE FROM ladm.extinteresado a
USING (
    SELECT MIN(ctid) AS ctid, id_operacion_predio
    FROM ladm.extinteresado
    WHERE id_operacion_predio IS NOT NULL
    GROUP BY id_operacion_predio
    HAVING COUNT(*) > 1
) b
WHERE a.id_operacion_predio = b.id_operacion_predio
AND a.ctid <> b.ctid;
-- Asegura la columna existe
ALTER TABLE ladm.extinteresado
  ADD COLUMN IF NOT EXISTS id_operacion_predio varchar(255);

-- Actualiza solo donde se pueda traer desde ilc_interesado
UPDATE ladm.extinteresado ext
SET id_operacion_predio = i.id_operacion_predio
FROM ladm.ilc_interesado i
WHERE ext.ilc_interesado_ext_pid = i.t_id
  AND ext.id_operacion_predio IS NULL
  AND i.id_operacion_predio IS NOT NULL;

--- extdirección


-- 1. Limpiar tabla destino
TRUNCATE TABLE ladm.extdireccion CASCADE;

-- 2. Fuente normalizada desde preprod
DROP TABLE IF EXISTS tmp_extdir_src;
CREATE UNLOGGED TABLE tmp_extdir_src AS
SELECT
  p.*,
  btrim(p.id_operacion_predio::text) AS id_op_norm,
  CASE 
    WHEN upper(trim(p.es_direccion_principal)) IN ('SI','S','TRUE','T','1') THEN TRUE
    WHEN upper(trim(p.es_direccion_principal)) IN ('NO','N','FALSE','F','0') THEN FALSE
    ELSE NULL
  END AS es_principal_bool,
  CASE
    WHEN p.localizacion IS NULL OR trim(p.localizacion) = '' THEN NULL
    WHEN p.localizacion ~* '^\s*POINT(\s+Z(M)?|\s*)\s*\('
      THEN ST_SetSRID(ST_Force3D(ST_GeomFromText(trim(p.localizacion))), 9377)
    ELSE NULL
  END AS geom_wkt
FROM preprod.t_extdireccion p
WHERE p.id_operacion_predio IS NOT NULL;

CREATE INDEX tmp_extdir_src_idop_idx ON tmp_extdir_src (id_op_norm);
ANALYZE tmp_extdir_src;

-- 3. Mapeos por id_operacion_predio

-- 3.1 extinteresado
DROP TABLE IF EXISTS map_ei;
CREATE UNLOGGED TABLE map_ei AS
SELECT btrim(id_operacion_predio::text) AS id_op_norm, MIN(t_id) AS t_id
FROM ladm.extinteresado
WHERE id_operacion_predio IS NOT NULL
GROUP BY 1;
CREATE INDEX map_ei_idop_idx ON map_ei (id_op_norm);
ANALYZE map_ei;

-- 3.2 cr_terreno
DROP TABLE IF EXISTS map_t;
CREATE UNLOGGED TABLE map_t AS
SELECT btrim(cod_match::text) AS id_op_norm, MIN(t_id) AS t_id
FROM ladm.cr_terreno
WHERE cod_match IS NOT NULL
GROUP BY 1;
CREATE INDEX map_t_idop_idx ON map_t (id_op_norm);
ANALYZE map_t;

-- 3.3 cr_unidadconstruccion
DROP TABLE IF EXISTS map_uc;
CREATE UNLOGGED TABLE map_uc AS
WITH src_link AS (
  SELECT btrim(src.id_operacion_predio::text) AS id_op_norm, uc.t_id
  FROM ladm.cr_unidadconstruccion uc
  JOIN preprod.t_cr_unidadconstruccion src
    ON src.objectid::text = uc.local_id::text
  WHERE src.id_operacion_predio IS NOT NULL
),
predio_link AS (
  SELECT btrim(p.id_operacion_predio::text) AS id_op_norm, uc.t_id
  FROM ladm.cr_unidadconstruccion uc
  JOIN ladm.ilc_predio p
    ON p.t_id::text = uc.id_predio::text
  WHERE p.id_operacion_predio IS NOT NULL
),
all_uc AS (
  SELECT * FROM src_link
  UNION ALL
  SELECT * FROM predio_link
)
SELECT id_op_norm, MIN(t_id) AS t_id
FROM all_uc
GROUP BY id_op_norm;
CREATE INDEX map_uc_idop_idx ON map_uc (id_op_norm);
ANALYZE map_uc;

-- 3.4 ilc_predio
DROP TABLE IF EXISTS map_pr;
CREATE UNLOGGED TABLE map_pr AS
SELECT btrim(id_operacion_predio::text) AS id_op_norm, MIN(t_id) AS t_id
FROM ladm.ilc_predio
WHERE id_operacion_predio IS NOT NULL
GROUP BY 1;
CREATE INDEX map_pr_idop_idx ON map_pr (id_op_norm);
ANALYZE map_pr;

-- 4. Inserción final en ladm.extdireccion
INSERT INTO ladm.extdireccion (
  tipo_direccion,
  es_direccion_principal,
  localizacion,
  codigo_postal,
  clase_via_principal,
  valor_via_principal,
  letra_via_principal,
  letra_via_generadora,
  sector_ciudad,
  valor_via_generadora,
  numero_predio,
  sector_predio,
  complemento,
  nombre_predio,
  extunidadedificcnfsica_ext_direccion_id,
  extinteresado_ext_direccion_id,
  cr_terreno_ext_direccion_id,
  cr_unidadconstruccion_ext_direccion_id,
  ilc_predio_direccion
)
SELECT
  td.t_id,
  s.es_principal_bool,
  s.geom_wkt,
  s.codigo_postal,
  cv.t_id,
  s.valor_via_principal,
  s.letra_via_principal,
  s.letra_via_generadora,
  sc.t_id,
  s.valor_via_generadora,
  s.numero_predio,
  sp.t_id,
  s.complemento,
  s.nombre_predio,
  NULL::bigint,
  CASE WHEN pr.t_id IS NOT NULL THEN NULL ELSE ei.t_id END,
  t.t_id,
  uc.t_id,
  pr.t_id
FROM tmp_extdir_src s
JOIN ladm.extdireccion_tipo_direccion td
  ON td.ilicode = s.tipo_direccion::text
LEFT JOIN ladm.extdireccion_clase_via_principal cv
  ON cv.ilicode = s.clase_via_principal::text
LEFT JOIN ladm.extdireccion_sector_ciudad sc
  ON sc.ilicode = s.sector_ciudad::text
LEFT JOIN ladm.extdireccion_sector_predio sp
  ON sp.ilicode = s.sector_predio::text
LEFT JOIN map_ei ei ON ei.id_op_norm = s.id_op_norm
LEFT JOIN map_t  t  ON t.id_op_norm  = s.id_op_norm
LEFT JOIN map_uc uc ON uc.id_op_norm = s.id_op_norm
LEFT JOIN map_pr pr ON pr.id_op_norm = s.id_op_norm;

-- 5. Limpieza
DROP TABLE IF EXISTS tmp_extdir_src;
DROP TABLE IF EXISTS map_ei;
DROP TABLE IF EXISTS map_t;
DROP TABLE IF EXISTS map_uc;
DROP TABLE IF EXISTS map_pr;

DELETE FROM ladm.extdireccion
WHERE ilc_predio_direccion IS NULL;

-- Inserta solo predios que no estén ya relacionados en extdireccion
INSERT INTO ladm.extdireccion (
  tipo_direccion,
  es_direccion_principal,
  localizacion,
  codigo_postal,
  clase_via_principal,
  valor_via_principal,
  letra_via_principal,
  letra_via_generadora,
  sector_ciudad,
  valor_via_generadora,
  numero_predio,
  sector_predio,
  complemento,
  nombre_predio,
  extunidadedificcnfsica_ext_direccion_id,
  extinteresado_ext_direccion_id,
  cr_terreno_ext_direccion_id,
  cr_unidadconstruccion_ext_direccion_id,
  ilc_predio_direccion
)
SELECT
  NULL,       -- tipo_direccion
  NULL,       -- es_direccion_principal
  NULL,       -- localizacion
  NULL,       -- codigo_postal
  NULL,       -- clase_via_principal
  NULL,       -- valor_via_principal
  NULL,       -- letra_via_principal
  NULL,       -- letra_via_generadora
  NULL,       -- sector_ciudad
  NULL,       -- valor_via_generadora
  NULL,       -- numero_predio
  NULL,       -- sector_predio
  NULL,       -- complemento
  NULL,       -- nombre_predio
  NULL,       -- extunidadedificcnfsica_ext_direccion_id
  NULL,       -- extinteresado_ext_direccion_id
  NULL,       -- cr_terreno_ext_direccion_id
  NULL,       -- cr_unidadconstruccion_ext_direccion_id
  p.t_id      -- ilc_predio_direccion
FROM ladm.ilc_predio p
LEFT JOIN ladm.extdireccion ed ON ed.ilc_predio_direccion = p.t_id
WHERE ed.t_id IS NULL;


