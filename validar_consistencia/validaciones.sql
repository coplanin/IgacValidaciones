
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

--746
DROP TABLE IF EXISTS reglas.regla_746;

CREATE TABLE reglas.regla_746 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio)   AS id_operacion_predio,
    upper(btrim(i.tipo))           AS tipo,
    btrim(i.primer_nombre)         AS primer_nombre,
    btrim(i.segundo_nombre)        AS segundo_nombre,
    btrim(i.primer_apellido)       AS primer_apellido,
    btrim(i.segundo_apellido)      AS segundo_apellido
  FROM preprod.ilc_interesado i
  WHERE upper(btrim(i.tipo)) = 'PERSONA_NATURAL'
),
viol AS (
  SELECT
    b.*,
    trim(both ', ' FROM concat_ws(', ',
      CASE 
        WHEN b.primer_nombre IS NULL OR b.primer_nombre = '' 
        THEN 'Primer_Nombre es obligatorio' 
        WHEN b.primer_nombre !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$' 
        THEN 'Primer_Nombre contiene números o caracteres inválidos' 
      END,
      CASE 
        WHEN b.primer_apellido IS NULL OR b.primer_apellido = '' 
        THEN 'Primer_Apellido es obligatorio' 
        WHEN b.primer_apellido !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$' 
        THEN 'Primer_Apellido contiene números o caracteres inválidos' 
      END,
      CASE 
        WHEN b.segundo_nombre IS NOT NULL AND b.segundo_nombre <> '' 
             AND b.segundo_nombre !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$' 
        THEN 'Segundo_Nombre contiene números o caracteres inválidos' 
      END,
      CASE 
        WHEN b.segundo_apellido IS NOT NULL AND b.segundo_apellido <> '' 
             AND b.segundo_apellido !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$' 
        THEN 'Segundo_Apellido contiene números o caracteres inválidos' 
      END
    )) AS motivo
  FROM base b
  WHERE 
    -- incumple si hay motivo
    (b.primer_nombre IS NULL OR b.primer_nombre = '' OR b.primer_nombre !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$')
    OR (b.primer_apellido IS NULL OR b.primer_apellido = '' OR b.primer_apellido !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$')
    OR (b.segundo_nombre IS NOT NULL AND b.segundo_nombre <> '' AND b.segundo_nombre !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$')
    OR (b.segundo_apellido IS NOT NULL AND b.segundo_apellido <> '' AND b.segundo_apellido !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$')
)
SELECT
  '746'::text                     AS regla,
  'ILC_Interesado'::text          AS objeto,
  'preprod.ilc_interesado'::text  AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio           AS id_operacion,
  NULL::varchar(30)               AS npn, -- no aplica
  ('INCUMPLE: Persona_Natural → Nombres/Apellidos inválidos. '||v.motivo)::text AS descripcion,
  (
    'primer_nombre='||COALESCE(v.primer_nombre,'(null)')|| 
    ', segundo_nombre='||COALESCE(v.segundo_nombre,'(null)')||
    ', primer_apellido='||COALESCE(v.primer_apellido,'(null)')||
    ', segundo_apellido='||COALESCE(v.segundo_apellido,'(null)')
  )::text                         AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;

--747

DROP TABLE IF EXISTS reglas.regla_747;

CREATE TABLE reglas.regla_747 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio)   AS id_operacion_predio,
    upper(btrim(i.tipo))           AS tipo,
    btrim(i.primer_nombre)         AS primer_nombre,
    btrim(i.segundo_nombre)        AS segundo_nombre,
    btrim(i.primer_apellido)       AS primer_apellido,
    btrim(i.segundo_apellido)      AS segundo_apellido
  FROM preprod.ilc_interesado i
  WHERE upper(btrim(i.tipo)) = 'PERSONA_JURIDICA'
),
viol AS (
  SELECT
    b.*,
    trim(both ', ' FROM concat_ws(', ',
      CASE WHEN b.primer_nombre IS NOT NULL AND b.primer_nombre <> '' 
           THEN 'Primer_Nombre debe ser NULL' END,
      CASE WHEN b.segundo_nombre IS NOT NULL AND b.segundo_nombre <> '' 
           THEN 'Segundo_Nombre debe ser NULL' END,
      CASE WHEN b.primer_apellido IS NOT NULL AND b.primer_apellido <> '' 
           THEN 'Primer_Apellido debe ser NULL' END,
      CASE WHEN b.segundo_apellido IS NOT NULL AND b.segundo_apellido <> '' 
           THEN 'Segundo_Apellido debe ser NULL' END
    )) AS motivo
  FROM base b
  WHERE 
    (b.primer_nombre IS NOT NULL AND b.primer_nombre <> '')
    OR (b.segundo_nombre IS NOT NULL AND b.segundo_nombre <> '')
    OR (b.primer_apellido IS NOT NULL AND b.primer_apellido <> '')
    OR (b.segundo_apellido IS NOT NULL AND b.segundo_apellido <> '')
)
SELECT
  '747'::text                     AS regla,
  'ILC_Interesado'::text          AS objeto,
  'preprod.ilc_interesado'::text  AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio           AS id_operacion,
  NULL::varchar(30)               AS npn, -- no aplica
  ('INCUMPLE: Persona_Jurídica → No debe tener nombres/apellidos diligenciados. '||v.motivo)::text AS descripcion,
  (
    'primer_nombre='||COALESCE(v.primer_nombre,'(null)')|| 
    ', segundo_nombre='||COALESCE(v.segundo_nombre,'(null)')||
    ', primer_apellido='||COALESCE(v.primer_apellido,'(null)')||
    ', segundo_apellido='||COALESCE(v.segundo_apellido,'(null)')
  )::text                         AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;

--- regla 730
DROP TABLE IF EXISTS reglas.regla_730;

CREATE TABLE reglas.regla_730 AS
WITH base AS (
  SELECT
    d.objectid,
    d.globalid,
    btrim(d.id_operacion_predio)   AS id_operacion_predio,
    upper(btrim(d.tipo))           AS tipo_derecho,
    p.tipo                         AS tipo_predio,
    NULLIF(btrim(p.matricula_inmobiliaria),'') AS matricula_inmobiliaria,
    p.numero_predial_nacional      AS npn
  FROM preprod.ilc_derecho d
  JOIN preprod.ilc_predio p
    ON p.id_operacion = d.id_operacion_predio
),
viol AS (
  SELECT
    b.*,
    CASE
      WHEN b.tipo_predio = 'Privado' AND b.tipo_derecho = 'DOMINIO' AND b.matricula_inmobiliaria IS NULL
        THEN 'Privado + Dominio requiere Matricula_Inmobiliaria NO NULL'
      WHEN b.tipo_derecho IN ('POSESION','OCUPACION') AND b.matricula_inmobiliaria IS NOT NULL
        THEN 'Posesion/Ocupacion requiere Matricula_Inmobiliaria = NULL'
    END AS motivo
  FROM base b
  WHERE 
    (b.tipo_predio = 'Privado' AND b.tipo_derecho = 'DOMINIO' AND b.matricula_inmobiliaria IS NULL)
    OR (b.tipo_derecho IN ('POSESION','OCUPACION') AND b.matricula_inmobiliaria IS NOT NULL)
)
SELECT
  '730'::text                     AS regla,
  'ILC_Derecho'::text             AS objeto,
  'preprod.ilc_derecho'::text     AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio           AS id_operacion,
  v.npn,
  ('INCUMPLE: '||v.motivo)::text  AS descripcion,
  ('tipo_predio='||COALESCE(v.tipo_predio,'(null)')||
   ', tipo_derecho='||COALESCE(v.tipo_derecho,'(null)')||
   ', matricula_inmobiliaria='||COALESCE(v.matricula_inmobiliaria,'(null)')
  )::text                         AS valor,
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;

--748
DROP TABLE IF EXISTS reglas.regla_748;

CREATE TABLE reglas.regla_748 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    i.tipo,
    btrim(i.primer_nombre)       AS primer_nombre,
    btrim(i.segundo_nombre)      AS segundo_nombre,
    btrim(i.primer_apellido)     AS primer_apellido,
    btrim(i.segundo_apellido)    AS segundo_apellido
  FROM preprod.ilc_interesado i
  WHERE upper(btrim(i.tipo)) = 'PERSONA_NATURAL'
),
viol AS (
  SELECT
    b.*,
    ARRAY_REMOVE(ARRAY[
      CASE WHEN upper(b.primer_nombre)   LIKE '%SUC%' THEN 'primer_nombre contiene SUC' END,
      CASE WHEN upper(b.segundo_nombre)  LIKE '%SUC%' THEN 'segundo_nombre contiene SUC' END,
      CASE WHEN upper(b.primer_apellido) LIKE '%SUC%' THEN 'primer_apellido contiene SUC' END,
      CASE WHEN upper(b.segundo_apellido)LIKE '%SUC%' THEN 'segundo_apellido contiene SUC' END
    ], NULL) AS motivos
  FROM base b
)
SELECT
  '748'::text AS regla,
  'ILC_Interesado'::text AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio,
  NULL::varchar(30) AS npn,
  ('INCUMPLE: Persona_Natural con nombres/apellidos que contienen "SUC".')::text AS descripcion,
  array_to_string(v.motivos, ', ')::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM viol v
WHERE array_length(v.motivos,1) > 0
ORDER BY v.id_operacion_predio, v.objectid;

--749
DROP TABLE IF EXISTS reglas.regla_749;

CREATE TABLE reglas.regla_749 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    upper(btrim(i.tipo)) AS tipo,
    i.primer_nombre,
    i.segundo_nombre,
    i.primer_apellido,
    i.segundo_apellido,
    btrim(i.razon_social) AS razon_social
  FROM preprod.ilc_interesado i
)
, viol AS (
  SELECT
    b.*,
    ARRAY_REMOVE(ARRAY[
      CASE WHEN b.tipo = 'PERSONA_JURIDICA' AND b.primer_nombre IS NOT NULL 
           THEN 'primer_nombre='   || COALESCE(b.primer_nombre,'(null)') END,
      CASE WHEN b.tipo = 'PERSONA_JURIDICA' AND b.segundo_nombre IS NOT NULL 
           THEN 'segundo_nombre='  || COALESCE(b.segundo_nombre,'(null)') END,
      CASE WHEN b.tipo = 'PERSONA_JURIDICA' AND b.primer_apellido IS NOT NULL 
           THEN 'primer_apellido=' || COALESCE(b.primer_apellido,'(null)') END,
      CASE WHEN b.tipo = 'PERSONA_JURIDICA' AND b.segundo_apellido IS NOT NULL 
           THEN 'segundo_apellido='|| COALESCE(b.segundo_apellido,'(null)') END,
      CASE WHEN b.tipo = 'PERSONA_JURIDICA' AND (b.razon_social IS NULL OR b.razon_social = '') 
           THEN 'razon_social='    || COALESCE(b.razon_social,'(null)') END
    ], NULL) AS motivos
  FROM base b
  WHERE b.tipo = 'PERSONA_JURIDICA'
)
SELECT
  '749'::text AS regla,
  'ILC_Interesado'::text AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio,
  NULL::varchar(30) AS npn,
  'INCUMPLE: Persona_Juridica debe tener solo razon_social y no nombres/apellidos'::text AS descripcion,
  ('tipo='||v.tipo||' | '||array_to_string(v.motivos, ', '))::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM viol v
WHERE array_length(v.motivos,1) > 0
ORDER BY v.id_operacion_predio, v.objectid;


--750
DROP TABLE IF EXISTS reglas.regla_750;

CREATE TABLE reglas.regla_750 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    upper(btrim(i.tipo)) AS tipo,
    btrim(i.sexo) AS sexo
  FROM preprod.ilc_interesado i
)
, viol AS (
  SELECT
    b.*,
    CASE 
      WHEN b.sexo IS NOT NULL AND b.tipo <> 'PERSONA_NATURAL'
      THEN 'Sexo='||COALESCE(b.sexo,'(null)')||', Tipo='||COALESCE(b.tipo,'(null)')
    END AS motivo
  FROM base b
  WHERE b.sexo IS NOT NULL
    AND b.tipo <> 'PERSONA_NATURAL'
)
SELECT
  '750'::text AS regla,
  'ILC_Interesado'::text AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio,
  NULL::varchar(30) AS npn,
  'INCUMPLE: Si Sexo está diligenciado entonces Tipo debe ser Persona_Natural'::text AS descripcion,
  ('tipo='||v.tipo||' | sexo='||COALESCE(v.sexo,'(null)'))::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM viol v
ORDER BY v.id_operacion_predio, v.objectid;

--751
DROP TABLE IF EXISTS reglas.regla_751;

CREATE TABLE reglas.regla_751 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    upper(btrim(i.tipo))         AS tipo,
    btrim(i.primer_nombre)       AS primer_nombre,
    btrim(i.segundo_nombre)      AS segundo_nombre,
    btrim(i.primer_apellido)     AS primer_apellido,
    btrim(i.segundo_apellido)    AS segundo_apellido
  FROM preprod.ilc_interesado i
  WHERE upper(btrim(i.tipo)) = 'PERSONA_NATURAL'
),
norm AS (
  -- Normaliza cada campo: a MAYÚSCULAS, quita . , & - por espacios y colapsa espacios
  SELECT
    b.*,
    upper(btrim(b.primer_nombre))  AS pn_raw,
    upper(btrim(b.segundo_nombre)) AS sn_raw,
    upper(btrim(b.primer_apellido)) AS pa_raw,
    upper(btrim(b.segundo_apellido)) AS sa_raw,
    -- versión normalizada con signos reemplazados por espacio y espacios colapsados
    ' '||regexp_replace(regexp_replace(coalesce(upper(b.primer_nombre),''), '[\.\,&\-]', ' ', 'g'), '\s+', ' ', 'g')||' ' AS pn_norm,
    ' '||regexp_replace(regexp_replace(coalesce(upper(b.segundo_nombre),''),'[\.\,&\-]',' ','g'), '\s+', ' ', 'g')||' ' AS sn_norm,
    ' '||regexp_replace(regexp_replace(coalesce(upper(b.primer_apellido),''),'[\.\,&\-]',' ','g'), '\s+', ' ', 'g')||' ' AS pa_norm,
    ' '||regexp_replace(regexp_replace(coalesce(upper(b.segundo_apellido),''),'[\.\,&\-]',' ','g'), '\s+', ' ', 'g')||' ' AS sa_norm
  FROM base b
),
flag AS (
  -- Tokens prohibidos: LTDA, SA, SCA, SAS, EN C, CIA
  -- (S.A., S.C.A., S.A.S., & Cia, EN C. se vuelven SA/SCA/SAS/CIA/EN C tras normalizar)
  SELECT
    n.*,
    -- Primer Nombre
    (position(' LTDA ' IN n.pn_norm) > 0) AS pn_has_ltda,
    (position(' SA '   IN n.pn_norm) > 0) AS pn_has_sa,
    (position(' SCA '  IN n.pn_norm) > 0) AS pn_has_sca,
    (position(' SAS '  IN n.pn_norm) > 0) AS pn_has_sas,
    (position(' EN C ' IN n.pn_norm) > 0) AS pn_has_enc,
    (position(' CIA '  IN n.pn_norm) > 0) AS pn_has_cia,

    -- Segundo Nombre
    (position(' LTDA ' IN n.sn_norm) > 0) AS sn_has_ltda,
    (position(' SA '   IN n.sn_norm) > 0) AS sn_has_sa,
    (position(' SCA '  IN n.sn_norm) > 0) AS sn_has_sca,
    (position(' SAS '  IN n.sn_norm) > 0) AS sn_has_sas,
    (position(' EN C ' IN n.sn_norm) > 0) AS sn_has_enc,
    (position(' CIA '  IN n.sn_norm) > 0) AS sn_has_cia,

    -- Primer Apellido
    (position(' LTDA ' IN n.pa_norm) > 0) AS pa_has_ltda,
    (position(' SA '   IN n.pa_norm) > 0) AS pa_has_sa,
    (position(' SCA '  IN n.pa_norm) > 0) AS pa_has_sca,
    (position(' SAS '  IN n.pa_norm) > 0) AS pa_has_sas,
    (position(' EN C ' IN n.pa_norm) > 0) AS pa_has_enc,
    (position(' CIA '  IN n.pa_norm) > 0) AS pa_has_cia,

    -- Segundo Apellido
    (position(' LTDA ' IN n.sa_norm) > 0) AS sa_has_ltda,
    (position(' SA '   IN n.sa_norm) > 0) AS sa_has_sa,
    (position(' SCA '  IN n.sa_norm) > 0) AS sa_has_sca,
    (position(' SAS '  IN n.sa_norm) > 0) AS sa_has_sas,
    (position(' EN C ' IN n.sa_norm) > 0) AS sa_has_enc,
    (position(' CIA '  IN n.sa_norm) > 0) AS sa_has_cia
  FROM norm n
),
viol AS (
  -- Construye lista de motivos "campo contiene TOKEN" con su valor original
  SELECT
    f.*,
    ARRAY_REMOVE(ARRAY[
      CASE WHEN pn_has_ltda THEN 'primer_nombre contiene LTDA (valor='||coalesce(f.primer_nombre,'(null)')||')' END,
      CASE WHEN pn_has_sa   THEN 'primer_nombre contiene SA (valor='  ||coalesce(f.primer_nombre,'(null)')||')' END,
      CASE WHEN pn_has_sca  THEN 'primer_nombre contiene SCA (valor=' ||coalesce(f.primer_nombre,'(null)')||')' END,
      CASE WHEN pn_has_sas  THEN 'primer_nombre contiene SAS (valor=' ||coalesce(f.primer_nombre,'(null)')||')' END,
      CASE WHEN pn_has_enc  THEN 'primer_nombre contiene EN C (valor='||coalesce(f.primer_nombre,'(null)')||')' END,
      CASE WHEN pn_has_cia  THEN 'primer_nombre contiene CIA (valor=' ||coalesce(f.primer_nombre,'(null)')||')' END,

      CASE WHEN sn_has_ltda THEN 'segundo_nombre contiene LTDA (valor='||coalesce(f.segundo_nombre,'(null)')||')' END,
      CASE WHEN sn_has_sa   THEN 'segundo_nombre contiene SA (valor='  ||coalesce(f.segundo_nombre,'(null)')||')' END,
      CASE WHEN sn_has_sca  THEN 'segundo_nombre contiene SCA (valor=' ||coalesce(f.segundo_nombre,'(null)')||')' END,
      CASE WHEN sn_has_sas  THEN 'segundo_nombre contiene SAS (valor=' ||coalesce(f.segundo_nombre,'(null)')||')' END,
      CASE WHEN sn_has_enc  THEN 'segundo_nombre contiene EN C (valor='||coalesce(f.segundo_nombre,'(null)')||')' END,
      CASE WHEN sn_has_cia  THEN 'segundo_nombre contiene CIA (valor=' ||coalesce(f.segundo_nombre,'(null)')||')' END,

      CASE WHEN pa_has_ltda THEN 'primer_apellido contiene LTDA (valor='||coalesce(f.primer_apellido,'(null)')||')' END,
      CASE WHEN pa_has_sa   THEN 'primer_apellido contiene SA (valor='  ||coalesce(f.primer_apellido,'(null)')||')' END,
      CASE WHEN pa_has_sca  THEN 'primer_apellido contiene SCA (valor=' ||coalesce(f.primer_apellido,'(null)')||')' END,
      CASE WHEN pa_has_sas  THEN 'primer_apellido contiene SAS (valor=' ||coalesce(f.primer_apellido,'(null)')||')' END,
      CASE WHEN pa_has_enc  THEN 'primer_apellido contiene EN C (valor='||coalesce(f.primer_apellido,'(null)')||')' END,
      CASE WHEN pa_has_cia  THEN 'primer_apellido contiene CIA (valor=' ||coalesce(f.primer_apellido,'(null)')||')' END,

      CASE WHEN sa_has_ltda THEN 'segundo_apellido contiene LTDA (valor='||coalesce(f.segundo_apellido,'(null)')||')' END,
      CASE WHEN sa_has_sa   THEN 'segundo_apellido contiene SA (valor='  ||coalesce(f.segundo_apellido,'(null)')||')' END,
      CASE WHEN sa_has_sca  THEN 'segundo_apellido contiene SCA (valor=' ||coalesce(f.segundo_apellido,'(null)')||')' END,
      CASE WHEN sa_has_sas  THEN 'segundo_apellido contiene SAS (valor=' ||coalesce(f.segundo_apellido,'(null)')||')' END,
      CASE WHEN sa_has_enc  THEN 'segundo_apellido contiene EN C (valor='||coalesce(f.segundo_apellido,'(null)')||')' END,
      CASE WHEN sa_has_cia  THEN 'segundo_apellido contiene CIA (valor=' ||coalesce(f.segundo_apellido,'(null)')||')' END
    ], NULL) AS motivos
  FROM flag f
)
SELECT
  '751'::text                     AS regla,
  'ILC_Interesado'::text          AS objeto,
  'preprod.ilc_interesado'::text  AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio           AS id_operacion,
  NULL::varchar(30)               AS npn,  -- no aplica
  'INCUMPLE: Persona_Natural no debe contener marcas societarias (LTDA, SA, SCA, SAS, EN C, CIA) en nombres/apellidos.'::text AS descripcion,
  array_to_string(v.motivos, ', ')::text   AS valor,  -- lista "campo contiene TOKEN (valor=...)"
  FALSE                           AS cumple,
  NOW()                           AS created_at,
  NOW()                           AS updated_at
FROM viol v
WHERE array_length(v.motivos,1) > 0
ORDER BY v.id_operacion_predio, v.objectid;


--757
-- Reglas:
--  1) Tipo = 'Escritura pública'   -> Ente_Emisor debe contener "Notaría"
--  2) Tipo = 'Sentencia_judicial'  -> Ente_Emisor debe contener "Juzgado" o "Tribunal"
--  3) Tipo = 'Acto_Administrativo' -> Ente_Emisor debe contener "Alcaldía" o "ANT" o "INCODER" o "INCORA" o "Ministerio" o "Juzgado" o "Tribunal"

DROP TABLE IF EXISTS reglas.regla_752;

CREATE TABLE reglas.regla_752 AS
WITH base AS (
  SELECT
    f.objectid,
    f.globalid,
    btrim(f.id_operacion_predio)             AS id_operacion_predio,
    btrim(f.tipo)                             AS tipo_raw,
    btrim(f.ente_emisor)                      AS ente_raw,
    upper(btrim(f.tipo))                      AS tipo_norm,
    upper(btrim(f.ente_emisor))               AS ente_norm,
    -- Para detectar 'ANT' como palabra y evitar falsos positivos tipo 'ANTONIO'
    (' '||upper(btrim(f.ente_emisor))||' ')   AS ente_padded
  FROM preprod.ilc_fuenteadministrativa f
),
marcados AS (
  SELECT
    b.*,
    -- Qué tipos nos interesan (normalizados a mayúsculas)
    (b.tipo_norm IN ('ESCRITURA PUBLICA','ESCRITURA_PÚBLICA','ESCRITURA_PUBLICA','ESCRITURA PÚBLICA')) AS es_escritura,
    (b.tipo_norm IN ('SENTENCIA_JUDICIAL','SENTENCIA JUDICIAL'))                                         AS es_sentencia,
    (b.tipo_norm IN ('ACTO_ADMINISTRATIVO','ACTO ADMINISTRATIVO'))                                       AS es_acto,

    -- Chequeos de contenido (case-insensitive por estar en upper):
    -- Escritura: debe tener 'NOTAR' (cubre NOTARIA / NOTARÍA)
    (b.ente_norm LIKE '%NOTAR%') AS ok_escritura,

    -- Sentencia: 'JUZGAD' o 'TRIBUN'
    (b.ente_norm LIKE '%JUZGAD%' OR b.ente_norm LIKE '%TRIBUN%') AS ok_sentencia,

    -- Acto: ALCALD | ANT (como palabra) | INCODER | INCORA | MINISTER | JUZGAD | TRIBUN
    (
      b.ente_norm LIKE '%ALCALD%'
      OR b.ente_padded LIKE '% ANT %'
      OR b.ente_norm LIKE '%INCODER%'
      OR b.ente_norm LIKE '%INCORA%'
      OR b.ente_norm LIKE '%MINISTER%'
      OR b.ente_norm LIKE '%JUZGAD%'
      OR b.ente_norm LIKE '%TRIBUN%'
    ) AS ok_acto
  FROM base b
),
viol AS (
  SELECT
    m.*,
    CASE
      WHEN m.es_escritura AND (m.ente_raw IS NULL OR m.ente_raw = '' OR NOT m.ok_escritura)
        THEN 'Tipo=Escritura pública → Ente_Emisor debe contener "Notaría"'
      WHEN m.es_sentencia AND (m.ente_raw IS NULL OR m.ente_raw = '' OR NOT m.ok_sentencia)
        THEN 'Tipo=Sentencia_judicial → Ente_Emisor debe contener "Juzgado" o "Tribunal"'
      WHEN m.es_acto AND (m.ente_raw IS NULL OR m.ente_raw = '' OR NOT m.ok_acto)
        THEN 'Tipo=Acto_Administrativo → Ente_Emisor debe contener "Alcaldía", "ANT", "INCODER", "INCORA", "Ministerio", "Juzgado" o "Tribunal"'
    END AS motivo
  FROM marcados m
)
SELECT
  '752'::text                         AS regla,
  'ILC_FuenteAdministrativa'::text    AS objeto,
  'preprod.ilc_fuenteadministrativa'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio               AS id_operacion,
  NULL::varchar(30)                   AS npn,   -- no aplica aquí
  ('INCUMPLE: '||v.motivo)::text      AS descripcion,
  (
    'tipo='||COALESCE(v.tipo_raw,'(null)')||
    ', ente_emisor='||COALESCE(v.ente_raw,'(null)')
  )::text                             AS valor,
  FALSE                                AS cumple,
  NOW()                                AS created_at,
  NOW()                                AS updated_at
FROM viol v
WHERE v.motivo IS NOT NULL   -- solo incumplidos
ORDER BY v.id_operacion_predio, v.objectid;

--731
DROP TABLE IF EXISTS reglas.regla_731;

CREATE TABLE reglas.regla_731 AS
WITH base AS (
    SELECT
        d.objectid,
        d.globalid,
        btrim(d.id_operacion_predio)   AS id_operacion_predio,
        btrim(lower(d.tipo))           AS derecho_tipo,
        btrim(lower(p.tipo))           AS predio_tipo
    FROM preprod.ilc_derecho d
    JOIN preprod.ilc_predio p
      ON p.id_operacion = d.id_operacion_predio
    WHERE lower(btrim(d.tipo)) = 'posesion'
),
viol AS (
    SELECT
        b.*,
        CASE 
          WHEN b.predio_tipo IS NULL OR b.predio_tipo <> 'privado'
            THEN 'ILC_Derecho.Tipo=Posesion → ILC_Predio.Tipo debe ser "Privado"'
        END AS motivo
    FROM base b
)
SELECT
    '731'::text                       AS regla,
    'ILC_Derecho'::text               AS objeto,
    'preprod.ilc_derecho'::text       AS tabla,
    v.objectid,
    v.globalid,
    v.id_operacion_predio             AS id_operacion,
    NULL::varchar(30)                 AS npn, -- no aplica aquí
    ('INCUMPLE: '||v.motivo)::text    AS descripcion,
    (
      'derecho_tipo='||COALESCE(v.derecho_tipo,'(null)')||
      ', predio_tipo='||COALESCE(v.predio_tipo,'(null)')
    )::text                           AS valor,
    FALSE                             AS cumple,
    NOW()                             AS created_at,
    NOW()                             AS updated_at
FROM viol v
WHERE v.motivo IS NOT NULL
ORDER BY v.id_operacion_predio, v.objectid;

--758
DROP TABLE IF EXISTS reglas.regla_758;

CREATE TABLE reglas.regla_758 AS
WITH base AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)        AS id_operacion_predio,
    p.numero_predial_nacional    AS npn
  FROM preprod.ilc_predio p
),
agg AS (
  SELECT
    b.objectid,
    b.globalid,
    b.id_operacion_predio,
    b.npn,
    COUNT(i.objectid) AS n_interesados
  FROM base b
  LEFT JOIN preprod.ilc_interesado i
    ON b.id_operacion_predio = btrim(i.id_operacion_predio)
  GROUP BY b.objectid, b.globalid, b.id_operacion_predio, b.npn
)
SELECT
  '758'::text                   AS regla,
  'ILC_Predio'::text           AS objeto,
  'preprod.ilc_predio'::text   AS tabla,
  a.objectid,
  a.globalid,
  a.id_operacion_predio        AS id_operacion,
  a.npn,
  'INCUMPLE: Todo ILC_Predio debe relacionar al menos un ILC_Interesado'::text AS descripcion,
  ('n_interesados='||a.n_interesados||', npn='||COALESCE(a.npn,'(null)'))::text AS valor,
  FALSE                        AS cumple,
  NOW()                        AS created_at,
  NOW()                        AS updated_at
FROM agg a
WHERE a.n_interesados = 0
ORDER BY a.id_operacion_predio, a.objectid;

--759

DROP TABLE IF EXISTS reglas.regla_759;

CREATE TABLE reglas.regla_759 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    NULLIF(btrim(i.primer_nombre),'')     AS primer_nombre,
    NULLIF(btrim(i.segundo_nombre),'')    AS segundo_nombre,
    NULLIF(btrim(i.primer_apellido),'')   AS primer_apellido,
    NULLIF(btrim(i.segundo_apellido),'')  AS segundo_apellido,
    NULLIF(btrim(i.razon_social),'')      AS razon_social,
    NULLIF(btrim(i.documento_identidad),'') AS documento_identidad
  FROM preprod.ilc_interesado i
),
-- Agrupo por combinación de nombres y razón social
agrupado AS (
  SELECT
    COALESCE(primer_nombre,'')   AS primer_nombre,
    COALESCE(segundo_nombre,'')  AS segundo_nombre,
    COALESCE(primer_apellido,'') AS primer_apellido,
    COALESCE(segundo_apellido,'')AS segundo_apellido,
    COALESCE(razon_social,'')    AS razon_social,
    COUNT(DISTINCT documento_identidad)   AS n_docs,
    ARRAY_AGG(DISTINCT documento_identidad) AS docs_distintos,
    ARRAY_AGG(DISTINCT id_operacion_predio) AS predios
  FROM base
  GROUP BY primer_nombre, segundo_nombre, primer_apellido, segundo_apellido, razon_social
  HAVING COUNT(DISTINCT documento_identidad) > 1
)
SELECT
  '759'::text AS regla,
  'ILC_Interesado'::text AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  NULL::bigint AS objectid,
  NULL::uuid   AS globalid,
  NULL::text   AS id_operacion,
  NULL::text   AS npn,
  (
    'INCUMPLE: Existen '||a.n_docs||' documentos diferentes asociados a mismos nombres/razón social'
  )::text AS descripcion,
  (
    'Nombres='||
    COALESCE(NULLIF(a.primer_nombre,''),'(null)')||' '||
    COALESCE(NULLIF(a.segundo_nombre,''),'')||' '||
    COALESCE(NULLIF(a.primer_apellido,''),'')||' '||
    COALESCE(NULLIF(a.segundo_apellido,''),'')||
    ', Razon_Social='||COALESCE(NULLIF(a.razon_social,''),'(null)')||
    ', Docs='||array_to_string(a.docs_distintos, ',')||
    ', Predios='||array_to_string(a.predios, ',')
  )::text AS valor,
  FALSE AS cumple,
  NOW()  AS created_at,
  NOW()  AS updated_at
FROM agrupado a;

--760
DROP TABLE IF EXISTS reglas.regla_756;

CREATE TABLE reglas.regla_756 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    NULLIF(btrim(i.documento_identidad),'') AS documento_identidad
  FROM preprod.ilc_interesado i
),
duplicados AS (
  SELECT
    documento_identidad,
    COUNT(*) AS n_veces,
    ARRAY_AGG(objectid) AS objetos,
    ARRAY_AGG(globalid) AS globales,
    ARRAY_AGG(id_operacion_predio) AS predios
  FROM base
  WHERE documento_identidad IS NOT NULL
  GROUP BY documento_identidad
  HAVING COUNT(*) > 1
)
SELECT
  '756'::text AS regla,
  'ILC_Interesado'::text AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  NULL::bigint AS objectid,
  NULL::uuid   AS globalid,
  NULL::text   AS id_operacion,
  NULL::text   AS npn,
  ('INCUMPLE: Documento_Identidad duplicado, aparece '||d.n_veces||' veces')::text AS descripcion,
  ('Documento_Identidad='||d.documento_identidad||
   ', ObjectIDs='||array_to_string(d.objetos, ',')||
   ', GlobalIDs='||array_to_string(d.globales, ',')||
   ', Predios='||array_to_string(d.predios, ',')
  )::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM duplicados d;

--761
DROP TABLE IF EXISTS reglas.regla_761;

CREATE TABLE reglas.regla_761 AS
WITH base AS (
  SELECT
    i.objectid,
    i.globalid,
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    NULLIF(btrim(i.grupo_etnico),'') AS grupo_etnico,
    NULLIF(btrim(i.nombre_pueblo),'') AS nombre_pueblo
  FROM preprod.ilc_interesado i
),
viol AS (
  SELECT
    b.*,
    (b.grupo_etnico = 'Etnico.Indigena' AND b.nombre_pueblo IS NOT NULL) AS ok_regla,
    CASE 
      WHEN b.grupo_etnico = 'Etnico.Indigena' AND b.nombre_pueblo IS NULL 
        THEN 'Grupo_Etnico=Indigena pero Nombre_Pueblo es NULL o vacío'
    END AS motivo
  FROM base b
)
SELECT
  '761'::text AS regla,
  'ILC_Interesado'::text AS objeto,
  'preprod.ilc_interesado'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio,
  NULL::text AS npn,
  ('INCUMPLE: Grupo_Etnico=Indigena → Nombre_Pueblo obligatorio. '||v.motivo)::text AS descripcion,
  ('Grupo_Etnico='||COALESCE(v.grupo_etnico,'(null)')||
   ', Nombre_Pueblo='||COALESCE(v.nombre_pueblo,'(null)')
  )::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM viol v
WHERE NOT v.ok_regla
ORDER BY v.id_operacion_predio, v.objectid;

--732

DROP TABLE IF EXISTS reglas.regla_732;

CREATE TABLE reglas.regla_732 AS
WITH base AS (
  SELECT
    d.objectid,
    d.globalid,
    btrim(d.id_operacion_predio) AS id_operacion_predio,
    lower(btrim(d.tipo)) AS derecho_tipo,
    lower(btrim(p.tipo)) AS predio_tipo
  FROM preprod.ilc_derecho d
  JOIN preprod.ilc_predio p
    ON p.id_operacion = d.id_operacion_predio
),
viol AS (
  SELECT
    b.*,
    NOT (b.predio_tipo = 'privado' AND b.derecho_tipo = 'ocupacion') AS ok_regla,
    CASE 
      WHEN b.predio_tipo = 'privado' AND b.derecho_tipo = 'ocupacion'
        THEN 'Predio.Tipo=Privado pero Derecho.Tipo=Ocupacion'
    END AS motivo
  FROM base b
)
SELECT
  '732'::text AS regla,
  'ILC_Derecho'::text AS objeto,
  'preprod.ilc_derecho'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio,
  NULL::text AS npn,
  ('INCUMPLE: Si Predio.Tipo=Privado → Derecho.Tipo≠Ocupacion. '||v.motivo)::text AS descripcion,
  ('Predio.Tipo='||COALESCE(v.predio_tipo,'(null)')||
   ', Derecho.Tipo='||COALESCE(v.derecho_tipo,'(null)')
  )::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM viol v
WHERE NOT v.ok_regla
ORDER BY v.id_operacion_predio, v.objectid;

--733
DROP TABLE IF EXISTS reglas.regla_733;

CREATE TABLE reglas.regla_733 AS
WITH base AS (
  SELECT
    d.objectid,
    d.globalid,
    btrim(d.id_operacion_predio) AS id_operacion_predio,
    lower(btrim(d.tipo)) AS derecho_tipo,
    lower(btrim(p.tipo)) AS predio_tipo
  FROM preprod.ilc_derecho d
  JOIN preprod.ilc_predio p
    ON p.id_operacion = d.id_operacion_predio
),
viol AS (
  SELECT
    b.*,
    NOT (
      b.predio_tipo LIKE 'publico%' 
      AND b.derecho_tipo = 'posesion'
    ) AS ok_regla,
    CASE 
      WHEN b.predio_tipo LIKE 'publico%' AND b.derecho_tipo = 'posesion'
        THEN 'Predio.Tipo='||b.predio_tipo||' pero Derecho.Tipo=Posesion'
    END AS motivo
  FROM base b
)
SELECT
  '733'::text AS regla,
  'ILC_Derecho'::text AS objeto,
  'preprod.ilc_derecho'::text AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio,
  NULL::text AS npn,
  ('INCUMPLE: Predio.Tipo=Publico → Derecho.Tipo≠Posesion. '||v.motivo)::text AS descripcion,
  ('Predio.Tipo='||COALESCE(v.predio_tipo,'(null)')||
   ', Derecho.Tipo='||COALESCE(v.derecho_tipo,'(null)')
  )::text AS valor,
  FALSE AS cumple,
  NOW() AS created_at,
  NOW() AS updated_at
FROM viol v
WHERE NOT v.ok_regla
ORDER BY v.id_operacion_predio, v.objectid;

--374

DROP TABLE IF EXISTS reglas.regla_734;

CREATE TABLE reglas.regla_734 AS
WITH dpr AS (
  SELECT
    d.objectid,
    d.globalid,
    btrim(d.id_operacion_predio)                                 AS id_operacion_predio,
    lower(btrim(d.tipo))                                          AS derecho_tipo,
    btrim(p.tipo)                                                 AS predio_tipo_raw,
    -- normaliza tipo de predio: mayúsc/minúsc y reemplaza . y espacios por _
    lower(regexp_replace(btrim(p.tipo), '[\.\s]+', '_', 'g'))     AS predio_tipo_norm
  FROM preprod.ilc_derecho d
  JOIN preprod.ilc_predio p
    ON p.id_operacion = d.id_operacion_predio
  WHERE lower(btrim(d.tipo)) = 'dominio'
),
int_rs AS (
  SELECT
    btrim(i.id_operacion_predio) AS id_operacion_predio,
    -- juntamos todas las razones sociales por predio para informar
    string_agg(btrim(i.razon_social), ' | ' ORDER BY btrim(i.razon_social)) AS razones_sociales_raw,
    -- bandera: ¿hay alguna razón social aceptada?
    bool_or(
      lower(i.razon_social) LIKE '%la nación%' OR
      lower(i.razon_social) LIKE '%la nacion%' OR
      lower(i.razon_social) LIKE '%municipio%' OR
      lower(i.razon_social) LIKE '%agencia nacional de tierras%'
    ) AS tiene_rs_valida
  FROM preprod.ilc_interesado i
  GROUP BY btrim(i.id_operacion_predio)
),
base AS (
  SELECT
    d.*,
    coalesce(r.razones_sociales_raw, '(sin interesados)') AS razones_sociales_raw,
    coalesce(r.tiene_rs_valida, FALSE)                   AS tiene_rs_valida
  FROM dpr d
  LEFT JOIN int_rs r
    ON r.id_operacion_predio = d.id_operacion_predio
),
viol AS (
  SELECT
    b.*,
    -- aplica la regla solo para los tipos públicos indicados
    (b.predio_tipo_norm IN ('publico_baldio','publico_presunto_baldio','publico_baldio_reserva_indigena')) AS aplica_regla,
    CASE
      WHEN b.predio_tipo_norm IN ('publico_baldio','publico_presunto_baldio','publico_baldio_reserva_indigena')
           AND b.tiene_rs_valida = FALSE
      THEN 'Predio público (baldío/presunto/reserva indígena) con Derecho=Dominio sin RS válida (La Nación/Municipio/Agencia Nacional de Tierras)'
    END AS motivo
  FROM base b
)
SELECT
  '734'::text                      AS regla,
  'ILC_Interesado'::text           AS objeto,
  'preprod.ilc_interesado'::text   AS tabla,
  v.objectid,
  v.globalid,
  v.id_operacion_predio            AS id_operacion,
  NULL::text                       AS npn,
  ('INCUMPLE: '||v.motivo)::text   AS descripcion,
  (
    'predio_tipo='||COALESCE(v.predio_tipo_raw,'(null)')||
    ', derecho_tipo='||COALESCE(v.derecho_tipo,'(null)')||
    ', razones_sociales='||COALESCE(v.razones_sociales_raw,'(null)')
  )::text                          AS valor,
  FALSE                            AS cumple,
  NOW()                            AS created_at,
  NOW()                            AS updated_at
FROM viol v
WHERE v.aplica_regla = TRUE
  AND v.motivo IS NOT NULL            -- solo incumplidos
ORDER BY v.id_operacion_predio, v.objectid;

--737
DROP TABLE IF EXISTS reglas.regla_737;

CREATE TABLE reglas.regla_737 AS
WITH dpr AS (
    SELECT
        d.objectid,
        d.globalid,
        btrim(d.id_operacion_predio) AS id_operacion_predio,
        lower(btrim(d.tipo))         AS derecho_tipo,
        btrim(p.tipo)                AS predio_tipo
    FROM preprod.ilc_derecho d
    JOIN preprod.ilc_predio p
      ON p.id_operacion = d.id_operacion_predio
    WHERE lower(btrim(d.tipo)) = 'dominio'
      AND p.tipo IN ('Publico_Fiscal_Patrimonial','Publico_Uso_Publico')
),
ints AS (
    SELECT
        i.id_operacion_predio,
        string_agg(
            coalesce(i.tipo,'(null)')||'/'||coalesce(i.documento_identidad,''),
            ' | ' ORDER BY i.objectid
        ) AS interesados_raw,
        bool_or(lower(btrim(i.tipo)) <> 'persona_juridica') AS hay_invalido
    FROM preprod.ilc_interesado i
    GROUP BY i.id_operacion_predio
),
base AS (
    SELECT
        d.*,
        coalesce(i.interesados_raw,'(sin interesados)') AS interesados_raw,
        coalesce(i.hay_invalido,FALSE)                  AS hay_invalido
    FROM dpr d
    LEFT JOIN ints i ON i.id_operacion_predio = d.id_operacion_predio
)
SELECT
    '737'::text                    AS regla,
    'ILC_Interesado'::text         AS objeto,
    'preprod.ilc_interesado'::text AS tabla,
    b.objectid,
    b.globalid,
    b.id_operacion_predio          AS id_operacion,
    NULL::text                     AS npn,
    ('INCUMPLE: Predio '||b.predio_tipo||' + Derecho=Dominio debe tener interesados Persona_Juridica')::text AS descripcion,
    (
      'predio_tipo='||COALESCE(b.predio_tipo,'(null)')||
      ', derecho_tipo='||COALESCE(b.derecho_tipo,'(null)')||
      ', interesados='||COALESCE(b.interesados_raw,'(null)')
    )::text                        AS valor,
    FALSE                          AS cumple,
    NOW()                          AS created_at,
    NOW()                          AS updated_at
FROM base b
WHERE b.hay_invalido = TRUE
ORDER BY b.id_operacion_predio, b.objectid;

-- REGLA 762 - INCUMPLIDOS
-- Predios PH.Unidad_Predial o Informal con NPN pos22='2' y pos27-30<>'0000'
-- Deben tener ≥1 UC válida (excluye parqueaderos/garajes descubiertos y UC no construidas)

DROP TABLE IF EXISTS reglas.regla_762_incumple;

CREATE TABLE reglas.regla_762_incumple AS
WITH predios AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.condicion_predio))              AS condicion,
    p.numero_predial_nacional                     AS npn,
    regexp_replace(p.numero_predial_nacional, '\D', '', 'g') AS npn_digits
  FROM preprod.ilc_predio p
),
predios_objetivo AS (
  SELECT
    objectid, globalid, id_operacion, condicion, npn, npn_digits,
    substring(npn_digits FROM 22 FOR 1) AS s22,
    substring(npn_digits FROM 27 FOR 4) AS s27_30
  FROM predios
  WHERE condicion IN ('ph_unidad_predial','ph.unidad_predial','informal')
    AND length(npn_digits) = 30
    AND substring(npn_digits FROM 22 FOR 1) = '2'
    AND substring(npn_digits FROM 27 FOR 4) <> '0000'
),
uc AS (   -- UC con sus áreas
  SELECT
    btrim(u.id_operacion_predio)      AS id_operacion,
    u.objectid                        AS uc_objectid,
    u.globalid                        AS uc_globalid,
    u.id_caracteristicasunidadconstru AS cuc_id_fk,
    u.area_construccion
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (  -- características (uso)
  SELECT
    c.id_caracteristicas_unidad_cons  AS cuc_id,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc_join AS (  -- UC + uso por predio
  SELECT
    po.id_operacion,
    u.uc_objectid,
    u.uc_globalid,
    u.area_construccion,
    c.uso
  FROM predios_objetivo po
  LEFT JOIN uc  u ON u.id_operacion = po.id_operacion
  LEFT JOIN cuc c ON c.cuc_id       = u.cuc_id_fk
),
-- reglas de exclusión según tu lista y "no construidas"
uc_marcada AS (
  SELECT
    id_operacion,
    uc_objectid,
    uc_globalid,
    area_construccion,
    uso,
    -- Exclusiones: parqueaderos/garajes descubiertos (patrones dados)
    (
      (uso ILIKE 'Residencial_Garajes_Descubiertos%') OR
      (uso ILIKE 'Comercial.Parqueaderos%') OR
      (uso ILIKE 'Comercial.Parqueaderos_en_PH%')
    ) AS es_parqueadero_descubierto,
    -- No construida: área de construcción = 0
    (COALESCE(area_construccion,0) = 0) AS es_no_construida
  FROM uc_join
),
-- Conteo de UC válidas por predio (NOT de las exclusiones)
uc_agg AS (
  SELECT
    id_operacion,
    COUNT(*) FILTER (WHERE uc_objectid IS NOT NULL
                     AND NOT (es_parqueadero_descubierto OR es_no_construida)) AS n_uc_validas,
    -- Muestra de hasta 3 UCs (uso|area) para diagnóstico
    array_to_string(
      (ARRAY_AGG( ('uso='||COALESCE(uso,'NULL')||', area_construccion='||COALESCE(area_construccion::text,'NULL'))
                  ORDER BY uc_objectid NULLS LAST))[1:3],
      ' || '
    ) AS uc_muestra
  FROM uc_marcada
  GROUP BY id_operacion
),
base AS (
  SELECT
    po.*,
    COALESCE(a.n_uc_validas,0)                               AS n_uc_validas,
    COALESCE(NULLIF(a.uc_muestra,''),'(sin UC o todas excluidas)') AS uc_muestra
  FROM predios_objetivo po
  LEFT JOIN uc_agg a USING (id_operacion)
)
SELECT
  '762'::text                     AS regla,
  'ILC_Predio'::text             AS objeto,
  'preprod.ilc_predio'::text     AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: PH.Unidad_Predial/Informal (s22=2, s27_30<>0000) debe tener ≥1 UC válida; '||
  'se excluyen parqueaderos/garajes descubiertos (Residencial_Garajes_Descubiertos, Comercial.Parqueaderos, Comercial.Parqueaderos_en_PH) '||
  'y UC no construidas (area_construccion=0).'::text AS descripcion,
  (
    'condicion='||b.condicion||
    ', s22='||b.s22||
    ', s27_30='||b.s27_30||
    ', n_uc_validas='||b.n_uc_validas||
    ', muestra=['||b.uc_muestra||']'
  )::text                        AS valor,
  FALSE                          AS cumple,
  NOW()                          AS created_at,
  NOW()                          AS updated_at
FROM base b
WHERE b.n_uc_validas = 0
ORDER BY b.id_operacion, b.objectid;


--774
DROP TABLE IF EXISTS reglas.regla_774;

CREATE TABLE reglas.regla_774 AS
WITH uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio) AS id_operacion,
    u.planta_ubicacion
  FROM preprod.cr_unidadconstruccion u
)
SELECT
  '774'::text             AS regla,
  'CR_UnidadConstruccion'::text AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  uc.objectid,
  uc.globalid,
  uc.id_operacion,
  COALESCE(uc.planta_ubicacion::text,'(NULL)') AS planta,
  'INCUMPLE: CR_UnidadConstruccion.Planta_Ubicacion debe ser > 0'::text AS descripcion,
  (
    'planta_ubicacion='||COALESCE(uc.planta_ubicacion::text,'NULL')
  )::text AS valor,
  FALSE AS cumple,
  NOW()  AS created_at,
  NOW()  AS updated_at
FROM uc
WHERE COALESCE(uc.planta_ubicacion,0) <= 0
ORDER BY uc.id_operacion, uc.objectid;

--771
DROP TABLE IF EXISTS reglas.regla_771;

CREATE TABLE reglas.regla_771 AS
WITH cuc AS (
  SELECT
    c.objectid,
    c.globalid,
    c.id_caracteristicas_unidad_cons     AS cuc_id,
    lower(btrim(c.tipo_unidad_construccion)) AS tipo_uc,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc AS (
  SELECT
    u.id_caracteristicasunidadconstru    AS cuc_id_fk,
    btrim(u.id_operacion_predio)         AS id_operacion
  FROM preprod.cr_unidadconstruccion u
),
cuc_uc AS (
  SELECT
    c.objectid,
    c.globalid,
    u.id_operacion,
    c.tipo_uc,
    c.uso
  FROM cuc c
  LEFT JOIN uc u ON u.cuc_id_fk = c.cuc_id
)
SELECT
  '771'::text                                              AS regla,
  'ILC_CaracteristicasUnidadConstruccion'::text            AS objeto,
  'preprod.ilc_caracteristicasunidadconstruccion'::text    AS tabla,
  cuc_uc.objectid,
  cuc_uc.globalid,
  cuc_uc.id_operacion,
  NULL::varchar(30)                                        AS npn,
  'INCUMPLE: Si Tipo_Unidad_Construccion = ''Industrial'' el Uso debe ser Industrial.*'::text AS descripcion,
  COALESCE(cuc_uc.uso,'(SIN USO)')                         AS valor,   -- <<< aquí guardamos el uso incumplido
  FALSE                                                    AS cumple,
  NOW()                                                    AS created_at,
  NOW()                                                    AS updated_at
FROM cuc_uc
WHERE cuc_uc.tipo_uc = 'industrial'
  AND (cuc_uc.uso IS NULL OR cuc_uc.uso NOT LIKE 'Industrial%')
ORDER BY cuc_uc.id_operacion, cuc_uc.objectid;

--772
DROP TABLE IF EXISTS reglas.regla_772;

CREATE TABLE reglas.regla_772 AS
WITH cuc AS (
  SELECT
    c.objectid,
    c.globalid,
    c.id_caracteristicas_unidad_cons     AS cuc_id,
    lower(btrim(c.tipo_unidad_construccion)) AS tipo_uc,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc AS (
  SELECT
    u.id_caracteristicasunidadconstru    AS cuc_id_fk,
    btrim(u.id_operacion_predio)         AS id_operacion
  FROM preprod.cr_unidadconstruccion u
),
cuc_uc AS (
  SELECT
    c.objectid,
    c.globalid,
    u.id_operacion,
    c.tipo_uc,
    c.uso
  FROM cuc c
  LEFT JOIN uc u ON u.cuc_id_fk = c.cuc_id
)
SELECT
  '772'::text                                              AS regla,
  'ILC_CaracteristicasUnidadConstruccion'::text            AS objeto,
  'preprod.ilc_caracteristicasunidadconstruccion'::text    AS tabla,
  cuc_uc.objectid,
  cuc_uc.globalid,
  cuc_uc.id_operacion,
  NULL::varchar(30)                                        AS npn,
  'INCUMPLE: Si Tipo_Unidad_Construccion = ''Institucional'' el Uso debe ser Institucional.*'::text AS descripcion,
  COALESCE(cuc_uc.uso,'(SIN USO)')                         AS valor,   -- guardamos el uso incumplido
  FALSE                                                    AS cumple,
  NOW()                                                    AS created_at,
  NOW()                                                    AS updated_at
FROM cuc_uc
WHERE cuc_uc.tipo_uc = 'institucional'
  AND (cuc_uc.uso IS NULL OR cuc_uc.uso NOT LIKE 'Institucional%')
ORDER BY cuc_uc.id_operacion, cuc_uc.objectid;

--773

DROP TABLE IF EXISTS reglas.regla_773;

CREATE TABLE reglas.regla_773 AS
WITH cuc AS (
  SELECT
    c.objectid,
    c.globalid,
    c.id_caracteristicas_unidad_cons                 AS cuc_id,
    lower(btrim(c.tipo_unidad_construccion))         AS tipo_uc,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc AS (
  SELECT
    u.id_caracteristicasunidadconstru                AS cuc_id_fk,
    btrim(u.id_operacion_predio)                     AS id_operacion
  FROM preprod.cr_unidadconstruccion u
),
cuc_uc AS (
  SELECT
    c.objectid,
    c.globalid,
    u.id_operacion,
    c.tipo_uc,
    c.uso
  FROM cuc c
  LEFT JOIN uc u ON u.cuc_id_fk = c.cuc_id
)
SELECT
  '773'::text                                           AS regla,
  'ILC_CaracteristicasUnidadConstruccion'::text         AS objeto,
  'preprod.ilc_caracteristicasunidadconstruccion'::text AS tabla,
  cuc_uc.objectid,
  cuc_uc.globalid,
  cuc_uc.id_operacion,
  NULL::varchar(30)                                     AS npn,  -- no aplica aquí
  'INCUMPLE: Si Tipo_Unidad_Construccion = ''Residencial'' el Uso debe ser Residencial.*'::text AS descripcion,
  COALESCE(cuc_uc.uso,'(SIN USO)')                      AS valor,  -- guarda el uso no-residencial
  FALSE                                                 AS cumple,
  NOW()                                                 AS created_at,
  NOW()                                                 AS updated_at
FROM cuc_uc
WHERE cuc_uc.tipo_uc = 'residencial'
  AND (cuc_uc.uso IS NULL OR cuc_uc.uso NOT LIKE 'Residencial%')
ORDER BY cuc_uc.id_operacion, cuc_uc.objectid;

--775
DROP TABLE IF EXISTS reglas.regla_775_incumple;

CREATE TABLE reglas.regla_775_incumple AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.destinacion_economica))         AS dest_econ,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
predio_hab AS (               -- solo predios Habitacionales
  SELECT *
  FROM predio
  WHERE dest_econ = 'habitacional'
),
uc AS (                       -- UC con FK a CUC y área en 9377 (m²) sin UPDATE
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio)      AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id_fk,
    -- Si el SRID es 0, asumimos 9377; transformamos solo si es distinto a 9377
    COALESCE(
      ST_Area(
        CASE
          WHEN COALESCE(NULLIF(ST_SRID(u.shape),0), 9377) = 9377 THEN
            ST_CollectionExtract(ST_MakeValid(u.shape), 3)
          ELSE
            ST_Transform(
              ST_CollectionExtract(
                ST_MakeValid(
                  ST_SetSRID(u.shape, COALESCE(NULLIF(ST_SRID(u.shape),0), 9377))
                ), 3
              ),
              9377
            )
        END
      ),
      0
    ) AS area_m2
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (                      -- características de la UC (para el Uso)
  SELECT
    c.id_caracteristicas_unidad_cons  AS cuc_id,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc_en_predio AS (             -- UC de cada predio con su Uso
  SELECT
    ph.objectid     AS predio_objectid,
    ph.globalid     AS predio_globalid,
    ph.id_operacion AS id_operacion,
    ph.npn          AS npn,
    u.objectid      AS uc_objectid,
    u.globalid      AS uc_globalid,
    u.area_m2,
    c.uso,
    (c.uso ILIKE 'Residencial%') AS es_residencial
  FROM predio_hab ph
  LEFT JOIN uc  u ON u.id_operacion = ph.id_operacion
  LEFT JOIN cuc c ON c.cuc_id = u.cuc_id_fk
),
agg AS (                      -- agregados por predio
  SELECT
    id_operacion,
    npn,
    predio_objectid AS objectid,
    predio_globalid AS globalid,
    COUNT(uc_objectid)                                      AS n_uc_total,
    COUNT(*) FILTER (WHERE es_residencial)                  AS n_uc_residenciales,
    SUM(area_m2)                                            AS area_total_uc,
    SUM(area_m2) FILTER (WHERE es_residencial)              AS area_residencial
  FROM uc_en_predio
  GROUP BY id_operacion, npn, objectid, globalid
),
base AS (                    -- razones y métricas finales
  SELECT
    a.objectid,
    a.globalid,
    a.id_operacion,
    a.npn,
    a.n_uc_total,
    a.n_uc_residenciales,
    COALESCE(a.area_total_uc,0)    AS area_total_uc,
    COALESCE(a.area_residencial,0) AS area_residencial,
    CASE
      WHEN COALESCE(a.area_total_uc,0) = 0 THEN 0::numeric
      ELSE ROUND((a.area_residencial / NULLIF(a.area_total_uc,0))::numeric, 6)
    END AS ratio_residencial
  FROM agg a
)
SELECT
  '775'::text                 AS regla,
  'ILC_Predio'::text          AS objeto,
  'preprod.ilc_predio'::text  AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  CASE
    WHEN b.n_uc_total = 0 THEN
      'INCUMPLE: Predio Habitacional sin CR_UnidadConstruccion asociadas.'
    WHEN b.n_uc_residenciales = 0 THEN
      'INCUMPLE: Sin UC con Uso Residencial (Uso ILIKE ''Residencial%'').'
    ELSE
      'INCUMPLE: Área de UC Residencial no predominante (<50%). ' ||
      'n_uc_residenciales='||b.n_uc_residenciales||
      ', area_residencial_m2='||ROUND(b.area_residencial::numeric,2)||
      ', area_total_uc_m2='||ROUND(b.area_total_uc::numeric,2)||
      ', ratio='||ROUND(b.ratio_residencial,4)
  END::text                 AS descripcion,
  b.ratio_residencial::numeric(38,8) AS valor,
  FALSE                        AS cumple,
  NOW()                        AS created_at,
  NOW()                        AS updated_at
FROM base b
WHERE b.n_uc_total = 0
   OR b.n_uc_residenciales = 0
   OR b.ratio_residencial < 0.5
ORDER BY b.id_operacion, b.objectid;


--776
DROP TABLE IF EXISTS reglas.regla_776_incumple;

CREATE TABLE reglas.regla_776_incumple AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.destinacion_economica))         AS dest_econ,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
predio_com AS (               -- solo predios Comerciales
  SELECT *
  FROM predio
  WHERE dest_econ = 'comercial'
),
uc AS (                       -- UC con área en 9377 (m²), robusto a SRID=0, sin UPDATE
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio)      AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id_fk,
    COALESCE(
      ST_Area(
        CASE
          WHEN COALESCE(NULLIF(ST_SRID(u.shape),0), 9377) = 9377 THEN
            ST_CollectionExtract(ST_MakeValid(u.shape), 3)
          ELSE
            ST_Transform(
              ST_CollectionExtract(
                ST_MakeValid(
                  ST_SetSRID(u.shape, COALESCE(NULLIF(ST_SRID(u.shape),0), 9377))
                ), 3
              ),
              9377
            )
        END
      ),
      0
    ) AS area_m2
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (                      -- características
  SELECT
    c.id_caracteristicas_unidad_cons AS cuc_id,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc_en_predio AS (             -- UC de cada predio con su Uso
  SELECT
    pc.objectid     AS predio_objectid,
    pc.globalid     AS predio_globalid,
    pc.id_operacion AS id_operacion,
    pc.npn,
    u.objectid      AS uc_objectid,
    u.globalid      AS uc_globalid,
    u.area_m2,
    c.uso,
    (c.uso ILIKE 'Comercial%') AS es_comercial,
    -- categoría de uso por prefijo (antes de '.' o '_')
    split_part(replace(coalesce(c.uso,''),'.','_'), '_', 1) AS uso_cat
  FROM predio_com pc
  LEFT JOIN uc  u ON u.id_operacion = pc.id_operacion
  LEFT JOIN cuc c ON c.cuc_id = u.cuc_id_fk
),
agg AS (                      -- agregados por predio (Comercial vs Total)
  SELECT
    id_operacion,
    npn,
    predio_objectid AS objectid,
    predio_globalid AS globalid,
    COUNT(uc_objectid)                               AS n_uc_total,
    COUNT(*) FILTER (WHERE es_comercial)             AS n_uc_comerciales,
    SUM(area_m2)                                     AS area_total_uc,
    SUM(area_m2) FILTER (WHERE es_comercial)         AS area_comercial
  FROM uc_en_predio
  GROUP BY id_operacion, npn, objectid, globalid
),
areas_por_uso AS (            -- suma de área por categoría de uso
  SELECT
    id_operacion,
    uso_cat,
    SUM(area_m2) AS area_uso
  FROM uc_en_predio
  GROUP BY id_operacion, uso_cat
),
uso_top AS (                  -- uso predominante (mayor área) por predio
  SELECT
    a.id_operacion,
    a.uso_cat AS uso_top,
    a.area_uso AS area_top,
    ROW_NUMBER() OVER (PARTITION BY a.id_operacion ORDER BY a.area_uso DESC NULLS LAST) AS rn
  FROM areas_por_uso a
),
base AS (                     -- métrica final + join con uso predominante
  SELECT
    g.objectid,
    g.globalid,
    g.id_operacion,
    g.npn,
    g.n_uc_total,
    g.n_uc_comerciales,
    COALESCE(g.area_total_uc,0)  AS area_total_uc,
    COALESCE(g.area_comercial,0) AS area_comercial,
    CASE
      WHEN COALESCE(g.area_total_uc,0) = 0 THEN 0::numeric
      ELSE ROUND((g.area_comercial / NULLIF(g.area_total_uc,0))::numeric, 6)
    END AS ratio_comercial,
    ut.uso_top,
    COALESCE(ut.area_top,0)      AS area_top
  FROM agg g
  LEFT JOIN uso_top ut
    ON ut.id_operacion = g.id_operacion AND ut.rn = 1
)
SELECT
  '776'::text                AS regla,
  'ILC_Predio'::text         AS objeto,
  'preprod.ilc_predio'::text AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  CASE
    WHEN b.n_uc_total = 0 THEN
      'INCUMPLE: Predio Comercial sin CR_UnidadConstruccion asociadas.'
    WHEN b.n_uc_comerciales = 0 THEN
      'INCUMPLE: Sin UC con Uso Comercial (Uso ILIKE ''Comercial%'').'
    WHEN b.area_total_uc > 0 AND b.area_comercial < b.area_top THEN
      'INCUMPLE: El uso predominante es '||COALESCE(b.uso_top,'(desconocido)')
      ||' con '||ROUND(b.area_top::numeric,2)||' m² ('
      ||ROUND( (100*b.area_top/NULLIF(b.area_total_uc,0))::numeric, 2 )||'%). '
      ||'Comercial tiene '||ROUND(b.area_comercial::numeric,2)||' m² ('
      ||ROUND( (100*b.area_comercial/NULLIF(b.area_total_uc,0))::numeric, 2 )||'%).'
    ELSE
      'INCUMPLE: Área de UC Comercial no predominante.'
  END AS descripcion,
  -- valor en porcentaje (0–100), no proporción
  ROUND( (100*b.ratio_comercial)::numeric, 2 ) AS valor,
  FALSE                             AS cumple,
  NOW()                             AS created_at,
  NOW()                             AS updated_at
FROM base b
WHERE b.n_uc_total = 0
   OR b.n_uc_comerciales = 0
   OR (b.area_total_uc > 0 AND b.area_comercial < b.area_top)
ORDER BY b.id_operacion, b.objectid;


--777
DROP TABLE IF EXISTS reglas.regla_777;

CREATE TABLE reglas.regla_777 AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.destinacion_economica))         AS dest_econ,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
predio_ind AS (              -- solo predios Industriales
  SELECT *
  FROM predio
  WHERE dest_econ = 'industrial'
),
-- UC con área en 9377 (m²), robusto (SRID=0, no-polígonos), sin UPDATE
uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio)      AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id_fk,
    COALESCE(
      ST_Area(
        CASE
          WHEN COALESCE(NULLIF(ST_SRID(u.shape),0), 9377) = 9377 THEN
            ST_CollectionExtract(ST_MakeValid(u.shape), 3)
          ELSE
            ST_Transform(
              ST_CollectionExtract(
                ST_MakeValid(
                  ST_SetSRID(u.shape, COALESCE(NULLIF(ST_SRID(u.shape),0), 9377))
                ), 3
              ),
              9377
            )
        END
      ),
      0
    ) AS area_m2
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (
  SELECT
    c.id_caracteristicas_unidad_cons AS cuc_id,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc_en_predio AS (            -- UC + Uso
  SELECT
    pi.objectid     AS predio_objectid,
    pi.globalid     AS predio_globalid,
    pi.id_operacion AS id_operacion,
    pi.npn,
    u.objectid      AS uc_objectid,
    u.globalid      AS uc_globalid,
    u.area_m2,
    c.uso,
    (c.uso ILIKE 'Industrial%') AS es_industrial,
    -- categoría por prefijo ('Industrial.x' o 'Industrial_x' -> 'Industrial')
    split_part(replace(coalesce(c.uso,''),'.','_'), '_', 1) AS uso_cat
  FROM predio_ind pi
  LEFT JOIN uc  u ON u.id_operacion = pi.id_operacion
  LEFT JOIN cuc c ON c.cuc_id = u.cuc_id_fk
),
-- agregados Industrial vs total
agg AS (
  SELECT
    id_operacion,
    npn,
    predio_objectid AS objectid,
    predio_globalid AS globalid,
    COUNT(uc_objectid)                              AS n_uc_total,
    COUNT(*) FILTER (WHERE es_industrial)           AS n_uc_industriales,
    SUM(area_m2)                                    AS area_total_uc,
    SUM(area_m2) FILTER (WHERE es_industrial)       AS area_industrial
  FROM uc_en_predio
  GROUP BY id_operacion, npn, objectid, globalid
),
-- suma de área por categoría de uso para hallar el predominante
areas_por_uso AS (
  SELECT
    id_operacion,
    uso_cat,
    SUM(area_m2) AS area_uso
  FROM uc_en_predio
  GROUP BY id_operacion, uso_cat
),
uso_top AS (                  -- uso de mayor área en el predio
  SELECT
    a.id_operacion,
    a.uso_cat AS uso_top,
    a.area_uso AS area_top,
    ROW_NUMBER() OVER (PARTITION BY a.id_operacion ORDER BY a.area_uso DESC NULLS LAST) AS rn
  FROM areas_por_uso a
),
base AS (                     -- métricas finales + uso predominante
  SELECT
    g.objectid,
    g.globalid,
    g.id_operacion,
    g.npn,
    g.n_uc_total,
    g.n_uc_industriales,
    COALESCE(g.area_total_uc,0)   AS area_total_uc,
    COALESCE(g.area_industrial,0) AS area_industrial,
    CASE
      WHEN COALESCE(g.area_total_uc,0) = 0 THEN 0::numeric
      ELSE ROUND((g.area_industrial / NULLIF(g.area_total_uc,0))::numeric, 6)
    END AS ratio_industrial,
    ut.uso_top,
    COALESCE(ut.area_top,0)       AS area_top
  FROM agg g
  LEFT JOIN uso_top ut
    ON ut.id_operacion = g.id_operacion AND ut.rn = 1
)
SELECT
  '777'::text                AS regla,
  'ILC_Predio'::text         AS objeto,
  'preprod.ilc_predio'::text AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  CASE
    WHEN b.n_uc_total = 0 THEN
      'INCUMPLE: Predio Industrial sin CR_UnidadConstruccion asociadas.'
    WHEN b.n_uc_industriales = 0 THEN
      'INCUMPLE: Sin UC con Uso Industrial (Uso ILIKE ''Industrial%'').'
    WHEN b.area_total_uc > 0 AND b.area_industrial < b.area_top THEN
      'INCUMPLE: El uso predominante es '||COALESCE(b.uso_top,'(desconocido)')
      ||' con '||ROUND(b.area_top::numeric,2)||' m² ('
      ||ROUND( (100*b.area_top/NULLIF(b.area_total_uc,0))::numeric, 2 )||'%). '
      ||'Industrial tiene '||ROUND(b.area_industrial::numeric,2)||' m² ('
      ||ROUND( (100*b.area_industrial/NULLIF(b.area_total_uc,0))::numeric, 2 )||'%).'
    ELSE
      'INCUMPLE: Área de UC Industrial no predominante.'
  END AS descripcion,
  -- valor = porcentaje (0–100) del área Industrial
  ROUND( (100*b.ratio_industrial)::numeric, 2 ) AS valor,
  FALSE                             AS cumple,
  NOW()                             AS created_at,
  NOW()                             AS updated_at
FROM base b
WHERE b.n_uc_total = 0
   OR b.n_uc_industriales = 0
   OR (b.area_total_uc > 0 AND b.area_industrial < b.area_top)
ORDER BY b.id_operacion, b.objectid;

--778
DROP TABLE IF EXISTS reglas.regla_778_incumple;

CREATE TABLE reglas.regla_778_incumple AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.destinacion_economica))         AS dest_econ,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
predio_obj AS (  -- Institucional/Cultural/Educativo/Religioso (soporta el typo "Eductaivo")
  SELECT *
  FROM predio
  WHERE dest_econ IN ('institucional','cultural','educativo','eductaivo','religioso')
),
-- UC con área en 9377 (m²), robusto a SRID=0 y no-polígonos, sin UPDATE
uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio)      AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id_fk,
    COALESCE(
      ST_Area(
        CASE
          WHEN COALESCE(NULLIF(ST_SRID(u.shape),0), 9377) = 9377 THEN
            ST_CollectionExtract(ST_MakeValid(u.shape), 3)
          ELSE
            ST_Transform(
              ST_CollectionExtract(
                ST_MakeValid(
                  ST_SetSRID(u.shape, COALESCE(NULLIF(ST_SRID(u.shape),0), 9377))
                ), 3
              ),
              9377
            )
        END
      ),
      0
    ) AS area_m2
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (
  SELECT
    c.id_caracteristicas_unidad_cons AS cuc_id,
    c.uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc_en_predio AS (  -- UC + Uso (y categoría por prefijo)
  SELECT
    po.objectid     AS predio_objectid,
    po.globalid     AS predio_globalid,
    po.id_operacion AS id_operacion,
    po.npn,
    u.objectid      AS uc_objectid,
    u.globalid      AS uc_globalid,
    u.area_m2,
    c.uso,
    (c.uso ILIKE 'Institucional%') AS es_institucional,
    split_part(replace(coalesce(c.uso,''),'.','_'), '_', 1) AS uso_cat
  FROM predio_obj po
  LEFT JOIN uc  u ON u.id_operacion = po.id_operacion
  LEFT JOIN cuc c ON c.cuc_id = u.cuc_id_fk
),
-- agregados Institucional vs total
agg AS (
  SELECT
    id_operacion,
    npn,
    predio_objectid AS objectid,
    predio_globalid AS globalid,
    COUNT(uc_objectid)                               AS n_uc_total,
    COUNT(*) FILTER (WHERE es_institucional)         AS n_uc_institucionales,
    SUM(area_m2)                                     AS area_total_uc,
    SUM(area_m2) FILTER (WHERE es_institucional)     AS area_institucional
  FROM uc_en_predio
  GROUP BY id_operacion, npn, objectid, globalid
),
-- suma de área por categoría de uso para hallar predominante
areas_por_uso AS (
  SELECT
    id_operacion,
    uso_cat,
    SUM(area_m2) AS area_uso
  FROM uc_en_predio
  GROUP BY id_operacion, uso_cat
),
uso_top AS (  -- uso de mayor área
  SELECT
    a.id_operacion,
    a.uso_cat AS uso_top,
    a.area_uso AS area_top,
    ROW_NUMBER() OVER (PARTITION BY a.id_operacion ORDER BY a.area_uso DESC NULLS LAST) AS rn
  FROM areas_por_uso a
),
base AS (  -- métricas finales + uso predominante
  SELECT
    g.objectid,
    g.globalid,
    g.id_operacion,
    g.npn,
    g.n_uc_total,
    g.n_uc_institucionales,
    COALESCE(g.area_total_uc,0)      AS area_total_uc,
    COALESCE(g.area_institucional,0) AS area_institucional,
    CASE
      WHEN COALESCE(g.area_total_uc,0) = 0 THEN 0::numeric
      ELSE ROUND((g.area_institucional / NULLIF(g.area_total_uc,0))::numeric, 6)
    END AS ratio_institucional,
    ut.uso_top,
    COALESCE(ut.area_top,0)          AS area_top
  FROM agg g
  LEFT JOIN uso_top ut
    ON ut.id_operacion = g.id_operacion AND ut.rn = 1
)
SELECT
  '778'::text                AS regla,
  'ILC_Predio'::text         AS objeto,
  'preprod.ilc_predio'::text AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  CASE
    WHEN b.n_uc_total = 0 THEN
      'INCUMPLE: Predio Institucional/Cultural/Educativo/Religioso sin CR_UnidadConstruccion asociadas.'
    WHEN b.n_uc_institucionales = 0 THEN
      'INCUMPLE: Sin UC con Uso Institucional (Uso ILIKE ''Institucional%'').'
    WHEN b.area_total_uc > 0 AND b.area_institucional < b.area_top THEN
      'INCUMPLE: El uso predominante es '||COALESCE(b.uso_top,'(desconocido)')
      ||' con '||ROUND(b.area_top::numeric,2)||' m² ('
      ||ROUND( (100*b.area_top/NULLIF(b.area_total_uc,0))::numeric, 2 )||'%). '
      ||'Institucional tiene '||ROUND(b.area_institucional::numeric,2)||' m² ('
      ||ROUND( (100*b.area_institucional/NULLIF(b.area_total_uc,0))::numeric, 2 )||'%).'
    ELSE
      'INCUMPLE: Área de UC Institucional no predominante.'
  END AS descripcion,
  -- valor = porcentaje (0–100) del área institucional sobre el total UC
  ROUND( (100*b.ratio_institucional)::numeric, 2 ) AS valor,
  FALSE                             AS cumple,
  NOW()                             AS created_at,
  NOW()                             AS updated_at
FROM base b
WHERE b.n_uc_total = 0
   OR b.n_uc_institucionales = 0
   OR (b.area_total_uc > 0 AND b.area_institucional < b.area_top)
ORDER BY b.id_operacion, b.objectid;

--779
-- Regla 779: CR/ILC_CaracteristicasUnidadConstruccion.Total_Plantas > 0
DROP TABLE IF EXISTS reglas.779;

CREATE TABLE reglas.779 AS
WITH cuc AS (
  SELECT
    c.objectid,
    c.globalid,
    c.id_caracteristicas_unidad_cons       AS cuc_id,
    c.total_plantas
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
uc AS (
  SELECT
    u.id_caracteristicasunidadconstru      AS cuc_id_fk,
    btrim(u.id_operacion_predio)           AS id_operacion
  FROM preprod.cr_unidadconstruccion u
),
predio AS (
  SELECT
    btrim(p.id_operacion)                  AS id_operacion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
cuc_uc AS (
  SELECT
    c.objectid,
    c.globalid,
    u.id_operacion,
    c.total_plantas
  FROM cuc c
  LEFT JOIN uc u ON u.cuc_id_fk = c.cuc_id
),
base AS (
  SELECT
    cu.objectid,
    cu.globalid,
    cu.id_operacion,
    COALESCE(pr.npn, NULL) AS npn,
    cu.total_plantas
  FROM cuc_uc cu
  LEFT JOIN predio pr ON pr.id_operacion = cu.id_operacion
)
SELECT
  '779'::text                                             AS regla,
  'ILC_CaracteristicasUnidadConstruccion'::text           AS objeto,
  'preprod.ilc_caracteristicasunidadconstruccion'::text   AS tabla,
  b.objectid,
  b.globalid,
  b.id_operacion,
  b.npn,
  CASE
    WHEN b.total_plantas IS NULL THEN
      'INCUMPLE: Total_Plantas es NULL; debe ser > 0.'
    WHEN b.total_plantas <= 0 THEN
      'INCUMPLE: Total_Plantas = '||b.total_plantas||'; debe ser > 0.'
  END::text                                               AS descripcion,
  COALESCE(b.total_plantas, 0)::numeric(38,8)             AS valor,   -- para métricas
  FALSE                                                   AS cumple,
  NOW()                                                   AS created_at,
  NOW()                                                   AS updated_at
FROM base b
WHERE b.total_plantas IS NULL
   OR b.total_plantas <= 0
ORDER BY b.id_operacion, b.objectid;



--780

-- Regla 780: PH/Condominio_UnidadPredial deben tener Area_Construccion=0 y Area_Privada_Construida>0
DROP TABLE IF EXISTS reglas.regla_780;

CREATE TABLE reglas.regla_780 AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.condicion_predio))              AS condicion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN ('ph_unidad_predial','condominio_unidad_predial')
),
uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio) AS id_operacion,
    u.area_construccion,
    u.area_privada_construida
  FROM preprod.cr_unidadconstruccion u
),
base AS (
  SELECT
    pr.objectid   AS predio_objectid,
    pr.globalid   AS predio_globalid,
    pr.id_operacion,
    pr.condicion,
    pr.npn,
    uc.objectid   AS uc_objectid,
    uc.globalid   AS uc_globalid,
    uc.area_construccion,
    uc.area_privada_construida
  FROM predio pr
  LEFT JOIN uc ON uc.id_operacion = pr.id_operacion
)
SELECT
  '780'::text                  AS regla,
  'CR_UnidadConstruccion'::text AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  b.uc_objectid                AS objectid,
  b.uc_globalid                AS globalid,
  b.id_operacion,
  b.npn,
  'INCUMPLE: Si Condicion_Predio='||b.condicion||
  ' entonces Area_Construccion debe ser 0 y Area_Privada_Construida > 0. '||
  'Valores: Area_Construccion='||COALESCE(b.area_construccion::text,'NULL')||
  ', Area_Privada_Construida='||COALESCE(b.area_privada_construida::text,'NULL')
  AS descripcion,
('Area_Construccion='||COALESCE(b.area_construccion::text,'NULL')||
 ', Area_Privada_Construida='||COALESCE(b.area_privada_construida::text,'NULL')) AS valor,
  FALSE                       AS cumple,
  NOW()                       AS created_at,
  NOW()                       AS updated_at
FROM base b
WHERE b.area_construccion IS DISTINCT FROM 0
   OR b.area_privada_construida IS NULL
   OR b.area_privada_construida <= 0
ORDER BY b.id_operacion, b.uc_objectid;

-- REGLA 763 - INCUMPLE
-- Predios PH/Condominio unidad predial: UC (tipo R/C/I/I) deben tener Uso con 'PH' o 'Depositos_Lockers'

DROP TABLE IF EXISTS reglas.763;

CREATE TABLE reglas.763 AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.condicion_predio))              AS condicion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) IN (
    'ph_unidad_predial','ph.unidad_predial',
    'condominio_unidad_predial','condominio.unidad_predial'
  )
),
uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio)      AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id_fk
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (
  SELECT
    c.id_caracteristicas_unidad_cons     AS cuc_id,
    btrim(c.tipo_unidad_construccion)    AS tipo_uc,
    c.uso                                AS uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
predio_uc AS (  -- Predio -> UC -> CUC
  SELECT
    pr.objectid      AS predio_objectid,
    pr.globalid      AS predio_globalid,
    pr.id_operacion,
    pr.npn,
    pr.condicion,
    u.objectid       AS uc_objectid,
    u.globalid       AS uc_globalid,
    c.tipo_uc,
    c.uso
  FROM predio pr
  LEFT JOIN uc  u ON u.id_operacion = pr.id_operacion
  LEFT JOIN cuc c ON c.cuc_id       = u.cuc_id_fk
),
-- Normalizamos tipo y evaluamos la condición de "Uso con PH o Depositos_Lockers"
eval AS (
  SELECT
    p.*,
    lower(btrim(tipo_uc)) AS tipo_uc_l,
    CASE
      WHEN uso IS NULL THEN FALSE
      -- Acepta cualquier presencia de 'PH' (._PH, en_PH, etc.) o 'Depositos_Lockers'
      WHEN uso ILIKE '%PH%' OR uso ILIKE '%Depositos_Lockers%' THEN TRUE
      ELSE FALSE
    END AS uso_es_ph
  FROM predio_uc p
)
SELECT
  '763'::text                          AS regla,
  'CR_UnidadConstruccion'::text        AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  e.uc_objectid                        AS objectid,
  e.uc_globalid                        AS globalid,
  e.id_operacion,
  e.npn,
  (
    'INCUMPLE: Predio ('||e.condicion||') con UC tipo='||
    COALESCE(e.tipo_uc,'NULL')||
    ' debe tener Uso con ''PH'' o ''Depositos_Lockers'', pero uso='||
    COALESCE(e.uso,'NULL')
  )::text                              AS descripcion,
  -- valor: tipo_uc | uso (para depurar rápido)
  (COALESCE(e.tipo_uc,'NULL')||' | '||COALESCE(e.uso,'NULL'))::text AS valor,
  FALSE                                 AS cumple,
  NOW()                                  AS created_at,
  NOW()                                  AS updated_at
FROM eval e
WHERE e.uc_objectid IS NOT NULL
  AND e.tipo_uc_l IN ('residencial','comercial','institucional','industrial')
  AND e.uso_es_ph = FALSE
ORDER BY e.id_operacion, e.uc_objectid;


-- REGLA 781 - INCUMPLE
-- Predios que NO son PH_Unidad_Predial ni Condominio_Unidad_Predial:
-- sus UC deben tener area_construccion > 0 y area_privada_construida = NULL

DROP TABLE IF EXISTS reglas.781;

CREATE TABLE reglas.781 AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.condicion_predio))              AS condicion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
  WHERE lower(btrim(p.condicion_predio)) NOT IN (
    'ph_unidad_predial','ph.unidad_predial',
    'condominio_unidad_predial','condominio.unidad_predial'
  )
),
uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio) AS id_operacion,
    u.area_construccion,
    u.area_privada_construida
  FROM preprod.cr_unidadconstruccion u
),
predio_uc AS (
  SELECT
    pr.objectid   AS predio_objectid,
    pr.globalid   AS predio_globalid,
    pr.id_operacion,
    pr.npn,
    pr.condicion,
    u.objectid    AS uc_objectid,
    u.globalid    AS uc_globalid,
    u.area_construccion,
    u.area_privada_construida
  FROM predio pr
  LEFT JOIN uc u ON u.id_operacion = pr.id_operacion
)
SELECT
  '781'::text                          AS regla,
  'CR_UnidadConstruccion'::text        AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  p.uc_objectid                        AS objectid,
  p.uc_globalid                        AS globalid,
  p.id_operacion,
  p.npn,
  'INCUMPLE: Predio con condicion='||p.condicion||
  ' (no PH_Unidad_Predial/Condominio_Unidad_Predial) debe tener UC con area_construccion>0 y area_privada_construida=NULL. '||
  'Valores: area_construccion='||COALESCE(p.area_construccion::text,'NULL')||
  ', area_privada_construida='||COALESCE(p.area_privada_construida::text,'NULL')
  AS descripcion,
  (COALESCE(p.area_construccion::text,'NULL')||'|'||COALESCE(p.area_privada_construida::text,'NULL')) AS valor,
  FALSE                                 AS cumple,
  NOW()                                 AS created_at,
  NOW()                                 AS updated_at
FROM predio_uc p
WHERE p.uc_objectid IS NOT NULL
  AND (p.area_construccion IS NULL OR p.area_construccion <= 0 OR p.area_privada_construida IS NOT NULL)
ORDER BY p.id_operacion, p.uc_objectid;
-- REGLA 782 - INCUMPLE
-- Comparación de área declarada vs área geométrica de UC.
--   - Predio NO PH/Condominio_Unidad_Predial: usa area_construccion
--   - Predio SÍ PH/Condominio_Unidad_Predial: usa area_privada_construida
-- INCUMPLE si: area_declarada es NULL/0 o abs(declarada - geom)/declarada > 1

DROP TABLE IF EXISTS reglas.regla_782;

CREATE TABLE reglas.regla_782 AS
WITH predio AS (
  SELECT
    p.objectid,
    p.globalid,
    btrim(p.id_operacion)                         AS id_operacion,
    lower(btrim(p.condicion_predio))              AS condicion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
uc_raw AS (  -- UC con áreas declaradas
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio) AS id_operacion,
    u.area_construccion,
    u.area_privada_construida,
    u.shape
  FROM preprod.cr_unidadconstruccion u
),
-- Área geométrica (m²) robusta (SRID=0 → 9377; MakeValid; solo polígonos; transform a 9377 si aplica)
uc_area AS (
  SELECT
    r.objectid,
    r.globalid,
    r.id_operacion,
    r.area_construccion,
    r.area_privada_construida,
    COALESCE(
      ST_Area(
        CASE
          WHEN ST_IsEmpty(r.shape) THEN NULL
          ELSE
            CASE
              WHEN COALESCE(NULLIF(ST_SRID(r.shape),0), 9377) = 9377
                THEN ST_Force2D(ST_CollectionExtract(ST_MakeValid(r.shape), 3))
              ELSE ST_Transform(
                     ST_Force2D(
                       ST_SetSRID(
                         ST_CollectionExtract(ST_MakeValid(r.shape), 3),
                         COALESCE(NULLIF(ST_SRID(r.shape),0), 9377)
                       )
                     ),
                     9377
                   )
            END
        END
      ),
      0
    ) AS area_geom_m2
  FROM uc_raw r
),
-- Predio ↔ UC (elige el área declarada correcta según la condición del predio)
base AS (
  SELECT
    pr.objectid        AS predio_objectid,
    pr.globalid        AS predio_globalid,
    pr.id_operacion,
    pr.npn,
    pr.condicion,
    ua.objectid        AS uc_objectid,
    ua.globalid        AS uc_globalid,
    ua.area_geom_m2,
    ua.area_construccion,
    ua.area_privada_construida,
    CASE
      WHEN pr.condicion IN ('ph_unidad_predial','ph.unidad_predial',
                            'condominio_unidad_predial','condominio.unidad_predial')
        THEN ua.area_privada_construida
      ELSE ua.area_construccion
    END AS area_declarada
  FROM predio pr
  LEFT JOIN uc_area ua ON ua.id_operacion = pr.id_operacion
),
calc AS (
  SELECT
    b.*,
    CASE
      WHEN area_declarada IS NULL OR area_declarada = 0 THEN NULL
      ELSE ROUND( (ABS(area_declarada - area_geom_m2) / NULLIF(area_declarada,0))::numeric, 6 )
    END AS ratio_diff
  FROM base b
)
SELECT
  '782'::text                         AS regla,
  'CR_UnidadConstruccion'::text       AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  c.uc_objectid                       AS objectid,
  c.uc_globalid                       AS globalid,
  c.id_operacion,
  c.npn,
  CASE
    WHEN c.area_declarada IS NULL OR c.area_declarada = 0 THEN
      'INCUMPLE: Área declarada es NULL o 0; no es posible validar contra geometría. '||c.detalle
    WHEN c.ratio_diff IS NULL THEN
      'INCUMPLE: No fue posible calcular la diferencia de áreas (divisor 0 o geometría vacía). '||c.detalle
    WHEN c.ratio_diff > 1 THEN
      'INCUMPLE: La diferencia relativa entre área declarada y geométrica supera el límite (≤ 1). '||c.detalle
    ELSE
      'INCUMPLE: Diferencia no especificada pero excede criterios.' -- fallback
  END AS descripcion,
  ROUND( (COALESCE(c.ratio_diff, 0) * 100)::numeric, 2 ) AS valor,  -- porcentaje 0–100
  FALSE                                  AS cumple,
  NOW()                                   AS created_at,
  NOW()                                   AS updated_at
FROM (
  SELECT
    calc.*,
    -- ★ AQUÍ FALTABA EL FROM calc ★
    ('condicion='||calc.condicion||
     ', area_declarada='||COALESCE(calc.area_declarada::text,'NULL')||
     ', area_geom_m2='||ROUND(COALESCE(calc.area_geom_m2,0)::numeric,2)||
     ', diff_abs='||ROUND(ABS(COALESCE(calc.area_declarada,0) - COALESCE(calc.area_geom_m2,0))::numeric,2)||
     ', diff_ratio='||COALESCE(calc.ratio_diff::text,'NULL')
    ) AS detalle
  FROM calc
) c
WHERE c.uc_objectid IS NOT NULL
  AND (
        c.area_declarada IS NULL OR c.area_declarada = 0
        OR c.ratio_diff IS NULL
        OR c.ratio_diff > 1
      )
ORDER BY c.id_operacion, c.uc_objectid;

--783
ROLLBACK;
DROP TABLE IF exists reglas.regla_783;
CREATE TABLE reglas.regla_783 AS
WITH params AS (
  SELECT 0.01::numeric AS tolerancia, 9377::int AS srid_target
),
predio AS (
  SELECT btrim(p.id_operacion) AS id_operacion,
         btrim(p.numero_predial_nacional)::varchar(30) AS npn,
         lower(btrim(p.condicion_predio)) AS condicion
  FROM preprod.ilc_predio p
),
uc_norm AS (
  SELECT pr.id_operacion, pr.npn, pr.condicion,
         u.identificador, u.area_construccion, u.area_privada_construida,
         ST_Force2D(ST_CollectionExtract(ST_MakeValid(u.shape), 3)) AS geom2d
  FROM preprod.cr_unidadconstruccion u
  JOIN predio pr ON pr.id_operacion = btrim(u.id_operacion_predio)
),
uc_area AS (
  SELECT n.id_operacion, n.npn, n.condicion, n.identificador,
         n.area_construccion, n.area_privada_construida,
         CASE
           WHEN n.geom2d IS NULL OR ST_IsEmpty(n.geom2d) THEN 0::double precision
           ELSE ST_Area(
                  CASE
                    WHEN COALESCE(NULLIF(ST_SRID(n.geom2d),0),0)=0 THEN
                      CASE
                        WHEN (abs(ST_XMin(ST_Envelope(n.geom2d)))<=180 AND
                              abs(ST_XMax(ST_Envelope(n.geom2d)))<=180 AND
                              abs(ST_YMin(ST_Envelope(n.geom2d)))<=90  AND
                              abs(ST_YMax(ST_Envelope(n.geom2d)))<=90)
                        THEN ST_Transform(ST_SetSRID(n.geom2d,4326),(SELECT srid_target FROM params))
                        ELSE ST_SetSRID(n.geom2d,(SELECT srid_target FROM params))
                      END
                    ELSE ST_Transform(n.geom2d,(SELECT srid_target FROM params))
                  END)
         END AS area_geom_m2
  FROM uc_norm n
),
grp AS (
  SELECT a.npn, a.identificador, a.condicion,
         STRING_AGG(DISTINCT a.id_operacion, ',' ORDER BY a.id_operacion) AS ids_predio,
         COUNT(*) AS n_uc,
         SUM(a.area_geom_m2) AS sum_area_geom_m2,
         SUM(a.area_construccion) AS sum_area_construccion,
         SUM(a.area_privada_construida) AS sum_area_privada
  FROM uc_area a
  GROUP BY a.npn, a.identificador, a.condicion
),
cmp AS (
  SELECT g.npn, g.identificador, g.condicion, g.ids_predio, g.n_uc,
         g.sum_area_geom_m2,
         CASE
           WHEN g.condicion IN ('ph_unidad_predial','ph.unidad_predial',
                                'condominio_unidad_predial','condominio.unidad_predial')
             THEN g.sum_area_privada
           ELSE g.sum_area_construccion
         END AS sum_area_declarada
  FROM grp g
),
eval AS (
  SELECT c.npn, c.identificador, c.condicion, c.ids_predio, c.n_uc,
         c.sum_area_geom_m2, c.sum_area_declarada,
         CASE
           WHEN c.sum_area_declarada IS NULL OR c.sum_area_declarada=0 THEN NULL
           ELSE ROUND((100.0*ABS(c.sum_area_geom_m2 - c.sum_area_declarada)/c.sum_area_declarada)::numeric,2)
         END AS diff_pct,
         CASE
           WHEN c.sum_area_declarada IS NULL OR c.sum_area_declarada=0 THEN FALSE
           ELSE ABS(c.sum_area_geom_m2 - c.sum_area_declarada) <= (SELECT tolerancia FROM params)*c.sum_area_declarada
         END AS cumple_grupo
  FROM cmp c
),
res AS (
  SELECT e.npn,
         MIN(e.ids_predio) AS id_operacion_uno,
         COUNT(*) AS n_grupos,
         COUNT(*) FILTER (WHERE e.cumple_grupo = FALSE) AS n_incumple,
         STRING_AGG(
           (COALESCE(e.identificador,'NULL')||'='||COALESCE(e.diff_pct::text,'NULL')||'%'),
           ', ' ORDER BY e.diff_pct DESC NULLS LAST
         ) FILTER (WHERE e.cumple_grupo = FALSE) AS lista_incumple,
         BOOL_OR(NOT e.cumple_grupo) AS hay_incumple
  FROM eval e
  GROUP BY e.npn
)
SELECT
  '783'::text                           AS regla,
  'CR_UnidadConstruccion'::text         AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  NULL::int4                            AS objectid,
  NULL::varchar(38)                     AS globalid,
  r.id_operacion_uno                    AS id_operacion,
  r.npn                                 AS npn,
  'INCUMPLE: en este predio se evaluaron '||r.n_grupos||' agrupaciones; '||
  r.n_incumple||' incumplen.'           AS descripcion,
  ('(diff%): '||r.lista_incumple||'.')::text AS valor,
  FALSE                                 AS cumple,
  NOW()                                 AS created_at,
  NOW()                                 AS updated_at
FROM res r
WHERE r.hay_incumple; 

--764

ROLLBACK;
drop table if exists reglas.regla_784;
CREATE TABLE reglas.regla_784 AS
WITH predio AS (
  SELECT 
    btrim(p.id_operacion) AS id_operacion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn,
    lower(btrim(p.condicion_predio)) AS condicion
  FROM preprod.ilc_predio p
),
uc AS (
  SELECT 
    u.id_operacion_predio AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (
  SELECT 
    c.id_caracteristicas_unidad_cons AS cuc_id,
    lower(btrim(c.tipo_unidad_construccion)) AS tipo_uc,
    lower(btrim(c.uso)) AS uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
pu AS (
  SELECT 
    p.npn,
    p.condicion,
    c.tipo_uc,
    c.uso
  FROM predio p
  JOIN uc u ON u.id_operacion = p.id_operacion
  JOIN cuc c ON c.cuc_id = u.cuc_id
)
SELECT
  '784'::text                        AS regla,
  'CR_UnidadConstruccion'::text      AS objeto,
  'preprod.cr_unidadconstruccion'    AS tabla,
  NULL::int4                         AS objectid,
  NULL::varchar(38)                  AS globalid,
  NULL::text                         AS id_operacion,
  pu.npn                             AS npn,
  'INCUMPLE: Predio con condición <> PH/Condominio, tipo_uc='||pu.tipo_uc||'.' AS descripcion,
  ('uso='||pu.uso||' contiene "_PH"')::text AS valor,   -- 👉 Aquí el detalle del uso que incumple
  FALSE                               AS cumple,
  NOW()                               AS created_at,
  NOW()                               AS updated_at
FROM pu
WHERE pu.condicion NOT IN ('ph','condominio','ph_unidad_predial','condominio_unidad_predial')
  AND pu.tipo_uc IN ('residencial','comercial','institucional','industrial')
  AND pu.uso LIKE '%_ph%';


--764


ROLLBACK;
drop table if exists reglas.regla_764;
CREATE TABLE reglas.regla_764 AS
WITH predio AS (
  SELECT 
    btrim(p.id_operacion) AS id_operacion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn,
    lower(btrim(p.condicion_predio)) AS condicion
  FROM preprod.ilc_predio p
),
uc AS (
  SELECT 
    u.id_operacion_predio AS id_operacion,
    u.id_caracteristicasunidadconstru AS cuc_id
  FROM preprod.cr_unidadconstruccion u
),
cuc AS (
  SELECT 
    c.id_caracteristicas_unidad_cons AS cuc_id,
    lower(btrim(c.tipo_unidad_construccion)) AS tipo_uc,
    lower(btrim(c.uso)) AS uso
  FROM preprod.ilc_caracteristicasunidadconstruccion c
),
pu AS (
  SELECT 
    p.npn,
    p.condicion,
    c.tipo_uc,
    c.uso
  FROM predio p
  JOIN uc u ON u.id_operacion = p.id_operacion
  JOIN cuc c ON c.cuc_id = u.cuc_id
)
SELECT
  '764'::text                        AS regla,
  'CR_UnidadConstruccion'::text      AS objeto,
  'preprod.cr_unidadconstruccion'    AS tabla,
  NULL::int4                         AS objectid,
  NULL::varchar(38)                  AS globalid,
  NULL::text                         AS id_operacion,
  pu.npn                             AS npn,
  'INCUMPLE: Predio con condición <> PH/Condominio, tipo_uc='||pu.tipo_uc||'.' AS descripcion,
  ('uso='||pu.uso||' contiene "_PH"')::text AS valor,   -- 👉 Aquí el detalle del uso que incumple
  FALSE                               AS cumple,
  NOW()                               AS created_at,
  NOW()                               AS updated_at
FROM pu
WHERE pu.condicion NOT IN ('ph','condominio','ph_unidad_predial','condominio_unidad_predial')
  AND pu.tipo_uc IN ('residencial','comercial','institucional','industrial')
  AND pu.uso LIKE '%_ph%';


--766

ROLLBACK;

CREATE TABLE reglas.regla_766 AS
WITH params AS (
  SELECT 2.00::numeric AS area_min_m2
),
predio AS (
  SELECT 
    btrim(p.id_operacion)                         AS id_operacion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
terreno AS (
  SELECT 
    t.objectid,
    t.globalid,
    btrim(t.id_operacion_predio) AS id_operacion_predio,
    ST_CollectionExtract(ST_MakeValid(t.shape), 3) AS geom_poly
  FROM preprod.cr_terreno t
),
terreno_predio AS (
  SELECT 
    tr.objectid,
    tr.globalid,
    tr.id_operacion_predio,
    pr.npn,
    tr.geom_poly
  FROM terreno tr
  LEFT JOIN predio pr
    ON pr.id_operacion = tr.id_operacion_predio
),
-- 1) Casos SIN geometría (NULL o vacía) -> INCUMPLE
vacios AS (
  SELECT
    tp.objectid,
    tp.globalid,
    tp.id_operacion_predio,
    tp.npn
  FROM terreno_predio tp
  WHERE tp.geom_poly IS NULL OR ST_IsEmpty(tp.geom_poly)
),
-- 2) Partes con geometría válida para cálculo de área
partes AS (
  SELECT 
    s.objectid,
    s.globalid,
    s.id_operacion_predio,
    s.npn,
    (dp).path[1]::int AS part_idx,
    ST_Force2D((dp).geom) AS geom2d
  FROM (
    SELECT tp.*, ST_Dump(tp.geom_poly) AS dp
    FROM terreno_predio tp
    WHERE tp.geom_poly IS NOT NULL AND NOT ST_IsEmpty(tp.geom_poly)
  ) s
),
partes_area AS (
  SELECT 
    p.*,
    -- Área en m² (numérica). Incluye 0 m² si la parte es degenerada.
    CASE
      WHEN p.geom2d IS NULL OR ST_IsEmpty(p.geom2d) THEN 0::numeric
      WHEN (abs(ST_XMin(ST_Envelope(p.geom2d))) <= 180 AND
            abs(ST_XMax(ST_Envelope(p.geom2d))) <= 180 AND
            abs(ST_YMin(ST_Envelope(p.geom2d))) <= 90  AND
            abs(ST_YMax(ST_Envelope(p.geom2d))) <= 90)
        THEN ST_Area(ST_SetSRID(p.geom2d, 4326)::geography)::numeric
      ELSE ST_Area(p.geom2d)::numeric
    END AS area_m2
  FROM partes p
)
-- UNION de incumplimientos:
--  a) Terrenos SIN geometría
--  b) Partes con área < 2.00 m² (incluye 0.00 m²)
SELECT
  '766'::text               AS regla,
  'CR_Terreno'::text        AS objeto,
  'preprod.cr_terreno'::text AS tabla,
  v.objectid                AS objectid,
  v.globalid                AS globalid,
  v.id_operacion_predio     AS id_operacion,
  v.npn,
  'INCUMPLE: terreno sin geometría (NULL/vacía).'::text AS descripcion,
  NULL::numeric            AS valor,       -- sin área porque no hay geometría
  FALSE                    AS cumple,
  NOW()                    AS created_at,
  NOW()                    AS updated_at
FROM vacios v

UNION ALL

SELECT
  '766'::text,
  'CR_Terreno'::text,
  'preprod.cr_terreno'::text,
  pa.objectid,
  pa.globalid,
  pa.id_operacion_predio,
  pa.npn,
  ('INCUMPLE: polígono de terreno (parte='||pa.part_idx||') con área='||
   ROUND(pa.area_m2, 2)::text||' m² < 2.00 m².')::text AS descripcion,
  ROUND(pa.area_m2, 2)      AS valor,
  FALSE                     AS cumple,
  NOW(), NOW()
FROM partes_area pa
WHERE pa.area_m2 < (SELECT area_min_m2 FROM params)
  AND pa.part_idx IS NOT NULL;


--767

ROLLBACK;

CREATE TABLE reglas.regla_767 AS
WITH params AS (
  SELECT 0.5::numeric AS area_min_m2
),
predio AS (
  SELECT 
    btrim(p.id_operacion)                         AS id_operacion,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
uc AS (
  SELECT 
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio) AS id_operacion_predio,
    ST_CollectionExtract(ST_MakeValid(u.shape), 3) AS geom_poly
  FROM preprod.cr_unidadconstruccion u
),
uc_predio AS (
  SELECT 
    u.objectid,
    u.globalid,
    u.id_operacion_predio,
    pr.npn,
    u.geom_poly
  FROM uc u
  LEFT JOIN predio pr
    ON pr.id_operacion = u.id_operacion_predio
),
uc_area AS (
  SELECT 
    u.objectid,
    u.globalid,
    u.id_operacion_predio,
    u.npn,
    -- flag de existencia de geometría válida
    (u.geom_poly IS NOT NULL AND NOT ST_IsEmpty(u.geom_poly)) AS tiene_geom,
    -- área en m² (NULL si no hay geometría)
    CASE
      WHEN u.geom_poly IS NULL OR ST_IsEmpty(u.geom_poly) THEN NULL::numeric
      WHEN (abs(ST_XMin(ST_Envelope(u.geom_poly))) <= 180 AND
            abs(ST_XMax(ST_Envelope(u.geom_poly))) <= 180 AND
            abs(ST_YMin(ST_Envelope(u.geom_poly))) <= 90  AND
            abs(ST_YMax(ST_Envelope(u.geom_poly))) <= 90)
        THEN ST_Area(ST_SetSRID(u.geom_poly, 4326)::geography)::numeric
      ELSE ST_Area(u.geom_poly)::numeric
    END AS area_m2
  FROM uc_predio u
)
SELECT
  '767'::text                           AS regla,
  'CR_UnidadConstruccion'::text         AS objeto,
  'preprod.cr_unidadconstruccion'::text AS tabla,
  ua.objectid,
  ua.globalid,
  ua.id_operacion_predio                AS id_operacion,
  ua.npn,
  CASE 
    WHEN ua.tiene_geom = FALSE THEN
      'INCUMPLE: UC sin geometría (NULL/vacía).'
    WHEN ua.area_m2 <= (SELECT area_min_m2 FROM params) THEN
      'INCUMPLE: UC con área='||ROUND(ua.area_m2,2)::text||' m² <= 0.5 m².'
  END                                    AS descripcion,
  ROUND(ua.area_m2,2)                     AS valor,    -- NULL si no hay geometría
  FALSE                                   AS cumple,
  NOW()                                   AS created_at,
  NOW()                                   AS updated_at
FROM uc_area ua
WHERE ua.tiene_geom = FALSE
   OR ua.area_m2 <= (SELECT area_min_m2 FROM params);

-- REGLA 768 - INCUMPLE (admite duplicados; muestra inválidos en "valor")

DROP TABLE IF EXISTS reglas.regla_768;

CREATE TABLE reglas.regla_768 AS
WITH predio AS (
  SELECT
    btrim(p.id_operacion)                         AS id_operacion,
    p.objectid,
    p.globalid,
    btrim(p.numero_predial_nacional)::varchar(30) AS npn
  FROM preprod.ilc_predio p
),
uc AS (
  SELECT
    u.objectid,
    u.globalid,
    btrim(u.id_operacion_predio)  AS id_operacion,
    UPPER(btrim(u.identificador)) AS identificador
  FROM preprod.cr_unidadconstruccion u
),
uc_norm AS (
  SELECT
    pr.id_operacion,
    pr.npn,
    pr.objectid   AS predio_objectid,
    pr.globalid   AS predio_globalid,
    u.objectid    AS uc_objectid,
    u.globalid    AS uc_globalid,
    u.identificador,
    (u.identificador IS NOT NULL AND u.identificador ~ '^[A-Z]+$') AS id_valido,
    LENGTH(u.identificador) AS len_id
  FROM predio pr
  LEFT JOIN uc u ON u.id_operacion = pr.id_operacion
),
uc_ord AS (
  SELECT
    u.*,
    CASE
      WHEN NOT id_valido THEN NULL
      ELSE (
        SELECT SUM(
                 ((ascii(substring(u.identificador, pos, 1)) - 64)::bigint)
                 * (power(26::numeric, (u.len_id - pos))::bigint)
               )
        FROM generate_series(1, u.len_id) AS pos
      )
    END AS id_orden
  FROM uc_norm u
),
agg AS (
  SELECT
    id_operacion,
    MIN(predio_objectid) AS objectid,
    MIN(predio_globalid) AS globalid,
    MIN(npn)             AS npn,
    COUNT(uc_objectid)                           AS n_uc_total,
    COUNT(*) FILTER (WHERE NOT id_valido)        AS n_invalidos,
    string_agg(identificador, ', ' ORDER BY uc_objectid) 
       FILTER (WHERE NOT id_valido)              AS muestra_invalidos
  FROM uc_ord
  GROUP BY id_operacion
),
presentes AS (
  SELECT
    t.id_operacion,
    ARRAY_AGG(DISTINCT t.id_orden ORDER BY t.id_orden) AS ord_presentes,
    BOOL_OR(t.cnt > 1) AS hay_duplicados
  FROM (
    SELECT id_operacion, id_orden, COUNT(*) AS cnt
    FROM uc_ord
    WHERE id_valido AND id_orden IS NOT NULL
    GROUP BY id_operacion, id_orden
  ) t
  GROUP BY t.id_operacion
),
eval AS (
  SELECT
    a.*,
    p.ord_presentes,
    p.hay_duplicados
  FROM agg a
  LEFT JOIN presentes p USING (id_operacion)
),
esperado AS (
  SELECT
    e.*,
    CASE
      WHEN e.n_uc_total > 0 THEN ARRAY(SELECT gs FROM generate_series(1, e.n_uc_total) AS gs)
      ELSE ARRAY[]::bigint[]
    END AS ord_esperados
  FROM eval e
),
faltantes AS (
  SELECT
    s.*,
    ARRAY(
      SELECT oe FROM unnest(s.ord_esperados) oe
      EXCEPT
      SELECT op FROM unnest(COALESCE(s.ord_presentes, ARRAY[]::bigint[])) op
      ORDER BY 1
    ) AS ord_faltantes
  FROM esperado s
),
-- convertir ordinal a letras
faltantes_txt AS (
  SELECT
    x.id_operacion,
    CASE WHEN COUNT(*) = 0 THEN NULL
         ELSE string_agg(x.letra, ',' ORDER BY x.ord) END AS letras_faltantes
  FROM (
    SELECT
      f.id_operacion,
      ord::int AS ord,
      (
        WITH RECURSIVE r(n,s) AS (
          SELECT ord::int, ''::text
          UNION ALL
          SELECT (n-1)/26, chr((65 + ((n-1)%26))::int) || s FROM r WHERE n > 0
        )
        SELECT s FROM r ORDER BY n LIMIT 1
      ) AS letra
    FROM faltantes f
    LEFT JOIN LATERAL unnest(COALESCE(f.ord_faltantes, ARRAY[]::bigint[])) AS ord ON TRUE
  ) x
  GROUP BY x.id_operacion
),
final AS (
  SELECT
    f.objectid, f.globalid, f.id_operacion, f.npn,
    f.n_uc_total, f.n_invalidos, f.hay_duplicados,
    COALESCE(ft.letras_faltantes,'') AS letras_faltantes,
    f.muestra_invalidos
  FROM faltantes f
  LEFT JOIN faltantes_txt ft USING (id_operacion)
)
SELECT
  '768'::text                 AS regla,
  'ILC_Predio'::text          AS objeto,
  'preprod.ilc_predio'::text  AS tabla,
  final.objectid,
  final.globalid,
  final.id_operacion,
  final.npn,
  (
    'INCUMPLE: Predio '||final.npn||
    ' tiene '||final.n_uc_total||' UC. '
  ) AS descripcion,
  (
    'n_uc='||final.n_uc_total||
    ', invalidos='||final.n_invalidos||
    CASE WHEN final.muestra_invalidos IS NOT NULL 
         THEN ' ('||final.muestra_invalidos||')' ELSE '' END||
    ', duplicados='||(CASE WHEN final.hay_duplicados THEN 'SI' ELSE 'NO' END)||
    ', faltantes=['||COALESCE(final.letras_faltantes,'')||']'
  )::text AS valor,
  FALSE                        AS cumple,
  NOW()                        AS created_at,
  NOW()                        AS updated_at
FROM final
WHERE
  final.n_uc_total = 0
  OR final.n_invalidos > 0
  OR COALESCE(final.letras_faltantes,'') <> ''
ORDER BY final.id_operacion, final.objectid;
