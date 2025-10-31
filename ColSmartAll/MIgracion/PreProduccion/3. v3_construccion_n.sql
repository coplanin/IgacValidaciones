 
/****************************
 * Cantidad Construcciones rurales 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_r_construccion;
    
--5075

/****************************
 * Cantidad Construcciones rurales  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_r_construccion
	where length(z_d_r_construccion.codigo)<30;
	
--2255

/****************************
 * Cantidad Construcciones rurales informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_r_construccion
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');
	
--47
	
/****************************
 * Cantidad Construcciones urbanas 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_u_construccion;
    
--5283

/****************************
 * Cantidad Construcciones urbanas  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_u_construccion
	where length(codigo)<30;
	
--1886
	
	
/****************************
 * Cantidad Construcciones urbanas informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_u_construccion
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');

--71
	
/****************************
 * Cantidad construcciones 
 */
	select count(*)
	from (
	    SELECT *
	  	FROM colsmart_prod_insumos.z_d_r_construccion
	    union all
	    SELECT *
	  	FROM colsmart_prod_insumos.z_d_u_construccion
	) t;

--125344



/****************************
 * Crear tabla unica de construccion
 */
		
	DROP TABLE IF EXISTS  colsmart_prod_insumos.z_b_construccion_terreno;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_terreno as	
	WITH cons AS (      -- construcciones (R + U) con posible terreno previo
	    /* ----- construcciones resguardo (Rurales) ----- */
	     SELECT
		    -- si necesitas que cada fila tenga un objectid único,
		    -- añade el nº de piso al final; adapta la fórmula a tu criterio
		    (row_number() OVER (ORDER BY objectid, piso)) AS objectid,
		    codigo                                             AS origen_codigo,
		    identificador,
		    shape,
		    st_area(shape)                                AS area_,
		    st_pointonsurface(shape)                      AS pt,
		    numero_pisos,
		    terreno_codigo,
		    gs.piso
		    -- ← campo con el piso
		FROM (select *,
		 case
			WHEN numero_pisos is null THEN 1   -- hay código → “base”
	        WHEN numero_pisos=0 THEN 1   -- hay código → “base”
	        ELSE numero_pisos                                     -- nulo → “nuevo”
	    END AS n_pisos
		from colsmart_prod_insumos.z_d_r_construccion)  c
		CROSS JOIN LATERAL generate_series(1, c.n_pisos) AS gs(piso) 
		 WHERE st_geometrytype(c.shape)::text IN ('ST_Polygon','ST_MultiPolygon')
		UNION ALL
	    /* ----- construcciones actualizadas (Urbanas) ----- */
	    SELECT
		    -- si necesitas que cada fila tenga un objectid único,
		    -- añade el nº de piso al final; adapta la fórmula a tu criterio
		    (row_number() OVER (ORDER BY objectid, piso))+1000000 AS objectid,
		    codigo                                             AS origen_codigo,
		    identificador,
		    shape,
		    st_area(shape)                                AS area_,
		    st_pointonsurface(shape)                      AS pt,
		    numero_pisos,
		    terreno_codigo,
		    gs.piso                                            -- ← campo con el piso
		FROM (select *,
		 case
			WHEN numero_pisos is null THEN 1   -- hay código → “base”
	        WHEN numero_pisos=0 THEN 1   -- hay código → “base”
	        ELSE numero_pisos                                     -- nulo → “nuevo”
	    END AS n_pisos
		from colsmart_prod_insumos.z_d_u_construccion)  c
		CROSS JOIN LATERAL generate_series(1, c.n_pisos) AS gs(piso) 
		 WHERE st_geometrytype(c.shape)::text IN ('ST_Polygon','ST_MultiPolygon')
	),
	terrenos AS (       -- Geometrías de terrenos (R + U)
	    SELECT codigo AS terreno_codigo, shape AS terreno_shape
	    FROM colsmart_prod_insumos.z_d_r_terreno
	    where  substring(codigo FROM 22 FOR 1)  not in ('2')-- Se retiran las informalidades
	    UNION ALL
	    SELECT codigo, shape
	    FROM colsmart_prod_insumos.z_d_u_terreno
	    where  substring(codigo FROM 22 FOR 1)  not in ('2')-- Se retiran las informalidades
	)
	select
		t.terreno_codigo,
		(row_number() OVER (ORDER BY objectid, piso)) AS objectid,        
	    CASE
	        WHEN length(c.origen_codigo)<30 THEN COALESCE(t.terreno_codigo, c.terreno_codigo)   -- hay código → “base”
	        ELSE c.origen_codigo                                   -- nulo → “nuevo”
	    END AS codigo,
	    c.identificador,
	    c.shape,
	    c.numero_pisos,
	    c.area_,
	    c.piso,
	    COALESCE(t.terreno_codigo, c.terreno_codigo) AS codigo_terreno,   -- prioridad al que intersecta
	    -- …otros campos…
	    CASE
	        WHEN t.terreno_codigo IS NOT NULL THEN 'base'   -- hay código → “base”
	        ELSE 'nuevo'                                    -- nulo → “nuevo”
	    END AS estado
	FROM cons c
	LEFT JOIN terrenos t
	       ON st_intersects(c.pt, t.terreno_shape) and t.terreno_codigo IS  NULL ;
	
	 
	
	
	
131439

--509850/444895

/****************************
 * Caso 1: Codigo unico + área más cercana (±5%)+piso+identificador
 */	    
    
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casouno;

	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casouno AS
	SELECT DISTINCT ON (
	    c.codigo,
	    u.id_caracteristicasunidadconstru
	  )
	  c.objectid,
	  c.codigo,
	  c.identificador                  AS constru_identificador,
	  c.area_                          AS area_construccion_terreno,
	  u.numero_predial,
	  u.identificador                  AS construccion_identificador,
	  u.area_construccion,
	  u.altura,
	  u.anio_construccion,
	  u.area_privada_construida,
	  u.etiqueta,
	  u.id_caracteristicasunidadconstru,
	  u.id_operacion_predio,
	  REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
	  u.predio_guid,
	  u.tipo_planta
	FROM
	  colsmart_prod_insumos.z_b_construccion_terreno AS c
	JOIN
	  colsmart_prod_insumos.z_u_r_unidad_data    AS u
	  ON c.codigo = u.numero_predial
	  and c.piso::int=REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int
	  AND c.identificador = u.identificador
	  AND u.area_construccion
	      BETWEEN c.area_ * 0.95 AND c.area_ * 1.05
	ORDER BY
	  c.codigo,
	  u.id_caracteristicasunidadconstru,
	  ABS(u.area_construccion - c.area_) ASC;
	
	select count(*)
	from colsmart_prod_insumos.z_b_construccion_casouno;

--21144
	
/****************************
 *  Caso 2 completo: predio + área ±5% +piso, excluyendo Caso 1,
 */
-- deduplicando individualmente por objectid y por id_caracteristicasunidadconstru

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casodos;
	
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casodos as
	WITH candidatos AS (
	  SELECT
	    c.objectid,
	    c.codigo,
	    c.area_                           AS area_construccion_terreno,
	    u.numero_predial,
	    u.id_caracteristicasunidadconstru,
	    u.area_construccion,
	    u.altura,
	    u.anio_construccion,
	    u.area_privada_construida,
	    u.etiqueta,
	    u.id_operacion_predio,
	    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
	    u.predio_guid,
	    u.tipo_planta,
	    ABS(u.area_construccion - c.area_) AS diff_area
	  FROM colsmart_prod_insumos.z_b_construccion_terreno AS c
	  JOIN colsmart_prod_insumos.z_u_r_unidad_data    AS u
	    ON c.codigo = u.numero_predial
	   and c.piso::int=REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int
	   AND u.area_construccion
	       BETWEEN c.area_ * 0.95 AND c.area_ * 1.05
	  WHERE
	    -- excluir cualquier objectid ya en Caso 1
	    NOT EXISTS (
	      SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno cas1
	       WHERE cas1.objectid = c.objectid
	    )
	    -- excluir cualquier construccion ya en Caso 1
	    AND NOT EXISTS (
	      SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno cas1
	       WHERE cas1.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	    )
	),
	dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	),
	dedup_id AS (
	  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY id_caracteristicasunidadconstru
	      ORDER BY diff_area
	    ) AS rn_id
	  FROM dedup_obj
	  WHERE rn_obj = 1
	)
	SELECT
	  objectid,
	  codigo,
	  area_construccion_terreno,
	  numero_predial,
	  id_caracteristicasunidadconstru,
	  area_construccion,
	  altura,
	  anio_construccion,
	  area_privada_construida,
	  etiqueta,
	  id_operacion_predio,
	  planta_ubicacion,
	  predio_guid,
	  tipo_planta
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_b_construccion_casodos;

-- 1908
	
/****************************
 *  Caso 3 completo: predio + área ±5%+identificador , excluyendo Caso 1 y 2,
 */
	
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casotres;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casotres AS
	WITH
	  unmatched_construccion AS (
	    select 	  t.*
	    FROM colsmart_prod_insumos.z_b_construccion_terreno t
	    WHERE
	      -- Excluir objectid de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos c
	        WHERE c.objectid = t.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      -- Excluir construccion de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno cas1
	        WHERE cas1.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      -- Excluir construccion de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos cas2
	        WHERE cas2.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		  SELECT
		    c.objectid,
		    c.codigo,
		    c.area_                           AS area_construccion_terreno,
		    u.numero_predial,
		    u.id_caracteristicasunidadconstru,
		    u.area_construccion,
		    u.altura,
		    u.anio_construccion,
		    u.area_privada_construida,
		    u.etiqueta,
		    u.id_operacion_predio,
		    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
		    u.predio_guid,
		    u.tipo_planta,
		    ABS(u.area_construccion - c.area_) AS diff_area
		  FROM unmatched_construccion AS c
		  JOIN unmatched_unidad    AS u
		    ON c.codigo = u.numero_predial
		    AND c.identificador = u.identificador
		   AND u.area_construccion
		       BETWEEN c.area_ * 0.95 AND c.area_ * 1.05
		),
		dedup_obj AS (
		  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY objectid
		      ORDER BY diff_area
		    ) AS rn_obj
		  FROM candidatos
		),
		dedup_id AS (
		  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY id_caracteristicasunidadconstru
		      ORDER BY diff_area
		    ) AS rn_id
		  FROM dedup_obj
		  WHERE rn_obj = 1
		)
		SELECT
		  objectid,
		  codigo,
		  area_construccion_terreno,
		  numero_predial,
		  id_caracteristicasunidadconstru,
		  area_construccion,
		  altura,
		  anio_construccion,
		  area_privada_construida,
		  etiqueta,
		  id_operacion_predio,
		  planta_ubicacion,
		  predio_guid,
		  tipo_planta
		FROM dedup_id
		WHERE rn_id = 1
		ORDER BY objectid;
	
		select count(*) 
		from colsmart_prod_insumos.z_b_construccion_casotres;
		

--85510

/****************************
 *  Caso 4 completo: 
 */
	
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casocuatro;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casocuatro AS
	WITH
	  unmatched_construccion AS (
	    select t.*
	    FROM colsmart_prod_insumos.z_b_construccion_terreno t
	    WHERE
	      -- Excluir objectid de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casotres  c
	        WHERE c.objectid = t.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      -- Excluir construccion de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      -- Excluir construccion de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	       -- Excluir construccion de Caso 3
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casotres c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		  SELECT
		    c.objectid,
		    c.codigo,
		    c.area_                           AS area_construccion_terreno,
		    u.numero_predial,
		    u.id_caracteristicasunidadconstru,
		    u.area_construccion,
		    u.altura,
		    u.anio_construccion,
		    u.area_privada_construida,
		    u.etiqueta,
		    u.id_operacion_predio,
		    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
		    u.predio_guid,
		    u.tipo_planta,
		    ABS(u.area_construccion - c.area_) AS diff_area
		  FROM unmatched_construccion AS c
		  JOIN unmatched_unidad    AS u
		    ON c.codigo = u.numero_predial
		       AND u.area_construccion
		       BETWEEN c.area_ * 0.9 AND c.area_ * 1.1
		),
		dedup_obj AS (
		  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY objectid
		      ORDER BY diff_area
		    ) AS rn_obj
		  FROM candidatos
		),
		dedup_id AS (
		  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY id_caracteristicasunidadconstru
		      ORDER BY diff_area
		    ) AS rn_id
		  FROM dedup_obj
		  WHERE rn_obj = 1
		)
		SELECT
		  objectid,
		  codigo,
		  area_construccion_terreno,
		  numero_predial,
		  id_caracteristicasunidadconstru,
		  area_construccion,
		  altura,
		  anio_construccion,
		  area_privada_construida,
		  etiqueta,
		  id_operacion_predio,
		  planta_ubicacion,
		  predio_guid,
		  tipo_planta
		FROM dedup_id
		WHERE rn_id = 1
		ORDER BY objectid;
	
		select count(*) 
		from colsmart_prod_insumos.z_b_construccion_casocuatro;
		

---28624
/****************************
 *  Caso 5 completo: predio + piso+identificador , excluyendo Caso 1, 2,3,4,
 */
	
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casocinco;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casocinco AS
	WITH
	  unmatched_construccion AS (
	    select t.*
	    FROM colsmart_prod_insumos.z_b_construccion_terreno t
	    WHERE
	      -- Excluir objectid de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casotres c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
	        WHERE c.objectid = t.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      -- Excluir construccion de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno cas1
	        WHERE cas1.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      -- Excluir construccion de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos cas2
	        WHERE cas2.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	       -- Excluir construccion de Caso 3
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casotres c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		  SELECT
		    c.objectid,
		    c.codigo,
		    c.area_                           AS area_construccion_terreno,
		    u.numero_predial,
		    u.id_caracteristicasunidadconstru,
		    u.area_construccion,
		    u.altura,
		    u.anio_construccion,
		    u.area_privada_construida,
		    u.etiqueta,
		    u.id_operacion_predio,
		    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
		    u.predio_guid,
		    u.tipo_planta,
		    ABS(u.area_construccion - c.area_) AS diff_area
		  FROM unmatched_construccion AS c
		  JOIN unmatched_unidad    AS u
		    ON c.codigo = u.numero_predial
		    AND c.identificador = u.identificador
		    and c.piso::int=REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int	   
		),
		dedup_obj AS (
		  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY objectid
		      ORDER BY diff_area
		    ) AS rn_obj
		  FROM candidatos
		),
		dedup_id AS (
		  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY id_caracteristicasunidadconstru
		      ORDER BY diff_area
		    ) AS rn_id
		  FROM dedup_obj
		  WHERE rn_obj = 1
		)
		SELECT
		  objectid,
		  codigo,
		  area_construccion_terreno,
		  numero_predial,
		  id_caracteristicasunidadconstru,
		  area_construccion,
		  altura,
		  anio_construccion,
		  area_privada_construida,
		  etiqueta,
		  id_operacion_predio,
		  planta_ubicacion,
		  predio_guid,
		  tipo_planta
		FROM dedup_id
		WHERE rn_id = 1
		ORDER BY objectid;

---7768
	
	
	
/****************************
 *  Caso 6 completo: predio + identiuficador , excluyendo Caso 1, 2,3,4,6
 */
	
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casoseis;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casoseis AS
	WITH
	  unmatched_construccion AS (
	    select t.*
	    FROM colsmart_prod_insumos.z_b_construccion_terreno t
	    WHERE
	      -- Excluir objectid de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 3
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casotres c
	        WHERE c.objectid = t.objectid
	      )
	      -- Excluir objectid de Caso 4
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
	        WHERE c.objectid = t.objectid
	      )
	       -- Excluir objectid de Caso 5
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casocinco c
	        WHERE c.objectid = t.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      -- Excluir construccion de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casouno c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      -- Excluir construccion de Caso 2
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casodos c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	       -- Excluir construccion de Caso 3
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casotres c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      AND NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_b_construccion_casocinco c
	        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		  SELECT
		    c.objectid,
		    c.codigo,
		    c.area_                           AS area_construccion_terreno,
		    u.numero_predial,
		    u.id_caracteristicasunidadconstru,
		    u.area_construccion,
		    u.altura,
		    u.anio_construccion,
		    u.area_privada_construida,
		    u.etiqueta,
		    u.id_operacion_predio,
		    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
		    u.predio_guid,
		    u.tipo_planta,
		    ABS(u.area_construccion - c.area_) AS diff_area
		  FROM unmatched_construccion AS c
		  JOIN unmatched_unidad    AS u
		    ON c.codigo = u.numero_predial
		    AND c.identificador = u.identificador
		),
		dedup_obj AS (
		  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY objectid
		      ORDER BY diff_area
		    ) AS rn_obj
		  FROM candidatos
		),
		dedup_id AS (
		  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
		  SELECT
		    *,
		    ROW_NUMBER() OVER (
		      PARTITION BY id_caracteristicasunidadconstru
		      ORDER BY diff_area
		    ) AS rn_id
		  FROM dedup_obj
		  WHERE rn_obj = 1
		)
		SELECT
		  objectid,
		  codigo,
		  area_construccion_terreno,
		  numero_predial,
		  id_caracteristicasunidadconstru,
		  area_construccion,
		  altura,
		  anio_construccion,
		  area_privada_construida,
		  etiqueta,
		  id_operacion_predio,
		  planta_ubicacion,
		  predio_guid,
		  tipo_planta
		FROM dedup_id
		WHERE rn_id = 1
		ORDER BY objectid;
--73923

/****************************
 *  Caso 7 
 */
	
	
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casosiete;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casosiete AS
WITH
  unmatched_construccion AS (
    select t.*
    FROM colsmart_prod_insumos.z_b_construccion_terreno t
    WHERE
      -- Excluir objectid de Caso 1
      NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casouno c
        WHERE c.objectid = t.objectid
      )
      -- Excluir objectid de Caso 2
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casodos c
        WHERE c.objectid = t.objectid
      )
      -- Excluir objectid de Caso 3
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casotres c
        WHERE c.objectid = t.objectid
      )
      -- Excluir objectid de Caso 4
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
        WHERE c.objectid = t.objectid
      )
       -- Excluir objectid de Caso 5
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocinco c
        WHERE c.objectid = t.objectid
      )
        -- Excluir objectid de Caso 6
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casoseis c
        WHERE c.objectid = t.objectid
      )
  ),
  unmatched_unidad AS (
    SELECT
      u.*
    FROM colsmart_prod_insumos.z_u_r_unidad_data u
    WHERE
      -- Excluir construccion de Caso 1
      NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casouno cas1
        WHERE cas1.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      -- Excluir construccion de Caso 2
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casodos cas2
        WHERE cas2.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
       -- Excluir construccion de Caso 3
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casotres c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocinco c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casoseis c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
  ),candidatos AS (
	  SELECT
	    c.objectid,
	    c.codigo,
	    c.area_                           AS area_construccion_terreno,
	    u.numero_predial,
	    u.id_caracteristicasunidadconstru,
	    u.area_construccion,
	    u.altura,
	    u.anio_construccion,
	    u.area_privada_construida,
	    u.etiqueta,
	    u.id_operacion_predio,
	    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
	    u.predio_guid,
	    u.tipo_planta,
	    ABS(u.area_construccion - c.area_) AS diff_area
	  FROM unmatched_construccion AS c
	  JOIN unmatched_unidad    AS u
	    ON c.codigo = u.numero_predial
	    and c.piso::int=REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int	  
	),
	dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	),
	dedup_id AS (
	  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY id_caracteristicasunidadconstru
	      ORDER BY diff_area
	    ) AS rn_id
	  FROM dedup_obj
	  WHERE rn_obj = 1
	)
	SELECT
	  objectid,
	  codigo,
	  area_construccion_terreno,
	  numero_predial,
	  id_caracteristicasunidadconstru,
	  area_construccion,
	  altura,
	  anio_construccion,
	  area_privada_construida,
	  etiqueta,
	  id_operacion_predio,
	  planta_ubicacion,
	  predio_guid,
	  tipo_planta
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;

--2383
/****************************
 *  Caso 8 completo: predio + rank , excluyendo Caso 1, 2,3,4,5,6,7
 */
	

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_casoocho;
	
		
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_casoocho as
WITH
  unmatched_construccion AS (
    SELECT   t.*
    FROM colsmart_prod_insumos.z_b_construccion_terreno t
    WHERE
      -- Excluir objectid de Caso 1
      NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casouno c
        WHERE c.objectid = t.objectid
      )
      -- Excluir objectid de Caso 2
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casodos c
        WHERE c.objectid = t.objectid
      )
      -- Excluir objectid de Caso 3
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casotres c
        WHERE c.objectid = t.objectid
      )
      -- Excluir objectid de Caso 4
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
        WHERE c.objectid = t.objectid
      )
       -- Excluir objectid de Caso 5
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocinco c
        WHERE c.objectid = t.objectid
      )
        -- Excluir objectid de Caso 6
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casoseis c
        WHERE c.objectid = t.objectid
      )
  ),
  unmatched_unidad AS (
    SELECT
      u.*
    FROM colsmart_prod_insumos.z_u_r_unidad_data u
    WHERE
      -- Excluir construccion de Caso 1
      NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casouno cas1
        WHERE cas1.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      -- Excluir construccion de Caso 2
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casodos cas2
        WHERE cas2.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
       -- Excluir construccion de Caso 3
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casotres c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casocinco c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
      AND NOT EXISTS (
        SELECT 1
        FROM colsmart_prod_insumos.z_b_construccion_casoseis c
        WHERE c.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
      )
  ),candidatos AS (
	  SELECT
	    c.objectid,
	    c.codigo,
	    c.area_                           AS area_construccion_terreno,
	    u.numero_predial,
	    u.id_caracteristicasunidadconstru,
	    u.area_construccion,
	    u.altura,
	    u.anio_construccion,
	    u.area_privada_construida,
	    u.etiqueta,
	    u.id_operacion_predio,
	    REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g') planta_ubicacion,
	    u.predio_guid,
	    u.tipo_planta,
	    ABS(u.area_construccion - c.area_) AS diff_area
	  FROM unmatched_construccion AS c
	  JOIN unmatched_unidad    AS u
	    ON left(c.codigo,22) = left(u.numero_predial,22)
	   	  
	),
	dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	),
	dedup_id AS (
	  -- De esas filas únicas por objectid, quedarnos solo con la de menor diff_area por construccion
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY id_caracteristicasunidadconstru
	      ORDER BY diff_area
	    ) AS rn_id
	  FROM dedup_obj
	  WHERE rn_obj = 1
	)
	SELECT
	  objectid,
	  codigo,
	  area_construccion_terreno,
	  numero_predial,
	  id_caracteristicasunidadconstru,
	  area_construccion,
	  altura,
	  anio_construccion,
	  area_privada_construida,
	  etiqueta,
	  id_operacion_predio,
	  planta_ubicacion,
	  predio_guid,
	  tipo_planta
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
--24321
	

	
/****************************
 *  Unir casos
 */
	
	DROP TABLE IF EXISTS colsmart_prod_insumos.z_b_construccion_final;
	
	CREATE TABLE colsmart_prod_insumos.z_b_construccion_final as
	-- Caso 1
	SELECT
	  c1.objectid,
	  c1.codigo,
	  c0.shape                             AS shape_construccion,
	  c1.constru_identificador             AS identificador,
	  c1.construccion_identificador,
	  c1.id_caracteristicasunidadconstru,
	  c1.area_construccion_terreno,
	  c1.area_construccion,
	  c1.id_operacion_predio,
	  '1'                            AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casouno c1
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c1.objectid = c0.objectid
	UNION ALL
	-- Caso 2
	SELECT
	  c2.objectid,
	  c2.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u2.identificador                     AS construccion_identificador,
	  c2.id_caracteristicasunidadconstru,
	  c2.area_construccion_terreno,
	  c2.area_construccion,
	  u2.id_operacion_predio,
	  '2'                            AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casodos c2
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c2.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u2
	  ON u2.id_caracteristicasunidadconstru = c2.id_caracteristicasunidadconstru
	UNION ALL
	-- Caso 3
	SELECT
	  c3.objectid,
	  c3.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u3.identificador                     AS construccion_identificador,
	  c3.id_caracteristicasunidadconstru,
	  c3.area_construccion_terreno,
	  c3.area_construccion,
	  u3.id_operacion_predio,
	  '3'                           AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casotres c3
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c3.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u3
	  ON u3.id_caracteristicasunidadconstru = c3.id_caracteristicasunidadconstru
	UNION ALL
	-- Caso 4
	SELECT
	  c.objectid,
	  c.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u3.identificador                     AS construccion_identificador,
	  c.id_caracteristicasunidadconstru,
	  c.area_construccion_terreno,
	  c.area_construccion,
	  u3.id_operacion_predio,
	  '4'                           AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casocuatro c
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u3
	  ON u3.id_caracteristicasunidadconstru = c.id_caracteristicasunidadconstru
	  UNION ALL
	-- Caso 5
	SELECT
	  c.objectid,
	  c.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u3.identificador                     AS construccion_identificador,
	  c.id_caracteristicasunidadconstru,
	  c.area_construccion_terreno,
	  c.area_construccion,
	  u3.id_operacion_predio,
	  '5'                           AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casocinco c
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u3
	  ON u3.id_caracteristicasunidadconstru = c.id_caracteristicasunidadconstru
	  UNION ALL
	-- Caso 6
	SELECT
	  c.objectid,
	  c.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u3.identificador                     AS construccion_identificador,
	  c.id_caracteristicasunidadconstru,
	  c.area_construccion_terreno,
	  c.area_construccion,
	  u3.id_operacion_predio,
	  '6'                           AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casoseis c
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u3
	  ON u3.id_caracteristicasunidadconstru = c.id_caracteristicasunidadconstru
	  UNION ALL
	-- Caso 7
	SELECT
	  c.objectid,
	  c.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u3.identificador                     AS construccion_identificador,
	  c.id_caracteristicasunidadconstru,
	  c.area_construccion_terreno,
	  c.area_construccion,
	  u3.id_operacion_predio,
	  '7'                           AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casosiete c
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u3
	  ON u3.id_caracteristicasunidadconstru = c.id_caracteristicasunidadconstru
	   UNION ALL-- Caso 8
	SELECT
	  c.objectid,
	  c.codigo,
	  c0.shape                             AS shape_construccion,
	  NULL                                 AS identificador,
	  u3.identificador                     AS construccion_identificador,
	  c.id_caracteristicasunidadconstru,
	  c.area_construccion_terreno,
	  c.area_construccion,
	  u3.id_operacion_predio,
	  '8'                           AS caso
	FROM colsmart_prod_insumos.z_b_construccion_casoocho c
	JOIN colsmart_prod_insumos.z_b_construccion_terreno c0
	  ON c.objectid = c0.objectid
	JOIN colsmart_prod_insumos.z_u_r_unidad_data u3
	  ON u3.id_caracteristicasunidadconstru = c.id_caracteristicasunidadconstru;
	
	
	select *
	from colsmart_prod_insumos.z_b_construccion_final
	where  id_caracteristicasunidadconstru in ('19178323','19197303');
	
	select *
	from colsmart_prod_insumos.z_u_r_unidad_data
	where id_caracteristicasunidadconstru in ('19178323','19197303');
	
	
	select *
	from  colsmart_prod_insumos.z_b_construccion_terreno
	where codigo='138360001000000040012800000000';
	
	select  left(codigo,5),count(*)
	from colsmart_prod_insumos.z_b_construccion_final
	group by  left(codigo,5)

--244.481
/****************************
 *  Contruciones sin unidad
 */
	select count(*)
	from colsmart_prod_insumos.z_b_construccion_terreno t
	where objectid in (
		select objectid
		from colsmart_prod_insumos.z_b_construccion_terreno 
		except
		select objectid
		from colsmart_prod_insumos.z_b_construccion_final
	);
--201244	

/****************************
 *  Reportes
 */

	select left(codigo,5),count(*)
	from colsmart_prod_insumos.z_b_construccion_terreno
	where length(codigo)>0
	group by left(codigo,5);
	
	select left(codigo,5),count(*)
	from colsmart_prod_insumos.z_b_construccion_final
	group by left(codigo,5);
	
	
	select left(numero_predial ,5),count(*)
	from colsmart_prod_insumos.z_u_r_unidad_data
	where length(numero_predial)>0
	and left(numero_predial,5) in (
	select left(codigo,5)
	from colsmart_prod_insumos.z_b_construccion_terreno
	where length(codigo)>0
	group by left(codigo,5)
	)
	group by left(numero_predial,5);







