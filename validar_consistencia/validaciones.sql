
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



--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////