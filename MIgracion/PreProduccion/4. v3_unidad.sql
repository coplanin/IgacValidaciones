
/****************************
* UNIDADES 
*/

/****************************
 * Cantidad unidades rurales 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_r_unidad;
    
--3323

/****************************
 * Cantidad Unidades rurales  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_r_unidad
	where length(codigo)<30;
	
--0
	
	
/****************************
 * Cantidad Unidades rurales informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_r_unidad
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');
	
--13
	
/****************************
 * Cantidad Unidades urbanas 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_u_unidad;
    
--10066

/****************************
 * Cantidad Unidades urbanas  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_u_unidad
	where length(codigo)<30;
	
--0
		
/****************************
 * Cantidad Unidades rurales informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_d_u_unidad
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');

--54
	
/****************************
 * Cantidad Unidades 
 */
	select count(*)
	from (
	    SELECT *
	  	FROM colsmart_prod_insumos.z_d_r_unidad
	    union all
	    SELECT *
	  	FROM colsmart_prod_insumos.z_d_u_unidad
	) t;

--263079




/****************************
 * Crear tabla unica de unidad
 */

	drop table colsmart_prod_insumos.z_b_unidad_terreno;

	
	create table colsmart_prod_insumos.z_b_unidad_terreno as
	with unidad as (
		select *,st_area(shape) area_,objectid t_id
		from colsmart_prod_insumos.z_d_r_unidad
		union all
		select *,st_area(shape) area_,objectid+1000000 t_id
		from colsmart_prod_insumos.z_d_u_unidad
	), unidad_uni as(
		select  codigo npn,identificador,planta,st_area(shape) area_,max(t_id) t_id
		from unidad
		group by codigo,identificador ,planta,st_area(shape)
	)
	SELECT u.objectid, u.codigo, u.terreno_codigo, u.construccion_codigo, 
	CASE 
		  WHEN REGEXP_REPLACE(u.planta, '[^\d]+', '', 'g') = '' THEN 1::text
		  WHEN REGEXP_REPLACE(u.planta, '[^\d]+', '', 'g') IS NULL THEN 1::text
		  ELSE REGEXP_REPLACE(u.planta, '[^\d]+', '', 'g')::text
	end as planta,
	u.tipo_construccion, u.tipo_dominio, u.etiqueta, u.identificador, u.usuario_log, 
	u.fecha_log, u.globalid, u.globalid_snc, u.codigo_municipio, u.shape, u.area_, u.t_id
	from unidad u
	inner join unidad_uni  t 
	on codigo=t.npn 
	and t.identificador=u.identificador
	and t.area_=u.area_
	and t.planta=u.planta
	and t.t_id=u.t_id;
	
	select count(*)
	from  colsmart_prod_insumos.z_b_unidad_terreno;

--270851/262320

/****************************
 * Caso 1: codigo + área más cercana (±5%)+piso+identificador
 */	    
 

	drop table colsmart_prod_insumos.z_u_r_unidad_caso1;

	create table colsmart_prod_insumos.z_u_r_unidad_caso1 as
	select *
	from (
	select u.*,'Caso 1'::text observaciones,g.area_,g.shape
	,g.objectid,'u'::text tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_data u
	inner join colsmart_prod_insumos.z_b_unidad_terreno g
	on u.numero_predial=g.codigo 
	and u.identificador=g.identificador
	and REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int = REGEXP_REPLACE(planta, '[^\d]+', '', 'g')::int
	and ((u.area_construccion>(g.area_*0.95) and u.area_construccion<(g.area_*1.05)) or
	(u.area_construccion>(g.area_-1) and u.area_construccion<(g.area_+1)))) t;

	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso1;

--20506
	
/****************************
 *  Caso 2 completo: predio + área ±5% +piso, excluyendo Caso 1,
 */
-- deduplicando individualmente por objectid y por id_caracteristicasunidadconstru

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso2;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso2 as
		WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      -- Excluir objectid de Caso 1
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas1
	        WHERE cas1.objectid = c.objectid
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
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas1
	        WHERE cas1.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 2'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		and REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int = REGEXP_REPLACE(planta, '[^\d]+', '', 'g')::int
		and ((u.area_construccion>(g.area_*0.95) and u.area_construccion<(g.area_*1.05)) or
		(u.area_construccion>(g.area_-1) and u.area_construccion<(g.area_+1)))) t  
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos	
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso2;

--870
	
	
/****************************
 *  Caso 3
 */
-- deduplicando individualmente por objectid y por id_caracteristicasunidadconstru

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso3;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso3  as
		WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 3'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		and u.identificador=g.identificador
		and ((u.area_construccion>(g.area_*0.95) and u.area_construccion<(g.area_*1.05)) or
		(u.area_construccion>(g.area_-1) and u.area_construccion<(g.area_+1)))) t  
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso3;
	
-- 47707
	
/************************************
 *  Caso 4
 */

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso4;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso4  as
		WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 4'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		and ((u.area_construccion>(g.area_*0.95) and u.area_construccion<(g.area_*1.05)) or
		(u.area_construccion>(g.area_-1) and u.area_construccion<(g.area_+1)))) t  
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso4;
	
--4741	

		
/************************************
 *  Caso 5
 */

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso5;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso5  as
	WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 5'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		and u.identificador=g.identificador
		and REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int = REGEXP_REPLACE(planta, '[^\d]+', '', 'g')::int
		)t
		
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso5;
	
--8278	

	
	
		
/************************************
 *  Caso 6
 */

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso6;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso6  as
	WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.objectid = c.objectid
	      )
	       and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 6'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		and u.identificador=g.identificador
		)t
		
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso6;
	
--38730
	
		
/************************************
 *  Caso 7
 */

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso7;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso7  as
	WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.objectid = c.objectid
	      )
	       and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso6 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso6 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 7'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		and REGEXP_REPLACE(u.planta_ubicacion, '[^\d]+', '', 'g')::int = REGEXP_REPLACE(planta, '[^\d]+', '', 'g')::int)t
		
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso7;
	
--153
		
/************************************
 *  Caso 8
 */

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso8;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso8  as
	WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.objectid = c.objectid
	      )
	       and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso6 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso7 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso6 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso7 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 8'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on u.numero_predial=g.codigo 
		)t
		
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso8;
	
--5306
	
	
/************************************
 *  Caso 8 Union posicion 22
 */

	DROP TABLE IF EXISTS colsmart_prod_insumos.z_u_r_unidad_caso99;
	
	CREATE TABLE colsmart_prod_insumos.z_u_r_unidad_caso99  as
	WITH
	  unmatched_construccion AS (
	    SELECT
	      c.*
	    FROM colsmart_prod_insumos.z_b_unidad_terreno c
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.objectid = c.objectid
	      )
	       and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso6 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso7 cas
	        WHERE cas.objectid = c.objectid
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso8 cas
	        WHERE cas.objectid = c.objectid
	      )
	  ),
	  unmatched_unidad AS (
	    SELECT
	      u.*
	    FROM colsmart_prod_insumos.z_u_r_unidad_data u
	    WHERE
	      NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso1 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso2 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso3 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso4 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso5 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso6 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	      and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso7 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	       and NOT EXISTS (
	        SELECT 1
	        FROM colsmart_prod_insumos.z_u_r_unidad_caso8 cas
	        WHERE cas.id_caracteristicasunidadconstru = u.id_caracteristicasunidadconstru
	      )
	  ),candidatos AS (
		select *
		from (
		select u.*,'Caso 9'::text observaciones,g.area_,g.shape
		,g.objectid,'u'::text tipogeo
		, ABS(u.area_construccion - g.area_) AS diff_area
		from unmatched_unidad u
		inner join unmatched_construccion g
		on left(u.numero_predial,22)=left(g.codigo,22) 
		)t		
	 ),dedup_obj AS (
	  -- Para cada objectid, quedarnos solo con la fila de menor diff_area
	  SELECT
	    *,
	    ROW_NUMBER() OVER (
	      PARTITION BY objectid
	      ORDER BY diff_area
	    ) AS rn_obj
	  FROM candidatos
	),dedup_id AS (
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
	select *
	FROM dedup_id
	WHERE rn_id = 1
	ORDER BY objectid;
	
--------Revisar union hasta la posicion 22
/*
 * Union de todos los casos
 * 
 */
	drop table colsmart_prod_insumos.z_u_r_unidad_union;
	
	create table colsmart_prod_insumos.z_u_r_unidad_union as
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso1
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso2
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso3
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso4
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso5
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso6
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso7
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso8
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso99;



	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_union;

--163069


/***********************************************************
 * Cantidad Unidades alfanumericas no migradas
 */
	
	with sin_migrar as (
		select id_caracteristicasunidadconstru
		from colsmart_prod_insumos.z_u_r_unidad_data
		except
		select id_caracteristicasunidadconstru
		from z_u_r_unidad_union
	)select count(*)
	from sin_migrar;

--228.559

/***********************************************************
 * Migrar Construcciones
 */	
	
	drop table colsmart_prod_insumos.z_u_r_unidad_caso9;
	
	create table colsmart_prod_insumos.z_u_r_unidad_caso9 as	
	with sin_migrar as (
		select id_caracteristicasunidadconstru
		from colsmart_prod_insumos.z_u_r_unidad_data
		where length(numero_predial)>0
		and left(numero_predial,5) in (
			select left(codigo_terreno,5)
			from colsmart_prod_insumos.z_b_construccion_terreno
			where length(codigo_terreno)>0
			group by left(codigo_terreno,5)
		)
		except
		select id_caracteristicasunidadconstru
		from z_u_r_unidad_union
	)
	select u.*,c.shape_construccion as shape,st_area(c.shape_construccion) area_ ,
	'Caso 9'::text observaciones
	,c.objectid::int as objectid,'c'::text tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_data u
	inner join  colsmart_prod_insumos.z_b_construccion_final c
	on c.id_caracteristicasunidadconstru=u.id_caracteristicasunidadconstru
	where 
	exists (
		select 1
		from sin_migrar s
		where s.id_caracteristicasunidadconstru=u.id_caracteristicasunidadconstru
	);
	
	select *
	from colsmart_prod_insumos.z_u_r_unidad_caso9
	where id_caracteristicasunidadconstru in ('19178323','19197303');

--96422

	
/********************
 * Union de  construcciones
 * 
 */
	drop table colsmart_prod_insumos.z_u_r_unidad_union2;
	
	create table colsmart_prod_insumos.z_u_r_unidad_union2 as
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_union
	union all
	select numero_predial,altura,anio_construccion,area_construccion,area_privada_construida,etiqueta,
	id_caracteristicasunidadconstru,id_operacion_predio,planta_ubicacion,predio_guid,tipo_planta,
	identificador,area_,shape,observaciones,objectid, tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_caso9;
	
	select *
	from colsmart_prod_insumos.z_u_r_unidad_union2
	where id_caracteristicasunidadconstru in ('19178323','19197303');


/***********************************************************
 * Migrar Unidades alfanumericas faltantes
 */	
	
	drop table colsmart_prod_insumos.z_u_r_unidad_caso10;
	
	create table colsmart_prod_insumos.z_u_r_unidad_caso10 as
	with sin_migrar as (
		select id_caracteristicasunidadconstru
		from colsmart_prod_insumos.z_u_r_unidad_data
		where length(numero_predial)>0
		and left(numero_predial,5) in (
			select left(codigo_terreno,5)
			from colsmart_prod_insumos.z_b_construccion_terreno
			where length(codigo_terreno)>0
			group by left(codigo_terreno,5)
		)
		except
		select id_caracteristicasunidadconstru
		from z_u_r_unidad_union2
	)
	select u.*,null as shape,
	'Caso 10'::text observaciones
	,0::int as objectid,''::text tipogeo
	from colsmart_prod_insumos.z_u_r_unidad_data u
	where exists (
		select 1
		from sin_migrar s
		where s.id_caracteristicasunidadconstru=u.id_caracteristicasunidadconstru
	);
	
--105076
/***********************************************************
 * Cantidad Unidades geograficas no migradas
 */
	

	select count(*)
	from (
		select objectid
		from colsmart_prod_insumos.z_b_unidad_terreno
		where length(codigo)>0
		and left(codigo,5) in (
			select left(codigo_terreno,5)
			from colsmart_prod_insumos.z_b_construccion_terreno
			where length(codigo_terreno)>0
			group by left(codigo_terreno,5)
		)
		except
		select objectid
		from colsmart_prod_insumos.z_u_r_unidad_union2
		where tipogeo='u'
	) t;
--120446


/***********************************************************
 * Migrar Unidades geografica faltante
 */
	
	drop table colsmart_prod_insumos.z_u_r_unidad_caso11;

	create table colsmart_prod_insumos.z_u_r_unidad_caso11 as
	with sin_migrar as (
		select objectid
		from colsmart_prod_insumos.z_b_unidad_terreno
		where length(codigo)>0
		and left(codigo,5) in (
			select left(codigo_terreno,5)
			from colsmart_prod_insumos.z_b_construccion_terreno
			where length(codigo_terreno)>0
			group by left(codigo_terreno,5)
		)
		except
		select objectid
		from z_u_r_unidad_union2
		where tipogeo='u'
	)
	select u.codigo as numero_predial, '2'::int altura,null::numeric(30,3)  anio_construccion,null::numeric(30,3) as area_construccion,
	null::numeric(30,3) as area_privada_construida, null::numeric(30,3)  as id_caracteristicasunidadconstru ,
	null::numeric(30,3)  as id_operacion_predio,
	planta as planta_ubicacion,''::text predio_guid,
	identificador,etiqueta,
	'Caso 11'::text observaciones,
	shape,u.objectid as objectid,'u'::text tipogeo
	from colsmart_prod_insumos.z_b_unidad_terreno u
	where exists (
		select 1
		from sin_migrar s
		where s.objectid=u.objectid
	);

--86113
	
/****************************
 *  Construciones nuevas no cruzan con lo alfanumerico
 */
	drop table colsmart_prod_insumos.z_u_r_unidad_caso12;

	create table colsmart_prod_insumos.z_u_r_unidad_caso12 as
	select 
	CASE
		WHEN length(u.codigo) <30 THEN u.codigo_terreno
		else u.codigo
	END  as numero_predial, 
	'2'::int altura,null::numeric(30,3)  anio_construccion,
	area_::numeric(30,3) as area_construccion,
	null::numeric(30,3) as area_privada_construida, 
	null::numeric(30,3)  as id_caracteristicasunidadconstru ,
	null::numeric(30,3)  as id_operacion_predio,
	piso as planta_ubicacion,
	''::text predio_guid,
	CASE
		WHEN length(identificador) =0 THEN 'A'
		else identificador
	END  as identificador
	,''::text etiqueta,
	'Caso 12'::text observaciones,
	shape,u.objectid as objectid,'c'::text tipogeo
	from colsmart_prod_insumos.z_b_construccion_terreno u	
	where objectid in (
		select objectid
		from colsmart_prod_insumos.z_b_construccion_terreno 
		except
		select objectid
		from colsmart_prod_insumos.z_b_construccion_final
	) ;	
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_caso12;

--177.750
/***********************************************************
 * Permisos para insertar en preproduccion migra
 */	
	
	GRANT INSERT, SELECT, REFERENCES, TRUNCATE, UPDATE, DELETE, TRIGGER ON TABLE 
	colsmart_prod_insumos.z_b_terreno TO colsmart_preprod_migra;
	
	GRANT INSERT, SELECT, REFERENCES, TRUNCATE, UPDATE, DELETE, TRIGGER ON TABLE 
		colsmart_prod_insumos.z_u_r_unidad_union2 TO colsmart_preprod_migra;
	
	
	GRANT INSERT, SELECT, REFERENCES, TRUNCATE, UPDATE, DELETE, TRIGGER ON TABLE 
		colsmart_prod_insumos.z_u_r_unidad_caso10 TO colsmart_preprod_migra;
	
	GRANT INSERT, SELECT, REFERENCES, TRUNCATE, UPDATE, DELETE, TRIGGER ON TABLE 
		colsmart_prod_insumos.z_u_r_unidad_caso11 TO colsmart_preprod_migra;
	
/**
 * Cambiar el usuario a colsmart_preprod_migra
 */

/***********************************************************
 * Borra Unidad de construccion de los 4 municipios
 */
	
	create table colsmart_prod_insumos.z_d_cr_unidadconstruccion as
	select *
	from colsmart_preprod_migra.cr_unidadconstruccion;
	
	delete
	from colsmart_preprod_migra.cr_unidadconstruccion
	where length(codigo)>0
	and left(codigo,5) in (
		select left(codigo,5)
		from colsmart_prod_insumos.z_d_terreno
		where length(codigo)>1
		group by left(codigo,5)
	);
	
/***********************************************************
 * Migrar Unidades que cruzaron a Unidad de construccion
 */
	--delete from colsmart_preprod_migra.cr_unidadconstruccion;
	
	GRANT INSERT, SELECT, REFERENCES, TRUNCATE, UPDATE, DELETE, TRIGGER ON TABLE colsmart_prod_insumos.z_b_a_construccion_terreno TO colsmart_preprod_migra;

		
	INSERT INTO colsmart_preprod_migra.cr_unidadconstruccion
	(objectid, globalid, altura, anio_construccion, area_construccion, 
	area_privada_construida, etiqueta, id_caracteristicasunidadconstru, 
	id_operacion_predio, planta_ubicacion, tipo_planta, predio_guid, 
	caracteristicasuc_guid, repetir,codigo,identificador,observaciones, shape)
	select sde.next_rowid('colsmart_preprod_migra', 'cr_unidadconstruccion') objectid,
		sde.next_globalid() globalid,
		altura,
		anio_construccion,
		area_construccion,
		area_privada_construida,
		etiqueta,
		id_caracteristicasunidadconstru,
		id_operacion_predio,
		coalesce(
		REGEXP_REPLACE(planta_ubicacion, '[^\d]+', '', 'g')
		,'0')::int as planta_ubicacion,
		tipo_planta,
		p.globalid predio_guid,
		c.globalid caracteristicasuc_guid,
		'No'::text repetir,
		numero_predial as codigo,
		identificador,
		u.observaciones,
		u.shape	
	from colsmart_prod_insumos.z_u_r_unidad_union2 u
	left join colsmart_preprod_migra.ilc_predio p
	on u.id_operacion_predio::text=p.id_operacion::text
	left join colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion c
	on c.id_caracteristicas_unidad_cons::text=u.id_caracteristicasunidadconstru::text;
	
---44733
/***********************************************************
* Migrar Unidades alfanunericas a Unidad de construccion
 */
	INSERT INTO colsmart_preprod_migra.cr_unidadconstruccion
	(objectid, globalid, altura, anio_construccion, area_construccion, 
	area_privada_construida, etiqueta, id_caracteristicasunidadconstru, 
	id_operacion_predio, planta_ubicacion, tipo_planta, predio_guid, 
	caracteristicasuc_guid, repetir,codigo,identificador,observaciones)
	select sde.next_rowid('colsmart_preprod_migra', 'cr_unidadconstruccion') objectid,
		sde.next_globalid() globalid,
		altura,
		anio_construccion,
		area_construccion,
		area_privada_construida,
		etiqueta,
		id_caracteristicasunidadconstru,
		id_operacion_predio,
		coalesce(
		REGEXP_REPLACE(planta_ubicacion, '[^\d]+', '', 'g')
		,'0')::int as planta_ubicacion,
		tipo_planta,
		p.globalid predio_guid,
		c.globalid caracteristicasuc_guid,
		'No'::text repetir,
		numero_predial as codigo,
		identificador,
		u.observaciones
		--u.shape	
	from colsmart_prod_insumos.z_u_r_unidad_caso10 u
	left join colsmart_preprod_migra.ilc_predio p
	on u.id_operacion_predio::text=p.id_operacion::text
	left join colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion c
	on c.id_caracteristicas_unidad_cons::text=u.id_caracteristicasunidadconstru::text;

--105076
		
/***********************************************************
* Migrar Unidades geograficas a Unidad de construccion
 */
	INSERT INTO colsmart_preprod_migra.cr_unidadconstruccion
	(objectid, globalid, altura, anio_construccion, area_construccion, 
	area_privada_construida, etiqueta, id_caracteristicasunidadconstru, 
	id_operacion_predio, planta_ubicacion, tipo_planta, predio_guid, 
	caracteristicasuc_guid, repetir,codigo,identificador,observaciones,shape)
	select sde.next_rowid('colsmart_preprod_migra', 'cr_unidadconstruccion') objectid,
		sde.next_globalid() globalid,	
		altura,
		anio_construccion,
		area_construccion,
		area_privada_construida,
		etiqueta,
        id_caracteristicasunidadconstru,
		p.id_operacion as id_operacion_predio,
		CASE 
		  WHEN REGEXP_REPLACE(planta_ubicacion, '[^\d]+', '', 'g') = '' THEN 1::int
		  WHEN REGEXP_REPLACE(planta_ubicacion, '[^\d]+', '', 'g') IS NULL THEN 1::int
		  ELSE REGEXP_REPLACE(planta_ubicacion, '[^\d]+', '', 'g')::int
		end as planta_ubicacion,
		'Piso'::text tipo_planta,
		p.globalid predio_guid,
		c.globalid caracteristicasuc_guid,
		'No'::text repetir,
		numero_predial as codigo,
		identificador,
		u.observaciones,
		u.shape	
	from colsmart_prod_insumos.z_u_r_unidad_caso11 u
	left join colsmart_preprod_migra.ilc_predio p
	on u.numero_predial::text=p.numero_predial_nacional::text
	left join colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion c
	on c.id_caracteristicas_unidad_cons::text=u.id_caracteristicasunidadconstru::text;
	

	
delete 
from colsmart_preprod_migra.cr_unidadconstruccion
where observaciones in ('Caso 11')
--86113

/***********************************************************
* Migrar Unidades geograficas de construccion
 */
	INSERT INTO colsmart_preprod_migra.cr_unidadconstruccion
	(objectid, globalid, altura, anio_construccion, area_construccion, 
	area_privada_construida, etiqueta, id_caracteristicasunidadconstru, 
	id_operacion_predio, planta_ubicacion, tipo_planta, predio_guid, 
	caracteristicasuc_guid, repetir,codigo,identificador,observaciones,shape)	
	select sde.next_rowid('colsmart_preprod_migra', 'cr_unidadconstruccion') objectid,
		sde.next_globalid() globalid,
		altura,
		anio_construccion,
		area_construccion,
		area_privada_construida,
		etiqueta,
		id_caracteristicasunidadconstru,
		p.id_operacion as id_operacion_predio,
		planta_ubicacion,
		'Piso'::text tipo_planta,
		p.globalid predio_guid,
		null caracteristicasuc_guid,
		'No'::text repetir,
		numero_predial as codigo,
		left(identificador,10) as identificador,
		u.observaciones,
		u.shape	
	from colsmart_prod_insumos.z_u_r_unidad_caso12 u
	left join colsmart_preprod_migra.ilc_predio p
	on u.numero_predial::text=p.numero_predial_nacional::text
	where not exists (
		select 1
		from colsmart_preprod_migra.cr_unidadconstruccion a
		where a.codigo=u.numero_predial and st_area(a.shape)=st_area(u.shape)		
	);



	with codigo as (
		select *
		from colsmart_preprod_migra.cr_unidadconstruccion
		where codigo in (
		select codigo--,count(*)
		from colsmart_preprod_migra.cr_unidadconstruccion
		where left(codigo,5) in (
			select left(codigo,5)
			from colsmart_prod_insumos.z_u_r_terreno 
			where left(codigo,5) not in (' ','')
			group by left(codigo,5)
		)
		group by codigo	
		having count(*)=1)
	), globalid_old as (
		select c.*,t.globalid as globalidold
		from codigo c,colsmart_prod_insumos.z_d_cr_unidadconstruccion t
		where c.codigo=t.codigo
	)
	update  colsmart_preprod_migra.cr_unidadconstruccion 
	set globalid=g.globalidold
	from globalid_old g
	where g.codigo=cr_unidadconstruccion.codigo;
	
	update  colsmart_preprod_migra.cr_unidadconstruccion
	set caracteristicasuc_guid=ic.globalid
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion ic
	where ic.id_caracteristicas_unidad_cons=cr_unidadconstruccion.id_caracteristicasunidadconstru;
	
	
	update  colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	set unidadconstruccion_guid=ic.globalid
	from colsmart_preprod_migra.cr_unidadconstruccion ic
	where ilc_caracteristicasunidadconstruccion.id_caracteristicas_unidad_cons=ic.id_caracteristicasunidadconstru;
	
	
	
	
	select *
	from colsmart_preprod_migra.cr_unidadconstruccion
	
	
	--126.195
	--15.758
	
	delete 
	from colsmart_preprod_migra.cr_unidadconstruccion
	where observaciones in ('Caso 12')

---141.953

	
	
	
	select count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion
	where length(codigo)>0
	and left(codigo,5) in (
		select left(codigo_terreno,5)
		from colsmart_prod_insumos.z_b_construccion_terreno
		where length(codigo_terreno)>0
		group by left(codigo_terreno,5)
	);
	
	

	
	
	select left(codigo,5),count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion
	where length(codigo)>0
	and left(codigo,5) in (
		select left(codigo_terreno,5)
		from colsmart_prod_insumos.z_b_construccion_terreno
		where length(codigo_terreno)>0
		group by left(codigo_terreno,5)
	)
	group by left(codigo,5);

	
	with ahora as (
		select left(codigo,5) npm,count(*)
		from colsmart_preprod_migra.cr_unidadconstruccion
		where length(codigo)>0
		and left(codigo,5) in (
			select left(codigo_terreno,5)
			from colsmart_prod_insumos.z_b_construccion_terreno
			where length(codigo_terreno)>0
			group by left(codigo_terreno,5)
		) 
		group by left(codigo,5)
	),antes as (	
			select left(numero_predial,5) npm,count(*)
			from  colsmart_prod_insumos.z_u_r_unidad_data
			where length(numero_predial)>0
			and left(numero_predial,5) in (
				select left(codigo_terreno,5)
				from colsmart_prod_insumos.z_b_construccion_terreno
				where length(codigo_terreno)>0
				group by left(codigo_terreno,5)
			)
			group by left(numero_predial,5)
	)
	select h.npm ,h.count c_ahora,n.count c_antes,h.count-n.count dif,
	((h.count::numeric(20,2)-n.count::numeric(20,2))/n.count::numeric(20,2)*100)::numeric(20,2) porcen
	from ahora h
	left join antes n
	on h.npm=n.npm;
	
	
	
	
	with ahora as (
		select left(codigo,5) npm,substring(codigo FROM 6 FOR 2) zona,count(*)
		from colsmart_preprod_migra.cr_unidadconstruccion
		where length(codigo)>0
		and left(codigo,5) in (
			select left(codigo_terreno,5)
			from colsmart_prod_insumos.z_b_construccion_terreno
			where length(codigo_terreno)>1
			group by left(codigo_terreno,5)
		)
		group by left(codigo,5),substring(codigo FROM 6 FOR 2)
	),antes as (	
			select left(numero_predial,5) npm,substring(numero_predial FROM 6 FOR 2) zona,count(*)
			from  colsmart_prod_insumos.z_u_r_unidad_data
			where length(numero_predial)>1
			and left(numero_predial,5) in (
				select left(codigo_terreno,5)
				from colsmart_prod_insumos.z_b_construccion_terreno
				where length(codigo_terreno)>0
				group by left(codigo_terreno,5)
			)
			group by left(numero_predial,5),substring(numero_predial FROM 6 FOR 2)
	),zona as(
		select h.npm, h.zona::int zona,h.count c_ahora,n.count c_antes,h.count-n.count dif,
		((h.count::numeric(20,2)-n.count::numeric(20,2))/n.count::numeric(20,2)*100)::numeric(20,2) porcen,
		CASE
		  WHEN h.zona::int = 0 THEN 'Rural'
		ELSE
		  'urbana'
		end zona_u_r
		from ahora h
		left join antes n
		on h.npm=n.npm and h.zona=n.zona
	)select npm,zona_u_r,c_ahora,c_antes,c_ahora-c_antes dif,
		((c_ahora::numeric(20,2)-c_antes::numeric(20,2))/c_antes::numeric(20,2)*100)::numeric(20,2) porcen
	from (
	select npm,zona_u_r,sum(c_ahora) c_ahora,sum(c_antes) c_antes
	from zona
	group by npm,zona_u_r
	order by npm,zona_u_r) t;
		where left(codigo,5) in (
		select left(codigo_terreno,5)
		from colsmart_prod_insumos.z_b_construccion_terreno
		where length(codigo_terreno)>0
		group by left(codigo_terreno,5)
	) 
	
with duplicate as (
	select codigo,
	planta_ubicacion,
	identificador,
	st_area(shape) area_,
	min(objectid) objectid,
	count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion
	group by codigo,
	planta_ubicacion,
	identificador,
	st_area(shape)
	having count(*)>1
)
delete
from colsmart_preprod_migra.cr_unidadconstruccion u
where exists (
	select 1
	from duplicate d
	where u.objectid=d.objectid )

select observaciones,count(*)
from colsmart_preprod_migra.cr_unidadconstruccion
group by observaciones;
	
select *
from (
	select codigo
	from (
		select left(codigo,22) codigo
		from colsmart_prod_insumos.z_b_construccion_terreno
		except
		select left(codigo,22) codigo
		from  colsmart_preprod_migra.cr_unidadconstruccion
	) t
	except
	select left(numero_predial,22) codigo 
	from  colsmart_prod_insumos.z_u_r_unidad_data
)t;


select *
from  colsmart_preprod_migra.cr_unidadconstruccion
where codigo in ('138360001000000040012800000002','138360001000000040012800000022')





inner join colsmart_preprod_migra.ilc_predio p
on t.codigo::text=p.numero_predial_nacional::text
inner join colsmart_prod_insumos.z_b_construccion_terreno c
on t.codigo::text=c.codigo::text;	




select *
from (
	select codigo
	from (
		select left(codigo,22) codigo
		from colsmart_prod_insumos.z_b_unidad
		except
		select left(codigo,22) codigo
		from  colsmart_preprod_migra.cr_unidadconstruccion
	) t	
)t
inner join colsmart_preprod_migra.ilc_predio p
on t.codigo::text=left(p.numero_predial_nacional,22)::text;


select *
from (
	select codigo
	from (
		select left(codigo,22) codigo
		from colsmart_prod_insumos.z_b_unidad
		except
		select left(codigo,22) codigo
		from  colsmart_preprod_migra.cr_unidadconstruccion
	) t
	order by codigo
)t
where left(codigo,5)='13836';



select *
from colsmart_prod_insumos.z_b_unidad
where left(codigo,22) in (
'1383600000000000000000',
'1383600010000000109029',
'1383600010000000109039',
'1383600010000000109079'
);


select *
from colsmart_prod_insumos.z_b_terreno 
where left(codigo,22) in (
'1383600000000000000000',
'1383600010000000109029',
'1383600010000000109039',
'1383600010000000109079'
);

select *
from colsmart_preprod_migra.ilc_predio
where left(matricula_inmobiliaria,22) in (
'1383600000000000000000',
'1383600010000000109029',
'1383600010000000109039',
'1383600010000000109079'
)


select *
from colsmart_prod_insumos.z_u_r_unidad_data  
where left(numero_predial,22) in (
'1383600000000000000000',
'1383600010000000109029',
'1383600010000000109039',
'1383600010000000109079'
)



group by left(codigo,5) ;

select left(numero_predial,22)  codigo
from  colsmart_prod_insumos.z_u_r_unidad_data
except
select left(codigo,22)
from  colsmart_preprod_migra.cr_unidadconstruccion;









