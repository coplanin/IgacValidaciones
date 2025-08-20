
/*//////////////////////////////////////////////////////////////////////////////////////////////////////////////

*/


INSERT INTO colsmart_prod_indicadores.consistencia_validacion_resultados
( id_sesion, regla, objeto, tabla, objectid, globalid, predio_id, numero_predial, descripcion, valor)
VALUES(1,  '1.1', '', '', 0, '', 0, '', '', '', 'NO');


--regla 691
create table reglas.regla_691 as
WITH req AS (
  SELECT
    p.objectid,
    p.id_operacion,
    p.globalid,
    p.numero_predial_nacional,
    p.destinacion_economica
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.destinacion_economica)) IN
    ('comercial','educativo','habitacional','industrial','institucional','salubridad')
),
uc AS (
  SELECT btrim(c.id_operacion_predio) AS id_operacion_predio, COUNT(*) AS n_uc
  FROM preprod.cr_unidadconstruccion c
  GROUP BY 1
)
SELECT
  '691'                           AS regla,
  'ILC_Predio'                                   AS objeto,
  'preprod.ilc_predio'                           AS tabla,
  r.objectid                                     AS objectid,
  r.globalid                                     AS globalid,
  r.id_operacion                                 AS predio_id,
  r.numero_predial_nacional                      AS numero_predial,
  'Destinación '||r.destinacion_economica||
  ' sin CR_UnidadConstruccion asociada'          AS descripcion,
  COALESCE(u.n_uc, 0)                            AS valor,
  FALSE                                          AS cumple,
  NOW()                                          AS created_at,
  NOW()                                          AS updated_at
FROM req r
LEFT JOIN uc u
  ON btrim(r.id_operacion) = u.id_operacion_predio
WHERE COALESCE(u.n_uc, 0) = 0
ORDER BY r.objectid;

--regla 681
create table reglas.regla_381 as
-- Regla 681 (sin tabla de “Cancelación”): pos22 ∈ {1,5,6} => incumple
WITH p AS (
  SELECT
    objectid,
    id_operacion,
    globalid,
    numero_predial_nacional AS npn
  FROM preprod.ilc_predio
  WHERE numero_predial_nacional ~ '^[0-9]{30}$'   -- solo NPN válidos (30 dígitos)
)
SELECT
  '681'::text                                 AS regla,
  'ILC_Predio'::text                          AS objeto,
  'preprod.ilc_predio'::text                  AS tabla,
  p.objectid                                  AS objectid,
  p.globalid                                  AS globalid,
  p.id_operacion                              AS predio_id,
  p.npn                                       AS numero_predial,
  CASE
    WHEN substring(p.npn FROM 22 FOR 1) IN ('1','6')
      THEN 'NPN: campo22 no permitido (1 o 6)'
    ELSE
      'NPN: campo22=5 (sin excepción de Cancelación; no hay tabla de novedades)'
  END                                         AS descripcion,
  substring(p.npn FROM 22 FOR 1)              AS valor,     -- dígito real en la posición 22
  FALSE                                       AS cumple,
  NOW()                                       AS created_at,
  NOW()                                       AS updated_at
FROM p
WHERE substring(p.npn FROM 22 FOR 1) IN ('1','5','6')
ORDER BY p.objectid;

--regla 685
DROP TABLE IF EXISTS reglas.regla_685;
CREATE TABLE reglas.regla_685 AS
WITH agg AS (
  SELECT
    btrim(matricula_inmobiliaria) AS mi,
    COUNT(DISTINCT numero_predial_nacional) AS n_npn,
    ARRAY_AGG(DISTINCT numero_predial_nacional ORDER BY numero_predial_nacional) AS npn_distintos
  FROM preprod.ilc_predio
  WHERE matricula_inmobiliaria IS NOT NULL
    AND btrim(matricula_inmobiliaria) <> ''
  GROUP BY 1
  HAVING COUNT(DISTINCT numero_predial_nacional) > 1
),
viol AS (
  SELECT
    p.objectid,
    p.globalid,
    p.id_operacion,
    p.matricula_inmobiliaria,
    p.numero_predial_nacional,
    a.n_npn,
    a.npn_distintos
  FROM preprod.ilc_predio p
  JOIN agg a ON btrim(p.matricula_inmobiliaria) = a.mi
)
SELECT
  '685'::text                                 AS regla,
  'ILC_Predio'::text                          AS objeto,
  'preprod.ilc_predio'::text                  AS tabla,
  v.objectid                                  AS objectid,
  v.globalid                                  AS globalid,
  v.id_operacion                              AS predio_id,
  v.numero_predial_nacional                   AS numero_predial,
  'Matrícula '||v.matricula_inmobiliaria||
  ' asociada a '||v.n_npn||' NPN distintos: '||
  array_to_string(v.npn_distintos, ',')       AS descripcion,
  v.n_npn                                     AS valor,
  FALSE                                       AS cumple,
  NOW()                                       AS created_at,
  NOW()                                       AS updated_at
FROM viol v
ORDER BY v.matricula_inmobiliaria, v.objectid;

--regla 686
create table reglas.regla_686 as
-- Regla 686: Matricula_Inmobiliaria debe ser un número entre 1 y 9,999,999 (solo dígitos, 1–7 chars, no solo ceros)
WITH t AS (
  SELECT
    p.objectid,
    p.globalid,
    p.id_operacion,
    p.numero_predial_nacional,
    p.matricula_inmobiliaria,
    btrim(coalesce(p.matricula_inmobiliaria, '')) AS mi_trim
  FROM preprod.ilc_predio p
)
SELECT
  '686'::text                                        AS regla,
  'ILC_Predio'::text                                 AS objeto,
  'preprod.ilc_predio'::text                         AS tabla,
  t.objectid                                         AS objectid,
  t.globalid                                         AS globalid,
  t.id_operacion                                     AS predio_id,
  t.numero_predial_nacional                          AS numero_predial,
  CASE
    WHEN t.mi_trim = '' THEN 'Matrícula vacía o nula'
    WHEN t.mi_trim ~ '^0+$' THEN 'Matrícula con solo ceros (fuera de 1..9999999)'
    WHEN t.mi_trim !~ '^[0-9]{1,7}$' THEN 'Matrícula no es numérica de 1 a 7 dígitos'
  END                                                AS descripcion,
  t.matricula_inmobiliaria                           AS valor,
  FALSE                                              AS cumple,
  NOW()                                              AS created_at,
  NOW()                                              AS updated_at
FROM t
WHERE
  t.mi_trim = ''
  OR t.mi_trim ~ '^0+$'
  OR t.mi_trim !~ '^[0-9]{1,7}$'
ORDER BY t.objectid;

--regla 688
-- Regla 688: Para cada Matricula_Inmobiliaria (no vacía), Codigo_ORIP debe ser exactamente 3 dígitos.
DROP TABLE IF EXISTS reglas.regla_688;
CREATE TABLE reglas.regla_688 AS
WITH t AS (
  SELECT
    p.objectid,
    p.globalid,
    p.id_operacion,
    p.numero_predial_nacional,
    btrim(coalesce(p.matricula_inmobiliaria,'')) AS mi,
    btrim(coalesce(p.codigo_orip,''))            AS orip
  FROM preprod.ilc_predio p
),
viol AS (
  SELECT
    objectid, globalid, id_operacion, numero_predial_nacional, mi, orip,
    CASE
      WHEN orip = '' THEN 'Código_ORIP vacío (debe ser 3 dígitos)'
      WHEN orip !~ '^[0-9]{3}$' THEN 'Código_ORIP inválido: debe tener 3 dígitos [0-9]'
    END AS detalle
  FROM t
  WHERE mi <> ''                            -- aplica solo si hay matrícula
    AND (orip = '' OR orip !~ '^[0-9]{3}$') -- falla formato ORIP
)
SELECT
  '688'::text                                    AS regla,
  'ILC_Predio'::text                             AS objeto,
  'preprod.ilc_predio'::text                     AS tabla,
  v.objectid                                     AS objectid,
  v.globalid                                     AS globalid,
  v.id_operacion                                 AS predio_id,
  v.numero_predial_nacional                      AS numero_predial,
  ('Matrícula '||v.mi||': '||v.detalle)          AS descripcion,
  v.orip                                         AS valor,       -- ORIP actual
  FALSE                                          AS cumple,
  NOW()                                          AS created_at,
  NOW()                                          AS updated_at
FROM viol v
ORDER BY v.objectid;

--regla 689
create table reglas.regla_689 as
WITH req AS (  -- predios a los que NO se les permite UC
  SELECT
    p.objectid,
    p.globalid,
    p.id_operacion,
    p.numero_predial_nacional,
    lower(btrim(p.destinacion_economica)) AS de
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.destinacion_economica)) IN (
    'lote_urbanizable_no_construido',
    'lote_rural'
  )
),
uc AS (       
  SELECT btrim(id_operacion_predio) AS id_operacion_predio,
         COUNT(*) AS n_uc
  FROM preprod.cr_unidadconstruccion
  GROUP BY 1
)
SELECT
  '689'::text                                   AS regla,          -- pon el ID que uses
  'ILC_Predio'::text                            AS objeto,
  'preprod.ilc_predio'::text                    AS tabla,
  r.objectid                                    AS objectid,
  r.globalid                                    AS globalid,
  r.id_operacion                                AS predio_id,
  r.numero_predial_nacional                     AS numero_predial,
  'Destinación '||r.de||' NO debe tener UC asociada, pero tiene' AS descripcion,
  u.n_uc                                        AS valor,          -- cuántas UC tiene
  FALSE                                         AS cumple,
  NOW()                                         AS created_at,
  NOW()                                         AS updated_at
FROM req r
JOIN uc  u ON btrim(r.id_operacion) = u.id_operacion_predio
ORDER BY r.objectid;

--regla 690
DROP TABLE IF EXISTS reglas.regla_690;
CREATE TABLE reglas.regla_690 AS
WITH base AS (  -- predios con NPN válido y datos clave
  SELECT
    p.objectid,
    p.globalid,
    p.id_operacion,
    p.numero_predial_nacional AS npn,
    lower(btrim(p.destinacion_economica)) AS de,
    lower(btrim(p.condicion_predio))      AS cp
  FROM preprod.ilc_predio p
  WHERE p.numero_predial_nacional ~ '^[0-9]{30}$'
),
-- Conteo de Unidades de Construcción por predio (id_operacion)
uc AS (
  SELECT btrim(c.id_operacion_predio) AS id_operacion_predio,
         COUNT(*) AS n_uc
  FROM preprod.cr_unidadconstruccion c
  GROUP BY 1
),
-- Área de Terreno por predio (suma de áreas; calcula en SRID 9377).
-- Maneja SRID 0 (desconocido) asignándolo a 9377.
terr AS (
  SELECT
    btrim(t.id_operacion_predio) AS id_operacion_predio,
    SUM(
      CASE
        WHEN t.shape IS NULL THEN NULL
        WHEN ST_SRID(t.shape) = 9377 THEN ST_Area(t.shape)
        WHEN ST_SRID(t.shape) = 0    THEN ST_Area(ST_SetSRID(t.shape, 9377))
        ELSE ST_Area(ST_Transform(t.shape, 9377))
      END
    ) AS area_m2
  FROM preprod.cr_terreno t
  WHERE t.shape IS NOT NULL
  GROUP BY 1
),
eval AS (
  SELECT
    b.*,
    substring(b.npn FROM 6 FOR 2) AS d67,
    COALESCE(u.n_uc, 0)           AS n_uc,
    t.area_m2
  FROM base b
  LEFT JOIN uc   u ON btrim(b.id_operacion) = u.id_operacion_predio
  LEFT JOIN terr t ON btrim(b.id_operacion) = t.id_operacion_predio
),
-- Clasificación de bloques y chequeos (todo en minúsculas)
viol AS (
  SELECT
    e.*,
    -- grupos
    (e.de IN ('acuicola','agricola','agroindustrial','agropecuario','agroforestal',
              'forestal','infraestructura_asociada_produccion_agropecuaria',
              'infraestructura_saneamiento_basico','mineria_hidrocarburos','pecuario','lote_rural')) AS es_agro_rural,
    (e.de IN ('lote_urbanizable_no_urbanizado','lote_urbanizable_no_construido')) AS es_urbanizable,
    -- fallas por bloque
    CASE WHEN e.de <> 'lote_rural' THEN (e.d67 <> '00') ELSE FALSE END AS f_agro_d67,
    CASE WHEN e.de = 'lote_rural'  THEN (e.d67 <> '00') ELSE FALSE END AS f_lr_d67,
    CASE WHEN e.de = 'lote_rural'  THEN (e.n_uc > 0)    ELSE FALSE END AS f_lr_uc,
    CASE WHEN e.de = 'lote_rural'  THEN (e.cp IN ('ph_matriz','ph_unidad_predial','ph.unidad_predial',
                                                  'condominio_matriz','condominio_unidad_predial')) ELSE FALSE END AS f_lr_cond,
    CASE WHEN e.de = 'lote_rural'  THEN (e.area_m2 IS NULL OR e.area_m2 >= 500) ELSE FALSE END AS f_lr_area,
    -- urbanizable
    CASE WHEN e.de IN ('lote_urbanizable_no_urbanizado','lote_urbanizable_no_construido')
         THEN (e.d67 = '00') ELSE FALSE END AS f_urb_d67
  FROM eval e
),
-- Armar texto de motivo y conteo de fallas
out AS (
  SELECT
    v.*,
    (
      (v.f_agro_d67)::int +
      (v.f_lr_d67)::int +
      (v.f_lr_uc)::int +
      (v.f_lr_cond)::int +
      (v.f_lr_area)::int +
      (v.f_urb_d67)::int
    ) AS fail_count,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN v.f_agro_d67 THEN 'dígitos 6-7 <> 00 (agro-rural)' END,
      CASE WHEN v.f_lr_d67   THEN 'dígitos 6-7 <> 00 (lote_rural)' END,
      CASE WHEN v.f_lr_uc    THEN 'tiene UC asociada ('||v.n_uc||')' END,
      CASE WHEN v.f_lr_cond  THEN 'condición prohibida: '||v.cp END,
      CASE WHEN v.f_lr_area  THEN COALESCE('área terreno '||round(v.area_m2::numeric,2)||' m² (>= 500 o sin terreno)','sin terreno') END,
      CASE WHEN v.f_urb_d67  THEN 'dígitos 6-7 = 00 (urbanizable debe ser ≠ 00)' END
    )) AS motivo
  FROM viol v
)
SELECT
  '690'::text                                   AS regla,
  'ILC_Predio'::text                            AS objeto,
  'preprod.ilc_predio'::text                    AS tabla,
  o.objectid                                    AS objectid,
  o.globalid                                    AS globalid,
  o.id_operacion                                AS predio_id,
  o.npn                                         AS numero_predial,
  ('Destinación '||o.de||' incumple: '||o.motivo) AS descripcion,
  o.fail_count                                  AS valor,
  FALSE                                         AS cumple,
  NOW()                                         AS created_at,
  NOW()                                         AS updated_at
FROM out o
WHERE
  (o.es_agro_rural  AND (o.f_agro_d67 OR o.f_lr_d67 OR o.f_lr_uc OR o.f_lr_cond OR o.f_lr_area))
  OR
  (o.es_urbanizable AND o.f_urb_d67)
ORDER BY o.objectid;

--673

WITH base AS (
  SELECT
    p.objectid,
    p.id_operacion,
    p.numero_predial_nacional AS npn,
    substring(p.numero_predial_nacional FROM 19 FOR 3)::int AS a_num
  FROM preprod.ilc_predio p
  WHERE left(p.numero_predial_nacional, 17) = '13836000200000002'
    AND substring(p.numero_predial_nacional FROM 18 FOR 1) = 'A'
    AND substring(p.numero_predial_nacional FROM 19 FOR 3) ~ '^[0-9]{3}$'
),
ord AS (
  SELECT
    b.*,
    LAG(a_num) OVER (ORDER BY a_num) AS prev_a
  FROM base b
)
SELECT
  npn,
  'salto: falta A' || LPAD((prev_a + 1)::text,3,'0') ||
  CASE WHEN a_num - prev_a > 2
       THEN ' ... A' || LPAD((a_num - 1)::text,3,'0')
       ELSE ''
  END AS detalle
FROM ord
WHERE prev_a IS NOT NULL
  AND (a_num - prev_a) > 1
ORDER BY a_num;


--692

-- Regla 692: Consistencia ORIP/Matrícula vs Área_Registral_M2
-- Vacío = NULL o cadena vacía

DROP TABLE IF EXISTS reglas.regla_692;

CREATE TABLE reglas.regla_692 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    p.id_operacion,
    p.numero_predial_nacional        AS npn,
    p.codigo_orip,
    p.matricula_inmobiliaria,
    p.area_registral_m2,
    (p.codigo_orip IS NULL OR btrim(p.codigo_orip) = '')                       AS orip_vacia,
    (p.matricula_inmobiliaria IS NULL OR btrim(p.matricula_inmobiliaria) = '') AS mi_vacia
  FROM preprod.ilc_predio p
)

-- Caso 1: ORIP y Matrícula vacías → área debe ser exactamente 0
SELECT
  '692'::text                        AS regla,
  'ILC_Predio'::text                 AS objeto,
  'preprod.ilc_predio'::text         AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: Sin ORIP/Matrícula pero Área_Registral_M2 ≠ 0 (NULL también incumple)'::text AS descripcion,
  b.area_registral_m2                AS valor,
  FALSE                               AS cumple,
  NOW()                               AS created_at,
  NOW()                               AS updated_at
FROM base b
WHERE b.orip_vacia AND b.mi_vacia
  AND (b.area_registral_m2 IS NULL OR b.area_registral_m2 <> 0)

UNION ALL

-- Caso 2: Área > 0 → ORIP y Matrícula deben estar diligenciados
SELECT
  '692',
  'ILC_Predio',
  'preprod.ilc_predio',
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: Área_Registral_M2 > 0 pero falta ORIP y/o Matrícula',
  b.area_registral_m2,
  FALSE,
  NOW(),
  NOW()
FROM base b
WHERE COALESCE(b.area_registral_m2,0) > 0
  AND (b.orip_vacia OR b.mi_vacia)

UNION ALL

-- Caso 3: Con ORIP y Matrícula → área no puede ser 0, NULL ni vacío (' ')
SELECT
  '692',
  'ILC_Predio',
  'preprod.ilc_predio',
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: Con ORIP y Matrícula pero Área_Registral_M2 = 0 o NULL o vacío',
  b.area_registral_m2,
  FALSE,
  NOW(),
  NOW()
FROM base b
WHERE (NOT b.orip_vacia AND NOT b.mi_vacia)
  AND (b.area_registral_m2 IS NULL OR b.area_registral_m2 = 0 OR btrim(b.area_registral_m2::text) = '')

ORDER BY objectid;

-- Resumen opcional
SELECT descripcion, COUNT(*) FROM reglas.regla_692 GROUP BY descripcion ORDER BY 2 DESC;

---693
-- Regla 693: Relación entre CR_Terreno ↔ ILC_Predio (SIN NOVEDADES)
-- Valida que los predios con condición específica tengan exactamente 1 terreno,
-- salvo la excepción de predios informales en altura.

DROP TABLE IF EXISTS reglas.regla_693;

CREATE TABLE reglas.regla_693 AS
WITH base AS (
  SELECT 
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)              AS id_operacion,
    p.numero_predial_nacional          AS npn,
    p.condicion_predio,

    CASE 
      WHEN lower(btrim(p.condicion_predio)) IN (
        'nph', 'ph.matriz', 'ph_matriz',
        'condominio.matriz', 'condominio_matriz',
        'condominio.unidad_predial', 'condominio_unidad_predial',
        'via', 'vía',
        'bien_uso_publico', 'bien_uso_público',
        'parque_cementerio.matriz',
        'informal'
      )
      THEN TRUE ELSE FALSE 
    END AS es_condicion_validada,

    CASE 
      WHEN lower(btrim(p.condicion_predio)) = 'informal'
       AND substring(p.numero_predial_nacional FROM 22 FOR 1) = '2'
       AND substring(p.numero_predial_nacional FROM 27 FOR 4) <> '0000'
      THEN TRUE ELSE FALSE
    END AS es_informal_en_altura
  FROM preprod.ilc_predio p
),
join_terreno AS (
  SELECT 
    b.objectid,
    b.globalid,
    b.id_operacion,
    b.npn,
    b.condicion_predio,
    b.es_condicion_validada,
    b.es_informal_en_altura,
    COUNT(t.objectid) AS n_terrenos
  FROM base b
  LEFT JOIN preprod.cr_terreno t 
    ON btrim(t.id_operacion_predio) = btrim(b.id_operacion)
  GROUP BY b.objectid, b.globalid, b.id_operacion, b.npn, b.condicion_predio,
           b.es_condicion_validada, b.es_informal_en_altura
)

-- ==========================
-- INCUMPLIMIENTOS
-- ==========================
SELECT
  '693'::text                   AS regla,
  'ILC_Predio'::text            AS objeto,
  'preprod.ilc_predio'::text    AS tabla,
  j.objectid,
  j.globalid,
  j.id_operacion,
  j.npn,
  'INCUMPLE: condicion_predio=' || COALESCE(j.condicion_predio,'(null)') ||
  ', n_terrenos=' || COALESCE(j.n_terrenos::text,'(null)') ||
  ', informal_en_altura=' || (CASE WHEN j.es_informal_en_altura THEN 'true' ELSE 'false' END) AS descripcion,
  j.n_terrenos::text            AS valor,
  FALSE                         AS cumple,
  NOW()                         AS created_at,
  NOW()                         AS updated_at
FROM join_terreno j
WHERE
      (j.es_condicion_validada AND NOT j.es_informal_en_altura AND j.n_terrenos <> 1)
   OR (NOT j.es_condicion_validada AND j.n_terrenos > 0)
   OR (j.es_informal_en_altura AND j.n_terrenos > 1)

ORDER BY j.id_operacion, j.npn;



select descripcion from
reglas.regla_693
group by descripcion


-- regla 675
-- Regla 675: Validar consistencia Rural (posiciones 6–7 = "00")
-- Si es Rural, posiciones 10–13 deben ser "0000"

DROP TABLE IF EXISTS reglas.regla_675;

CREATE TABLE reglas.regla_675 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)       AS id_operacion,
    p.numero_predial_nacional   AS npn,
    substring(p.numero_predial_nacional FROM 6 FOR 2)  AS npn_6_7,
    substring(p.numero_predial_nacional FROM 10 FOR 4) AS npn_10_13
  FROM preprod.ilc_predio p
)
SELECT
  '675'::text                AS regla,
  'ILC_Predio'::text         AS objeto,
  'preprod.ilc_predio'::text AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: Predio con posiciones 6–7 = "00" (Rural) pero posiciones 10–13 <> "0000"' AS descripcion,
  'npn_6_7='||b.npn_6_7||', npn_10_13='||b.npn_10_13 AS valor,
  FALSE                     AS cumple,
  NOW()                     AS created_at,
  NOW()                     AS updated_at
FROM base b
WHERE b.npn_6_7 = '00'
  AND b.npn_10_13 <> '0000'
ORDER BY b.id_operacion, b.npn;

-- Regla 713: Solo una dirección principal por predio cuando hay múltiples direcciones

DROP TABLE IF EXISTS reglas.regla_713;

CREATE TABLE reglas.regla_713 AS
WITH dir_agregada AS (
  SELECT
    btrim(e.id_operacion_predio) AS id_operacion,
    COUNT(*)                     AS n_direcciones,
    SUM(
      CASE
        -- Normalizamos la marca de principal: Si/Sí/1/true/t (cualquier casing y espacios)
        WHEN lower(btrim(e.es_direccion_principal)) IN ('si','sí','s','true','t','1') THEN 1
        ELSE 0
      END
    ) AS n_principal
  FROM preprod.extdireccion e
  GROUP BY 1
),
pred AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)       AS id_operacion,
    p.numero_predial_nacional   AS npn
  FROM preprod.ilc_predio p
)
SELECT
  '713'::text                   AS regla,
  'ILC_Predio'::text            AS objeto,
  'preprod.extdireccion'::text  AS tabla,
  pr.objectid,
  pr.globalid,
  d.id_operacion,
  pr.npn,
  CASE
    WHEN d.n_principal = 0 THEN
      'INCUMPLE: predio con múltiples direcciones pero ninguna principal'
    WHEN d.n_principal > 1 THEN
      'INCUMPLE: predio con múltiples direcciones y más de una principal ('||d.n_principal||')'
  END                           AS descripcion,
  ('n_direcciones='||d.n_direcciones||', n_principal='||d.n_principal) AS valor,
  FALSE                         AS cumple,
  NOW()                         AS created_at,
  NOW()                         AS updated_at
FROM dir_agregada d
LEFT JOIN pred pr ON pr.id_operacion = d.id_operacion
WHERE d.n_direcciones > 1         -- solo aplica si tiene más de una dirección
  AND d.n_principal <> 1          -- exactamente una debe ser principal
ORDER BY d.id_operacion;

---- Regla 707: Dirección Estructurada bien diligenciada

DROP TABLE IF EXISTS reglas.regla_707;

CREATE TABLE reglas.regla_707 AS
WITH base AS (
  SELECT
    e.objectid,
    e.globalid,
    btrim(e.id_operacion_predio)             AS id_operacion,
    lower(btrim(e.tipo_direccion))           AS tipo_dir,
    e.clase_via_principal,
    e.valor_via_principal,
    e.valor_via_generadora,
    e.numero_predio,
    e.nombre_predio
  FROM preprod.extdireccion e
),
pred AS (
  SELECT
    btrim(p.id_operacion) AS id_operacion,
    p.numero_predial_nacional AS npn
  FROM preprod.ilc_predio p
),
chk AS (
  SELECT
    b.*,
    -- Campos obligatorios (texto no vacío, numérico no nulo/0)
    (b.clase_via_principal IS NOT NULL AND btrim(b.clase_via_principal) <> '') AS ok_clase,
    (b.valor_via_principal   IS NOT NULL AND b.valor_via_principal   <> 0)     AS ok_vvp,
    (b.valor_via_generadora  IS NOT NULL AND b.valor_via_generadora  <> 0)     AS ok_vvg,
    (b.numero_predio         IS NOT NULL AND b.numero_predio         <> 0)     AS ok_num,
    -- Campo prohibido
    (b.nombre_predio IS NULL OR btrim(b.nombre_predio) = '')                    AS ok_nombre
  FROM base b
  WHERE b.tipo_dir = 'estructurada'
),
viol AS (
  SELECT
    c.*,
    -- construir motivo con las piezas que incumplen
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT c.ok_clase  THEN 'falta Clase_Via_Principal' END,
      CASE WHEN NOT c.ok_vvp    THEN 'falta Valor_Via_Principal' END,
      CASE WHEN NOT c.ok_vvg    THEN 'falta Valor_Via_Generadora' END,
      CASE WHEN NOT c.ok_num    THEN 'falta Numero_Predio' END,
      CASE WHEN NOT c.ok_nombre THEN 'Nombre_Predio debe ser vacío/NULL' END
    )) AS motivo
  FROM chk c
  WHERE NOT (c.ok_clase AND c.ok_vvp AND c.ok_vvg AND c.ok_num AND c.ok_nombre)
)
SELECT
  '707'::text                     AS regla,
  'EXTDireccion'::text            AS objeto,
  'preprod.extdireccion'::text    AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  p.npn,
  ('INCUMPLE: Dirección Estructurada → '||v.motivo)::text AS descripcion,
  -- Valor informativo con snapshot de campos clave
  (
    'clase_via_principal='||COALESCE(v.clase_via_principal,'(NULL)')
    ||', valor_via_principal='||COALESCE(v.valor_via_principal::text,'(NULL)')
    ||', valor_via_generadora='||COALESCE(v.valor_via_generadora::text,'(NULL)')
    ||', numero_predio='||COALESCE(v.numero_predio::text,'(NULL)')
    ||', nombre_predio='||COALESCE(NULLIF(btrim(v.nombre_predio),''),'(vacío)')
  )::text                        AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
LEFT JOIN pred p ON p.id_operacion = v.id_operacion
ORDER BY v.id_operacion, v.objectid;



-- Regla 708: Dirección No Estructurada bien diligenciada

DROP TABLE IF EXISTS reglas.regla_708;

CREATE TABLE reglas.regla_708 AS
WITH base AS (
  SELECT
    e.objectid,
    e.globalid,
    btrim(e.id_operacion_predio)             AS id_operacion,
    lower(btrim(e.tipo_direccion))           AS tipo_dir,
    e.clase_via_principal,
    e.valor_via_principal,
    e.valor_via_generadora,
    e.numero_predio,
    e.nombre_predio
  FROM preprod.extdireccion e
),
pred AS (
  SELECT
    btrim(p.id_operacion) AS id_operacion,
    p.numero_predial_nacional AS npn
  FROM preprod.ilc_predio p
),
chk AS (
  SELECT
    b.*,
    -- único campo permitido
    (b.nombre_predio IS NOT NULL AND btrim(b.nombre_predio) <> '') AS ok_nombre,
    -- campos prohibidos (deben ir vacíos o NULL)
    (b.clase_via_principal IS NULL OR btrim(b.clase_via_principal) = '') AS ok_clase,
    (b.valor_via_principal IS NULL OR b.valor_via_principal = 0)         AS ok_vvp,
    (b.valor_via_generadora IS NULL OR b.valor_via_generadora = 0)       AS ok_vvg,
    (b.numero_predio IS NULL OR b.numero_predio = 0)                     AS ok_num
  FROM base b
  WHERE b.tipo_dir = 'no_estructurada'
),
viol AS (
  SELECT
    c.*,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT c.ok_nombre THEN 'Nombre_Predio debe estar diligenciado' END,
      CASE WHEN NOT c.ok_clase  THEN 'Clase_Via_Principal debe ser NULL/vacío' END,
      CASE WHEN NOT c.ok_vvp    THEN 'Valor_Via_Principal debe ser NULL/0' END,
      CASE WHEN NOT c.ok_vvg    THEN 'Valor_Via_Generadora debe ser NULL/0' END,
      CASE WHEN NOT c.ok_num    THEN 'Numero_Predio debe ser NULL/0' END
    )) AS motivo
  FROM chk c
  WHERE NOT (c.ok_nombre AND c.ok_clase AND c.ok_vvp AND c.ok_vvg AND c.ok_num)
)
SELECT
  '708'::text                     AS regla,
  'EXTDireccion'::text            AS objeto,
  'preprod.extdireccion'::text    AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  p.npn,
  ('INCUMPLE: Dirección No Estructurada → '||v.motivo)::text AS descripcion,
  (
    'nombre_predio='||COALESCE(v.nombre_predio,'(NULL)')
    ||', clase_via_principal='||COALESCE(v.clase_via_principal,'(NULL)')
    ||', valor_via_principal='||COALESCE(v.valor_via_principal::text,'(NULL)')
    ||', valor_via_generadora='||COALESCE(v.valor_via_generadora::text,'(NULL)')
    ||', numero_predio='||COALESCE(v.numero_predio::text,'(NULL)')
  )::text AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
LEFT JOIN pred p ON p.id_operacion = v.id_operacion
ORDER BY v.id_operacion, v.objectid;

-- Regla 716: Longitud máxima de Nombre_Predio

DROP TABLE IF EXISTS reglas.regla_716;

CREATE TABLE reglas.regla_716 AS
WITH base AS (
  SELECT
    e.objectid,
    e.globalid,
    btrim(e.id_operacion_predio)     AS id_operacion,
    e.nombre_predio,
    length(e.nombre_predio)          AS longitud
  FROM preprod.extdireccion e
  WHERE e.nombre_predio IS NOT NULL AND btrim(e.nombre_predio) <> ''
),
viol AS (
  SELECT
    b.*,
    'INCUMPLE: Nombre_Predio supera los 49 caracteres (longitud='
    || b.longitud || ')' AS motivo
  FROM base b
  WHERE b.longitud > 49
)
SELECT
  '716'::text                     AS regla,
  'EXTDireccion'::text            AS objeto,
  'preprod.extdireccion'::text    AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  NULL::text                      AS npn,
  v.motivo                        AS descripcion,
  v.nombre_predio                 AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
ORDER BY v.id_operacion, v.objectid;

-- Regla 717: Coherencia NPN (dígitos 6–7) vs tipo de dirección
-- Si d6-7 <> '00' (no rural)  → la(s) dirección(es) deben ser Estructuradas.
-- Si d6-7  = '00' (rural)     → la(s) dirección(es) deben ser No_Estructuradas.
-- EXCEPCIÓN: rurales en zonas de comportamiento urbano o centros poblados rurales
--            (se pueden excluir vía CTE `excepciones` cuando tengas el insumo).

DROP TABLE IF EXISTS reglas.regla_717;

CREATE TABLE reglas.regla_717 AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                  AS id_operacion,
    p.numero_predial_nacional              AS npn,
    substring(p.numero_predial_nacional FROM 6 FOR 2) AS d67
  FROM preprod.ilc_predio p
  WHERE p.numero_predial_nacional IS NOT NULL
),
-- Normalizamos tipo_direccion y agregamos por predio
dir_agg AS (
  SELECT
    btrim(e.id_operacion_predio) AS id_operacion,
    COUNT(*)                     AS n_dir,
    SUM( CASE WHEN lower(btrim(e.tipo_direccion)) IN ('estructurada','estructurada ') THEN 1 ELSE 0 END ) AS n_estructurada,
    SUM( CASE WHEN lower(btrim(e.tipo_direccion)) IN ('no_estructurada','no estructurada','no-estructurada') THEN 1 ELSE 0 END ) AS n_no_estructurada
  FROM preprod.extdireccion e
  GROUP BY 1
),
excepciones AS (
  SELECT DISTINCT id_operacion
  FROM (VALUES
    -- ('<id_operacion_predio_1>'),
    -- ('<id_operacion_predio_2>')
    ('__none__')  -- placeholder para que el CTE no sea vacío
  ) AS x(id_operacion)
),
eval AS (
  SELECT
    pr.objectid,
    pr.globalid,
    pr.id_operacion,
    pr.npn,
    pr.d67,
    COALESCE(da.n_dir,0)           AS n_dir,
    COALESCE(da.n_estructurada,0)  AS n_estructurada,
    COALESCE(da.n_no_estructurada,0) AS n_no_estructurada,
    (pr.d67 = '00')  AS es_rural,
    (pr.d67 <> '00') AS es_no_rural,
    -- Está en la lista de excepciones
    (EXISTS (SELECT 1 FROM excepciones ex WHERE ex.id_operacion = pr.id_operacion)) AS es_excepcion_rural
  FROM predio pr
  LEFT JOIN dir_agg da ON da.id_operacion = pr.id_operacion
),
viol AS (
  SELECT
    e.*,
    CASE
      -- NO RURAL: todas deben ser Estructuradas (si existen direcciones)
      WHEN e.es_no_rural AND e.n_dir > 0 AND e.n_no_estructurada > 0
        THEN 'INCUMPLE: d6-7<>"00" ⇒ dirección debe ser Estructurada; se encontró No_Estructurada'
      -- RURAL (sin excepción): todas deben ser No_Estructuradas (si existen direcciones)
      WHEN e.es_rural AND NOT e.es_excepcion_rural AND e.n_dir > 0 AND e.n_estructurada > 0
        THEN 'INCUMPLE: d6-7="00" ⇒ dirección debe ser No_Estructurada; se encontró Estructurada'

      ELSE NULL
    END AS motivo
  FROM eval e
  WHERE
        (e.es_no_rural AND e.n_dir > 0 AND e.n_no_estructurada > 0)
     OR (e.es_rural AND NOT e.es_excepcion_rural AND e.n_dir > 0 AND e.n_estructurada > 0)
     -- OR (e.n_dir = 0)  -- activar si la regla exige que todo predio tenga dirección
)
SELECT
  '717'::text                 AS regla,
  'EXTDireccion'::text        AS objeto,
  'preprod.extdireccion'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  v.motivo                    AS descripcion,
  ('d67='||v.d67||', n_dir='||v.n_dir||
   ', n_estructurada='||v.n_estructurada||
   ', n_no_estructurada='||v.n_no_estructurada)::text AS valor,
  FALSE                       AS cumple,
  NOW()                       AS created_at,
  NOW()                       AS updated_at
FROM viol v
ORDER BY v.id_operacion, v.npn;

-- Regla 676: Campos 22-30 del NPN en predios PH_Matriz deben ser "900000000"

DROP TABLE IF EXISTS reglas.regla_676;

CREATE TABLE reglas.regla_676 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)          AS id_operacion,
    p.numero_predial_nacional      AS npn,
    lower(btrim(p.condicion_predio)) AS condicion_predio,
    substring(p.numero_predial_nacional FROM 22 FOR 9) AS npn_22_30
  FROM preprod.ilc_predio p
  WHERE p.numero_predial_nacional IS NOT NULL
)
SELECT
  '676'::text                     AS regla,
  'ILC_Predio'::text              AS objeto,
  'preprod.ilc_predio'::text      AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: predios con condición PH_Matriz deben tener posiciones 22-30 del NPN = "900000000"'::text AS descripcion,
  b.npn_22_30                     AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM base b
WHERE b.condicion_predio IN ('ph.matriz','ph_matriz','ph matriz')
  AND b.npn_22_30 <> '900000000'
ORDER BY b.id_operacion, b.npn;

-- Regla 725 (final): Complemento obligatorio en unidades

DROP TABLE IF EXISTS reglas.regla_725;

CREATE TABLE reglas.regla_725 AS
WITH unidades AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)             AS id_operacion,
    p.numero_predial_nacional         AS npn,
    lower(btrim(p.condicion_predio))  AS cp
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN (
    'ph.unidad_predial','ph_unidad_predial',
    'condominio.unidad_predial','condominio_unidad_predial'
  )
),
dir_token AS (
  SELECT
    e.id_operacion_predio             AS id_operacion,
    e.objectid                        AS dir_oid,
    unnest(
      regexp_split_to_array(upper(COALESCE(e.complemento,'')), '[^A-Z0-9]+')
    ) AS tok
  FROM preprod.extdireccion e
),
-- Filtramos solo tokens no vacíos
dir_norm AS (
  SELECT
    id_operacion,
    dir_oid,
    tok
  FROM dir_token
  WHERE tok <> ''
),
-- Evaluamos por predio
dir_eval AS (
  SELECT
    id_operacion,
    COUNT(DISTINCT dir_oid) AS n_dir,
    BOOL_OR(tok = ANY(ARRAY[
      'AP','BQ','BD','CS','ED','ET','GA','IN','L','LO','MZ','OF','PQ','PN','TO','UN','UR'
    ])) AS tiene_codigo,
    ARRAY_AGG(DISTINCT tok) FILTER (
      WHERE tok = ANY(ARRAY[
        'AP','BQ','BD','CS','ED','ET','GA','IN','L','LO','MZ','OF','PQ','PN','TO','UN','UR'
      ])
    ) AS codigos_encontrados
  FROM dir_norm
  GROUP BY id_operacion
),
eval AS (
  SELECT
    u.objectid, u.globalid, u.id_operacion, u.npn, u.cp,
    COALESCE(de.n_dir, 0)                           AS n_dir,
    COALESCE(de.tiene_codigo, FALSE)                AS tiene_codigo,
    COALESCE(de.codigos_encontrados, ARRAY[]::text[]) AS codigos_encontrados
  FROM unidades u
  LEFT JOIN dir_eval de ON de.id_operacion = u.id_operacion
)
-- Solo incumplimientos
SELECT
  '725'::text                      AS regla,
  'EXTDireccion'::text             AS objeto,
  'preprod.extdireccion'::text     AS tabla,
  e.objectid,
  e.globalid,
  e.id_operacion,
  e.npn,
  CASE
    WHEN e.n_dir = 0 THEN
      'INCUMPLE: unidad sin direcciones asociadas (se requiere al menos una con código de complemento)'
    WHEN e.tiene_codigo = FALSE THEN
      'INCUMPLE: ninguna dirección asociada contiene código de complemento permitido (AP,BQ,BD,CS,ED,ET,GA,IN,L,LO,MZ,OF,PQ,PN,TO,UN,UR)'
  END AS descripcion,
  (
    'n_dir='||e.n_dir||', codigos_encontrados='||
    CASE
      WHEN array_length(e.codigos_encontrados,1) IS NULL THEN '(ninguno)'
      ELSE array_to_string(e.codigos_encontrados, '|')
    END
  )::text                          AS valor,
  FALSE                            AS cumple,
  NOW()                            AS created_at,
  NOW()                            AS updated_at
FROM eval e
WHERE e.n_dir = 0 OR e.tiene_codigo = FALSE
ORDER BY e.id_operacion, e.objectid;



-- Regla 677: Validación de NPN para PH_Unidad_Predial

DROP TABLE IF EXISTS reglas.regla_677;

CREATE TABLE reglas.regla_677 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                AS id_operacion,
    p.numero_predial_nacional            AS npn,
    lower(btrim(p.condicion_predio))     AS cp,
    -- Segmentos del NPN (1-indexado)
    substring(p.numero_predial_nacional FROM 22 FOR 1) AS s22,
    substring(p.numero_predial_nacional FROM 23 FOR 2) AS s23_24,
    substring(p.numero_predial_nacional FROM 25 FOR 2) AS s25_26,
    substring(p.numero_predial_nacional FROM 27 FOR 4) AS s27_30,
    -- Formato general (30 dígitos)
    (p.numero_predial_nacional ~ '^[0-9]{30}$')        AS ok_formato
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN
    ('ph.unidad_predial','ph_unidad_predial','ph unidad predial')
),
viol AS (
  SELECT
    b.*,
    -- Chequeos de regla
    (b.ok_formato AND b.s22     = '9')       AS ok_22,
    (b.ok_formato AND b.s23_24 <> '00')      AS ok_23_24,
    (b.ok_formato AND b.s25_26 <> '00')      AS ok_25_26,
    (b.ok_formato AND b.s27_30 <> '0000')    AS ok_27_30,
    -- Motivo detallado (concatena todas las fallas)
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT b.ok_formato THEN 'formato inválido: NPN debe tener 30 dígitos' END,
      CASE WHEN b.ok_formato AND NOT (b.s22 = '9') THEN 'pos22≠9' END,
      CASE WHEN b.ok_formato AND NOT (b.s23_24 <> '00') THEN 'pos23-24="00"' END,
      CASE WHEN b.ok_formato AND NOT (b.s25_26 <> '00') THEN 'pos25-26="00"' END,
      CASE WHEN b.ok_formato AND NOT (b.s27_30 <> '0000') THEN 'pos27-30="0000"' END
    )) AS motivo
  FROM base b
)
SELECT
  '677'::text                    AS regla,
  'ILC_Predio'::text             AS objeto,
  'preprod.ilc_predio'::text     AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  ('INCUMPLE: PH_Unidad_Predial → '||v.motivo)::text AS descripcion,
  (
    's22='||COALESCE(v.s22,'(null)')||
    ', s23_24='||COALESCE(v.s23_24,'(null)')||
    ', s25_26='||COALESCE(v.s25_26,'(null)')||
    ', s27_30='||COALESCE(v.s27_30,'(null)')
  )::text                         AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
WHERE
     NOT v.ok_formato
  OR NOT v.ok_22
  OR NOT v.ok_23_24
  OR NOT v.ok_25_26
  OR NOT v.ok_27_30
ORDER BY v.id_operacion, v.npn;

-- Regla 676: Validación de NPN para PH.Matriz


DROP TABLE IF EXISTS reglas.regla_676;

CREATE TABLE reglas.regla_676 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                AS id_operacion,
    p.numero_predial_nacional            AS npn,
    lower(btrim(p.condicion_predio))     AS cp,
    -- Segmentos del NPN (1-indexado)
    substring(p.numero_predial_nacional FROM 22 FOR 1) AS s22,
    substring(p.numero_predial_nacional FROM 23 FOR 8) AS s23_30,
    (p.numero_predial_nacional ~ '^[0-9]{30}$')        AS ok_formato
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN
    ('ph.matriz','ph_matriz','ph matriz')
),
viol AS (
  SELECT
    b.*,
    (b.ok_formato AND b.s22 = '9')            AS ok_22,
    (b.ok_formato AND b.s23_30 = '00000000')  AS ok_23_30,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT b.ok_formato THEN 'formato inválido: NPN debe tener 30 dígitos' END,
      CASE WHEN b.ok_formato AND NOT (b.s22 = '9') THEN 'pos22≠9' END,
      CASE WHEN b.ok_formato AND NOT (b.s23_30 = '00000000') THEN 'pos23-30≠00000000' END
    )) AS motivo
  FROM base b
)
SELECT
  '676'::text                    AS regla,
  'ILC_Predio'::text             AS objeto,
  'preprod.ilc_predio'::text     AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  ('INCUMPLE: PH.Matriz → '||v.motivo)::text AS descripcion,
  (
    's22='||COALESCE(v.s22,'(null)')||
    ', s23_30='||COALESCE(v.s23_30,'(null)')
  )::text                         AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
WHERE
     NOT v.ok_formato
  OR NOT v.ok_22
  OR NOT v.ok_23_30
ORDER BY v.id_operacion, v.npn;

-- Regla 678: NPN para Parque_Cementerio.Unidad_Predial


DROP TABLE IF EXISTS reglas.regla_678;

CREATE TABLE reglas.regla_678 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                AS id_operacion,
    p.numero_predial_nacional            AS npn,
    lower(btrim(p.condicion_predio))     AS cp,
    -- segmentos del NPN (1-indexado)
    substring(p.numero_predial_nacional FROM 22 FOR 1) AS s22,
    substring(p.numero_predial_nacional FROM 23 FOR 2) AS s23_24,
    substring(p.numero_predial_nacional FROM 25 FOR 2) AS s25_26,
    substring(p.numero_predial_nacional FROM 27 FOR 4) AS s27_30,
    -- formato general (30 dígitos)
    (p.numero_predial_nacional ~ '^[0-9]{30}$')        AS ok_formato
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN
    ('parque_cementerio.unidad_predial','parque_cementerio_unidad_predial')
),
viol AS (
  SELECT
    b.*,
    -- checks por regla
    (b.ok_formato AND b.s22     = '7')       AS ok_22,
    (b.ok_formato AND b.s23_24 <> '00')      AS ok_23_24,
    (b.ok_formato AND b.s25_26 <> '00')      AS ok_25_26,
    (b.ok_formato AND b.s27_30 <> '0000')    AS ok_27_30,
    -- motivo detallado
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT b.ok_formato THEN 'formato inválido: NPN debe tener 30 dígitos' END,
      CASE WHEN b.ok_formato AND b.s22 <> '7'      THEN 'pos22≠7' END,
      CASE WHEN b.ok_formato AND b.s23_24 = '00'   THEN 'pos23-24="00"' END,
      CASE WHEN b.ok_formato AND b.s25_26 = '00'   THEN 'pos25-26="00"' END,
      CASE WHEN b.ok_formato AND b.s27_30 = '0000' THEN 'pos27-30="0000"' END
    )) AS motivo
  FROM base b
)
SELECT
  '678'::text                    AS regla,
  'ILC_Predio'::text             AS objeto,
  'preprod.ilc_predio'::text     AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  ('INCUMPLE: Parque_Cementerio.Unidad_Predial → '||v.motivo)::text AS descripcion,
  (
    's22='||COALESCE(v.s22,'(null)')||
    ', s23_24='||COALESCE(v.s23_24,'(null)')||
    ', s25_26='||COALESCE(v.s25_26,'(null)')||
    ', s27_30='||COALESCE(v.s27_30,'(null)')
  )::text                         AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
WHERE
     NOT v.ok_formato
  OR NOT v.ok_22
  OR NOT v.ok_23_24
  OR NOT v.ok_25_26
  OR NOT v.ok_27_30
ORDER BY v.id_operacion, v.npn;

-- Regla 679: NPN para Condominio.Matriz → posiciones 22–30 = "800000000"

DROP TABLE IF EXISTS reglas.regla_679;

CREATE TABLE reglas.regla_679 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                    AS id_operacion,
    p.numero_predial_nacional                AS npn,
    lower(btrim(p.condicion_predio))         AS cp,
    substring(p.numero_predial_nacional FROM 22 FOR 9) AS s22_30,
    substring(p.numero_predial_nacional FROM 22 FOR 1) AS s22,
    substring(p.numero_predial_nacional FROM 23 FOR 8) AS s23_30,
    (p.numero_predial_nacional ~ '^[0-9]{30}$')        AS ok_formato
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN ('condominio.matriz','condominio_matriz','condominio matriz')
),
viol AS (
  SELECT
    b.*,
    (b.ok_formato AND b.s22_30 = '800000000') AS ok_bloque,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT b.ok_formato THEN 'formato inválido: NPN debe tener 30 dígitos' END,
      CASE WHEN b.ok_formato AND b.s22_30 <> '800000000' THEN 'pos22-30≠800000000' END
    )) AS motivo
  FROM base b
)
SELECT
  '679'::text                    AS regla,
  'ILC_Predio'::text             AS objeto,
  'preprod.ilc_predio'::text     AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  ('INCUMPLE: Condominio.Matriz → '||v.motivo)::text AS descripcion,
  (
    's22='||COALESCE(v.s22,'(null)')||
    ', s23_30='||COALESCE(v.s23_30,'(null)')||
    ', s22_30='||COALESCE(v.s22_30,'(null)')
  )::text                       AS valor,
  FALSE                         AS cumple,
  NOW()                         AS created_at,
  NOW()                         AS updated_at
FROM viol v
WHERE NOT v.ok_formato OR NOT v.ok_bloque
ORDER BY v.id_operacion, v.npn;

-- Regla 680: NPN para Condominio.Unidad_Predial


DROP TABLE IF EXISTS reglas.regla_680;

CREATE TABLE reglas.regla_680 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                       AS id_operacion,
    p.numero_predial_nacional                   AS npn,
    lower(btrim(p.condicion_predio))            AS cp,
    substring(p.numero_predial_nacional FROM 22 FOR 5)  AS s22_26,
    substring(p.numero_predial_nacional FROM 27 FOR 4)  AS s27_30,
    (p.numero_predial_nacional ~ '^[0-9]{30}$') AS ok_formato
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN ('condominio.unidad_predial','condominio_unidad_predial')
),
viol AS (
  SELECT
    b.*,
    (b.ok_formato AND b.s22_26 = '80000' AND b.s27_30 <> '0000') AS ok_bloque,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT b.ok_formato THEN 'formato inválido: NPN debe tener 30 dígitos' END,
      CASE WHEN b.ok_formato AND b.s22_26 <> '80000' THEN 'pos22-26≠80000' END,
      CASE WHEN b.ok_formato AND b.s27_30 = '0000' THEN 'pos27-30=0000' END
    )) AS motivo
  FROM base b
)
SELECT
  '680'::text                        AS regla,
  'ILC_Predio'::text                 AS objeto,
  'preprod.ilc_predio'::text         AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  ('INCUMPLE: Condominio.Unidad_Predial → '||v.motivo)::text AS descripcion,
  (
    's22_26='||COALESCE(v.s22_26,'(null)')||
    ', s27_30='||COALESCE(v.s27_30,'(null)')
  )::text                           AS valor,
  FALSE                             AS cumple,
  NOW()                             AS created_at,
  NOW()                             AS updated_at
FROM viol v
WHERE NOT v.ok_formato OR NOT v.ok_bloque
ORDER BY v.id_operacion, v.npn;

-- Regla 729 (ajustada): Fecha_Inicio_Tenencia según d6-7 del NPN
-- Dominio + Matrícula vacía ('' o solo espacios) + d6-7='00'  =>  1936-12-04
-- Dominio + Matrícula vacía ('' o solo espacios) + d6-7 in 01..99 => 1959-12-31

DROP TABLE IF EXISTS reglas.regla_729;

CREATE TABLE reglas.regla_729 AS
WITH predio AS (
  SELECT
    p.objectid                          AS predio_oid,
    p.globalid                          AS predio_gid,
    btrim(p.id_operacion)               AS id_operacion_predio,
    p.numero_predial_nacional           AS npn,
    substring(p.numero_predial_nacional FROM 6 FOR 2) AS d67,
    p.matricula_inmobiliaria
  FROM preprod.ilc_predio p
),
derecho AS (
  SELECT
    btrim(d.id_operacion_predio)        AS id_operacion_predio,
    d.objectid                          AS der_oid,
    d.globalid                          AS der_gid,
    d.tipo,
    (d.fecha_inicio_tenencia)::date     AS fecha_inicio_tenencia
  FROM preprod.ilc_derecho d
),
base AS (
  SELECT
    pr.predio_oid,
    pr.predio_gid,
    pr.id_operacion_predio,
    pr.npn,
    pr.d67,
    pr.matricula_inmobiliaria,
    dr.der_oid,
    dr.der_gid,
    dr.tipo,
    dr.fecha_inicio_tenencia
  FROM predio pr
  JOIN derecho dr
    ON dr.id_operacion_predio = pr.id_operacion_predio
),
filtro AS (
  SELECT
    b.*,
    -- Dominio
    (lower(btrim(b.tipo)) = 'dominio') AS es_dominio,
    -- Matrícula "vacía": NULL o solo espacios/cadena vacía
    (b.matricula_inmobiliaria IS NULL OR btrim(b.matricula_inmobiliaria) = '') AS mi_vacia,
    -- Clasificación d6-7
    (b.d67 = '00')                                        AS es_rural_00,
    (b.d67 ~ '^(0[1-9]|[1-9][0-9])$')                     AS es_urb_01_99,
    -- Fecha esperada
    CASE
      WHEN b.d67 = '00' THEN DATE '1936-12-04'
      WHEN b.d67 ~ '^(0[1-9]|[1-9][0-9])$' THEN DATE '1959-12-31'
      ELSE NULL
    END AS fecha_esperada
  FROM base b
),
viol AS (
  SELECT
    f.*,
    -- Aplica regla
    (f.es_dominio AND f.mi_vacia AND f.fecha_esperada IS NOT NULL) AS aplica_regla,
    -- Incumple si fecha es NULL o distinta a la esperada
    (f.es_dominio AND f.mi_vacia AND f.fecha_esperada IS NOT NULL
      AND (f.fecha_inicio_tenencia IS NULL OR f.fecha_inicio_tenencia <> f.fecha_esperada)
    ) AS incumple,
    CASE
      WHEN NOT (f.es_dominio AND f.mi_vacia AND f.fecha_esperada IS NOT NULL) THEN NULL
      WHEN f.fecha_inicio_tenencia IS NULL THEN
        'INCUMPLE: Fecha_Inicio_Tenencia es NULL; se esperaba '||to_char(f.fecha_esperada,'YYYY-MM-DD')
      WHEN f.fecha_inicio_tenencia <> f.fecha_esperada THEN
        'INCUMPLE: Fecha_Inicio_Tenencia='||to_char(f.fecha_inicio_tenencia,'YYYY-MM-DD')||
        '; se esperaba '||to_char(f.fecha_esperada,'YYYY-MM-DD')
    END AS motivo
  FROM filtro f
)
SELECT
  '729'::text                           AS regla,
  'ILC_Derecho'::text                   AS objeto,
  'preprod.ilc_derecho'::text           AS tabla,
  v.predio_oid                          AS objectid,
  v.predio_gid                          AS globalid,
  v.id_operacion_predio                 AS id_operacion,
  v.npn,
  COALESCE(v.motivo,'')::text           AS descripcion,
  (
    'tipo='||COALESCE(v.tipo,'(null)')||
    ', d67='||COALESCE(v.d67,'(null)')||
    ', fecha_actual='||COALESCE(to_char(v.fecha_inicio_tenencia,'YYYY-MM-DD'),'(null)')||
    ', fecha_esperada='||COALESCE(to_char(v.fecha_esperada,'YYYY-MM-DD'),'(null)')||
    ', matricula_vacia='||(CASE WHEN (v.matricula_inmobiliaria IS NULL OR btrim(v.matricula_inmobiliaria)='') THEN 'true' ELSE 'false' END)
  )::text                                AS valor,
  FALSE                                   AS cumple,
  NOW()                                   AS created_at,
  NOW()                                   AS updated_at
FROM viol v
WHERE v.aplica_regla AND v.incumple
ORDER BY v.id_operacion_predio, v.npn;

--regla 738

DROP TABLE IF EXISTS reglas.regla_738;

CREATE TABLE reglas.regla_738 AS
WITH predio AS (
  SELECT
    p.objectid                AS predio_oid,
    p.globalid                AS predio_gid,
    btrim(p.id_operacion)     AS id_operacion_predio,
    p.numero_predial_nacional AS npn,
    p.condicion_predio
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN (
    'ph_matriz',
    'condominio_matriz',
    'cementerio_matriz'
  )
),
interesado AS (
  SELECT
    i.objectid               AS int_oid,
    i.globalid               AS int_gid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    i.tipo                   AS tipo_interesado
  FROM preprod.ilc_interesado i
),
base AS (
  SELECT
    pr.predio_oid,
    pr.predio_gid,
    pr.id_operacion_predio,
    pr.npn,
    pr.condicion_predio,
    it.int_oid,
    it.int_gid,
    it.tipo_interesado
  FROM predio pr
  LEFT JOIN interesado it
    ON pr.id_operacion_predio = it.id_operacion_predio
)
SELECT
  'Predio_Matriz_Persona_Juridica'::text AS regla,
  'ILC_Predio / ILC_Interesado'::text    AS objeto,
  'preprod.ilc_predio'::text             AS tabla,
  b.predio_oid                           AS objectid,
  b.predio_gid                           AS globalid,
  b.id_operacion_predio                  AS id_operacion,
  b.npn,
  'INCUMPLE: Predio con condición '||b.condicion_predio||
  ' tiene interesado de tipo '||COALESCE(b.tipo_interesado,'(null)')||
  ' pero se requiere Persona_Juridica'   AS descripcion,
  (
    'condicion='||COALESCE(b.condicion_predio,'(null)')||
    ', tipo_interesado='||COALESCE(b.tipo_interesado,'(null)')
  )::text                                AS valor,
  FALSE                                   AS cumple,
  NOW()                                   AS created_at,
  NOW()                                   AS updated_at
FROM base b
WHERE b.tipo_interesado IS DISTINCT FROM 'Persona_Juridica'
ORDER BY b.npn;

-- Regla 739: Vía / Bien_Uso_Publico ⇒ Tipo de predio y Derecho Dominio

DROP TABLE IF EXISTS reglas.regla_739;

CREATE TABLE reglas.regla_739 AS
WITH pr AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                      AS id_operacion,
    p.numero_predial_nacional                  AS npn,
    lower(btrim(p.condicion_predio))           AS cp,
    btrim(p.tipo)                               AS tipo_predio
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN ('via','vía','bien_uso_publico','bien_uso_público')
),
der AS (
  SELECT
    btrim(d.id_operacion_predio) AS id_operacion,
    COUNT(*)                     AS n_derechos,
    SUM( CASE WHEN lower(btrim(d.tipo)) = 'dominio' THEN 1 ELSE 0 END ) AS n_dominio
  FROM preprod.ilc_derecho d
  GROUP BY 1
),
eval AS (
  SELECT
    pr.objectid,
    pr.globalid,
    pr.id_operacion,
    pr.npn,
    pr.cp,
    pr.tipo_predio,
    COALESCE(der.n_derechos,0) AS n_derechos,
    COALESCE(der.n_dominio,0)  AS n_dominio,
    -- checks
    (lower(COALESCE(pr.tipo_predio,'')) = 'predio.publico.uso_publico') AS ok_tipo_predio,
    (COALESCE(der.n_dominio,0) > 0)                                     AS ok_dominio
  FROM pr
  LEFT JOIN der ON der.id_operacion = pr.id_operacion
),
viol AS (
  SELECT
    e.*,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN NOT e.ok_tipo_predio THEN 'Tipo de predio debe ser "Predio.Publico.Uso_Publico"' END,
      CASE WHEN NOT e.ok_dominio     THEN 'Debe existir al menos un Derecho con tipo "Dominio"' END
    )) AS motivo
  FROM eval e
  WHERE (NOT e.ok_tipo_predio) OR (NOT e.ok_dominio)
)
SELECT
  '739'::text                   AS regla,
  'ILC_Predio / ILC_Derecho'::text AS objeto,
  'preprod.ilc_predio'::text    AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion,
  v.npn,
  ('INCUMPLE: '||v.motivo)::text AS descripcion,
  (
    'condicion='||v.cp||
    ', tipo_predio='||COALESCE(v.tipo_predio,'(null)')||
    ', n_derechos='||v.n_derechos||
    ', n_dominio='||v.n_dominio
  )::text                       AS valor,
  FALSE                         AS cumple,
  NOW()                         AS created_at,
  NOW()                         AS updated_at
FROM viol v
ORDER BY v.id_operacion, v.npn;


--740
-- ====================================================================================
-- VALIDACIÓN: Fecha Inicio Tenencia vs Fecha Documento Fuente
-- ====================================================================================

DROP TABLE IF EXISTS reglas.regla_740;

CREATE TABLE reglas.regla_740 AS
WITH base AS (
  SELECT 
    d.objectid          AS derecho_oid,
    d.globalid          AS derecho_gid,
    btrim(d.id_operacion_predio) AS id_operacion,
    lower(btrim(d.tipo)) AS tipo_derecho,
    d.fecha_inicio_tenencia::date AS fecha_tenencia,
    
    p.objectid          AS predio_oid,
    p.globalid          AS predio_gid,
    p.numero_predial_nacional AS npn,
    NULLIF(btrim(p.matricula_inmobiliaria), '') AS matricula_inmobiliaria,
    
    f.objectid          AS fuente_oid,
    f.globalid          AS fuente_gid,
    f.fecha_documento_fuente::date AS fecha_fuente

  FROM preprod.ilc_derecho d
  JOIN preprod.ilc_predio p 
    ON btrim(p.id_operacion) = btrim(d.id_operacion_predio)
  LEFT JOIN preprod.ilc_fuenteadministrativa f 
    ON f.id_operacion_predio = d.id_operacion_predio
  WHERE lower(btrim(d.tipo)) = 'dominio'
    AND NULLIF(btrim(p.matricula_inmobiliaria), '') IS NOT NULL
    AND NULLIF(btrim(p.matricula_inmobiliaria), '') <> '0'
)
SELECT
  '740'::text                   AS regla,
  'ILC_Derecho / ILC_FuenteAdministrativa'::text AS objeto,
  'preprod.ilc_derecho'::text   AS tabla,
  b.derecho_oid                 AS objectid,
  b.derecho_gid                 AS globalid,
  b.id_operacion,
  b.npn,
  CASE 
    WHEN b.fecha_tenencia IS NULL OR b.fecha_fuente IS NULL
      THEN 'INCUMPLE: Faltan fechas para comparar (tenencia o documento fuente nulos)'
    WHEN b.fecha_tenencia < b.fecha_fuente
      THEN 'INCUMPLE: Fecha de inicio de tenencia ('||b.fecha_tenencia||') es menor a la fecha del documento fuente ('||b.fecha_fuente||')'
    ELSE 'OK'
  END AS descripcion,
  (
    'matricula='||COALESCE(b.matricula_inmobiliaria,'(null)')||
    ', fecha_tenencia='||COALESCE(b.fecha_tenencia::text,'(null)')||
    ', fecha_fuente='||COALESCE(b.fecha_fuente::text,'(null)')
  )::text AS valor,
  (b.fecha_tenencia IS NOT NULL AND b.fecha_fuente IS NOT NULL AND b.fecha_tenencia >= b.fecha_fuente) AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM base b
ORDER BY descripcion, b.npn;

DROP TABLE IF EXISTS reglas.regla_741;

CREATE TABLE reglas.regla_741 AS
WITH predios AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion) AS id_operacion,
    p.matricula_inmobiliaria AS mi_raw,
    CASE WHEN NULLIF(btrim(p.matricula_inmobiliaria),'') IS NOT NULL THEN TRUE ELSE FALSE END AS mi_diligenciada
  FROM preprod.ilc_predio p
),
predios_mi AS (
  SELECT * FROM predios WHERE mi_diligenciada
),
fuentes AS (
  SELECT
    f.id_operacion_predio,
    f.fecha_documento_fuente::date AS f_doc,
    NULLIF(btrim(f.tipo),'')   AS tipo,
    NULLIF(btrim(f.numero_fuente),'') AS numero_fuente,
    NULLIF(btrim(f.ente_emisor),'')   AS ente_emisor
  FROM preprod.ilc_fuenteadministrativa f
),
visita AS (
  SELECT
    d.id_operacion_predio,
    d.fecha_visita_predial::date AS f_visita
  FROM preprod.datosadicionaleslevantamientocatastral d
),
join_fuentes AS (
  SELECT
    pm.objectid, pm.globalid, pm.id_operacion, pm.mi_raw,
    f.f_doc, f.tipo, f.numero_fuente, f.ente_emisor,
    v.f_visita,
    CASE
      WHEN f.f_doc IS NOT NULL
       AND f.tipo IS NOT NULL
       AND f.numero_fuente IS NOT NULL
       AND f.ente_emisor IS NOT NULL
      THEN TRUE ELSE FALSE
    END AS completa
  FROM predios_mi pm
  LEFT JOIN fuentes f
    ON btrim(f.id_operacion_predio) = pm.id_operacion
  LEFT JOIN visita v
    ON v.id_operacion_predio = pm.id_operacion
),
agg AS (
  SELECT
    j.objectid, j.globalid, j.id_operacion, j.mi_raw,
    MAX(j.f_visita) AS f_visita,
    COUNT(*) FILTER (WHERE completa) AS n_completas,
    COUNT(*) FILTER (WHERE completa AND (j.f_doc > j.f_visita)) AS n_fuentes_posteriores
  FROM join_fuentes j
  GROUP BY j.objectid, j.globalid, j.id_operacion, j.mi_raw
)
SELECT
  '741'::text AS regla,
  'ILC_Predio'::text AS objeto,
  'preprod.ilc_predio'::text AS tabla,
  a.objectid,
  a.globalid,
  a.id_operacion,
  ('INCUMPLE: MI diligenciada pero no cumple con fuentes completas y válidas.')::text AS descripcion,
  (
    'mi='||COALESCE(a.mi_raw,'(null)')
    ||', n_completas='||a.n_completas
    ||', n_fuentes_posteriores='||a.n_fuentes_posteriores
    ||', visita='||COALESCE(a.f_visita::text,'(null)')
  )::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM agg a
WHERE a.n_completas = 0       -- no tiene ninguna fuente completa
   OR a.n_fuentes_posteriores > 0;  -- o la fecha_doc > fecha_visita

--742
DROP TABLE IF EXISTS reglas.regla_742;

CREATE TABLE reglas.regla_742 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio)        AS id_operacion_predio,
    lower(btrim(i.tipo))                AS tipo_norm,
    upper(btrim(i.tipo_documento))      AS tipo_doc_norm,
    i.tipo,
    i.tipo_documento
  FROM preprod.ilc_interesado i
),
viol AS (
  SELECT
    b.*
  FROM base b
  WHERE (b.tipo_norm IN ('persona_jurídica','persona_juridica'))
    AND (b.tipo_doc_norm NOT IN ('NIT','SECUENCIAL') OR b.tipo_doc_norm IS NULL)
)
SELECT
  '742'::text                            AS regla,
  'ILC_Interesado'::text                 AS objeto,
  'preprod.ilc_interesado'::text         AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio                  AS id_operacion,
  NULL::varchar(30)                      AS npn,  -- aquí no aplica
  'INCUMPLE: Persona_Jurídica debe tener Tipo_Documento ∈ {NIT, Secuencial}'::text AS descripcion,
  COALESCE(v.tipo_documento,'(null)')::text AS valor,  -- solo muestra el valor malo
  FALSE                                   AS cumple,
  NOW()                                   AS created_at,
  NOW()                                   AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;

--743
DROP TABLE IF EXISTS reglas.regla_743;

CREATE TABLE reglas.regla_743 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio)        AS id_operacion_predio,
    lower(btrim(i.tipo))                AS tipo_norm,
    upper(btrim(i.tipo_documento))      AS tipo_doc_norm,
    i.tipo_documento
  FROM preprod.ilc_interesado i
)
SELECT
  '743'::text                    AS regla,
  'ILC_Interesado'::text         AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion_predio          AS id_operacion,
  NULL::varchar(30)              AS npn,  -- no aplica
  'INCUMPLE: Persona_Natural no puede tener Tipo_Documento = NIT'::text AS descripcion,
  COALESCE(b.tipo_documento,'(null)')::text AS valor,  -- el valor malo (NIT)
  FALSE                         AS cumple,
  NOW()                         AS created_at,
  NOW()                         AS updated_at
FROM base b
WHERE b.tipo_norm IN ('persona_natural','persona natural')
  AND b.tipo_doc_norm = 'NIT'
ORDER BY b.id_operacion_predio, b.objectid;


--744
DROP TABLE IF EXISTS reglas.regla_744;

CREATE TABLE reglas.regla_744 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio)   AS id_operacion_predio,
    upper(btrim(i.tipo_documento)) AS tipo_doc_norm,
    btrim(i.documento_identidad)   AS doc_id
  FROM preprod.ilc_interesado i
  WHERE upper(btrim(i.tipo_documento)) <> 'NIT'
),
valid AS (
  SELECT
    b.*,
    -- ¿solo dígitos?
    (b.doc_id ~ '^[0-9]+$') AS solo_numeros,
    -- > 0 (solo si es numérico)
    CASE WHEN b.doc_id ~ '^[0-9]+$'
         THEN (b.doc_id)::numeric > 0
         ELSE FALSE
    END AS mayor_cero
  FROM base b
),
asc_check AS (
  SELECT
    v.*,
    -- ¿el documento COMPLETO es una secuencia ascendente (cada dígito = anterior+1)?
    CASE
      WHEN v.solo_numeros = FALSE OR length(v.doc_id) < 2 THEN FALSE
      ELSE NOT EXISTS (
        SELECT 1
        FROM generate_series(1, length(v.doc_id)-1) AS g(i)
        WHERE (substr(v.doc_id, g.i+1, 1)::int - substr(v.doc_id, g.i, 1)::int) <> 1
      )
    END AS consecutivo_full_asc
  FROM valid v
),
viol AS (
  SELECT
    a.*,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN a.solo_numeros = FALSE THEN 'Documento_identidad contiene letras/símbolos' END,
      CASE WHEN a.mayor_cero   = FALSE THEN 'Documento_identidad <= 0 o vacío' END,
      CASE WHEN a.consecutivo_full_asc THEN 'Documento_identidad es secuencia ascendente completa' END
    )) AS motivo
  FROM asc_check a
  WHERE a.solo_numeros = FALSE
     OR a.mayor_cero   = FALSE
     OR a.consecutivo_full_asc = TRUE
)
SELECT
  '744'::text                     AS regla,
  'ILC_Interesado'::text          AS objeto,
  'preprod.ilc_interesado'::text  AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio           AS id_operacion,
  NULL::varchar(30)               AS npn, -- no aplica
  ('INCUMPLE: Tipo_Documento<>"NIT" → Documento_identidad debe ser numérico (>0) y NO ser secuencia ascendente completa. '||v.motivo)::text AS descripcion,
  v.doc_id::text                  AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;

--245
DROP TABLE IF EXISTS reglas.regla_745;

CREATE TABLE reglas.regla_745 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio)   AS id_operacion_predio,
    upper(btrim(i.tipo_documento)) AS tipo_doc_norm,
    btrim(i.documento_identidad)   AS doc_id
  FROM preprod.ilc_interesado i
  WHERE upper(btrim(i.tipo_documento)) = 'NIT'
),
valid AS (
  SELECT
    b.*,
    -- Cumple estructura "#########-#"
    (b.doc_id ~ '^[0-9]{9}-[0-9]$') AS estructura_ok,
    -- Numérico > 0 (quitando guion)
    CASE 
      WHEN b.doc_id ~ '^[0-9]{9}-[0-9]$'
      THEN replace(b.doc_id, '-', '')::numeric > 0
      ELSE FALSE
    END AS mayor_cero
  FROM base b
),
viol AS (
  SELECT
    v.*,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN v.estructura_ok = FALSE THEN 'Formato inválido (esperado #########-#)' END,
      CASE WHEN v.mayor_cero    = FALSE THEN 'Documento_identidad ≤ 0 o inválido' END
    )) AS motivo
  FROM valid v
  WHERE v.estructura_ok = FALSE
     OR v.mayor_cero    = FALSE
)
SELECT
  '745'::text                     AS regla,
  'ILC_Interesado'::text          AS objeto,
  'preprod.ilc_interesado'::text  AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio           AS id_operacion,
  NULL::varchar(30)               AS npn, -- no aplica
  ('INCUMPLE: Tipo_Documento="NIT" → Documento_identidad debe ser >0 y cumplir estructura #########-#. '||v.motivo)::text AS descripcion,
  v.doc_id::text                  AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;




--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////