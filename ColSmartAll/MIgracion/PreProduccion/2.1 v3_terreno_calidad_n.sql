/****************************
 * Cantidad Terreno rurales 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_terreno;
   -- where  substring(codigo FROM 22 FOR 1)  not in ('2','5')-- Se retiran las informalidades
--224.139

	
/****************************
 * Cantidad Informalidas Terreno rurales 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_terreno
    where  substring(codigo FROM 22 FOR 1)  in ('2','5');-- Se retiran las informalidades

--2
	
/****************************
 * Cantidad Terreno urbanos
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_terreno;
   
---189.191
	
/****************************
 * Cantidad Informalidas Terreno Urbano 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_terreno
    where  substring(codigo FROM 22 FOR 1)  in ('2','5');-- Se retiran las informalidades

--1
	

 /*******************************************************
 * Total Terrenos
 */
	with terreno as (
		select *,st_area(shape) area_
		from colsmart_prod_insumos.z_f_r_terreno
		union all
		select *,st_area(shape) area_
		from colsmart_prod_insumos.z_f_u_terreno
	)
	select count(*)
	from terreno;
---412.425
 
  /*****************************************************
   * crea tabla terreno para casoes
   */
 	drop table colsmart_prod_insumos.z_b_terreno;
 
 	create table colsmart_prod_insumos.z_b_terreno as
	select *,st_area(shape) area_,
	objectid as t_id
	from colsmart_prod_insumos.z_f_r_terreno
	union all
	select *,st_area(shape) area_,
	objectid+1000000 as t_id
	from  colsmart_prod_insumos.z_f_u_terreno;
	
--413.330
 	

	delete
	from colsmart_prod_insumos.z_v_terrenos;
  /*******************************************************
 * Terreno caso longitud codigo, caso 1
 */
	INSERT INTO colsmart_prod_insumos.z_v_terrenos
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
	WITH terreno AS (
		SELECT *
		FROM colsmart_prod_insumos.z_b_terreno
	)
	SELECT 
		nextval('colsmart_prod_insumos.z_v_terrenos_objectid_seq'),
		gen_random_uuid()::varchar,
		codigo, 1, 'Geografica_Terreno_Npm_Longitud_Menor_A_30',
		globalid_snc, shape
	FROM terreno
	WHERE length(codigo) < 30;

---359
	
	SELECT *--count(*) 
	FROM colsmart_prod_insumos.z_v_terrenos;

  
  /*******************************************************
 * Terreno duplicados
 */

	INSERT INTO colsmart_prod_insumos.z_v_terrenos
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
	WITH terreno AS (
		SELECT *
		FROM colsmart_prod_insumos.z_b_terreno
	),
	terreno_miss AS (
		SELECT t_id
		FROM terreno
		EXCEPT
		SELECT t_id
		FROM (
			SELECT codigo, area_, MIN(t_id) AS t_id
			FROM terreno
			GROUP BY codigo, area_
		) sub
	)
	SELECT 
		nextval('colsmart_prod_insumos.z_v_terrenos_objectid_seq'),
		gen_random_uuid()::varchar,
		t.codigo,
		2,
		'Terreno duplicados',
		t.globalid_snc,
		t.shape
	FROM terreno t
	JOIN terreno_miss tm ON t.t_id = tm.t_id;

  
  	select *
  	from colsmart_prod_insumos.z_v_terrenos;
 --3423
  

   
  /*******************************************************
 * Terreno  codigo municipio incorrecto
 */
	INSERT INTO colsmart_prod_insumos.z_v_terrenos
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
	WITH terreno AS (
		SELECT *
		FROM colsmart_prod_insumos.z_b_terreno
	),
	cod AS (
		SELECT LEFT(codigo, 5) AS mpcodigo
		FROM terreno
		WHERE LENGTH(codigo) >= 30
		GROUP BY LEFT(codigo, 5)
		EXCEPT
		SELECT mpcodigo
		FROM colsmart_prod_insumos.igac_municipios_divipola
		WHERE mpcodigo != '00000'
	)
	SELECT 
	  nextval('colsmart_prod_insumos.z_v_terrenos_objectid_seq') AS objectid,
	  gen_random_uuid()::varchar AS globalid,
	  t.codigo,
	  3,
	  'Geografica_Terreno_Npm_Longitud_Menor_A_30',
	  t.globalid_snc,
	  t.shape
	FROM terreno t
	JOIN cod c ON c.mpcodigo = LEFT(t.codigo, 5);

	select *--count(*)
	from  colsmart_preprod_migra.cr_unidadconstruccion cu
	where observaciones='Caso 12';
--	group by ;
   	
--10
  /*******************************************************
 * Geometria de terreno no valida
 */
	INSERT INTO colsmart_prod_insumos.z_v_terrenos
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
	WITH terreno AS (
		SELECT *
		FROM colsmart_prod_insumos.z_b_terreno
	)
	SELECT 
		nextval('colsmart_prod_insumos.z_v_terrenos_objectid_seq') AS objectid,
		gen_random_uuid()::varchar AS globalid,
		codigo,
		4,
		'Tipo de geometria no valido ' || COALESCE(ST_GeometryType(shape)::text, 'No definido') AS detalle,
		globalid_snc,
		shape
	FROM terreno t
	WHERE ST_GeometryType(shape)::text NOT IN ('ST_Polygon', 'ST_MultiPolygon');

 --0
  
/*******************************************************
 * Geometria de terreno no valida
 */
	INSERT INTO colsmart_prod_insumos.z_v_terrenos
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
	WITH terreno AS (
		SELECT *
		FROM colsmart_prod_insumos.z_b_terreno
	)
	SELECT 
		nextval('colsmart_prod_insumos.z_v_terrenos_objectid_seq') AS objectid,
		gen_random_uuid()::varchar AS globalid,
		codigo,
		5,
		'Geografica_Terreno_Geometria_No_Valida',
		globalid_snc,
		shape
	FROM terreno t
	WHERE shape IS NULL;
	
	 
 ---0
   	
 /*******************************************************
 * Terreno predio
 */
		INSERT INTO colsmart_prod_insumos.z_v_terrenos
		(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
		WITH terreno AS (
			SELECT *
			from colsmart_preprod_migra.cr_terreno
			where predio_guid is null or predio_guid  like '%000%'
		)
		SELECT 
			nextval('colsmart_prod_insumos.z_v_terrenos_objectid_seq') AS objectid,
			gen_random_uuid()::varchar AS globalid,
			m.codigo,
			6,
			'Geografica_Terreno_Sin_Predio',
			null globalid_snc,
			m.shape
		FROM terreno m;
 

   --5412
 
  /*******************************************************
 * Resumen de predio
 */
   
   	select caso::int,detalle,count(*)
   	from colsmart_prod_insumos.z_v_terrenos
	group by caso,detalle
   	order by caso,detalle;
   	
  -- 	Npm longitud menor a 30	3
--Terreno duplicados	4045
--Codigo de Municipio no valido	10
--Terreno sin predio	3235
   	
   
   	

   
   	 	
 
 