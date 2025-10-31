/****************************
 * Cantidad Terreno rurales 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_terreno_40;
   -- where  substring(codigo FROM 22 FOR 1)  not in ('2','5')-- Se retiran las informalidades
--13717

	
/****************************
 * Cantidad Informalidas Terreno rurales 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_terreno_40
    where  substring(codigo FROM 22 FOR 1)  in ('2','5');-- Se retiran las informalidades

--8
	
/****************************
 * Cantidad Terreno urbanos
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_terreno_40;
   
---4358
	
/****************************
 * Cantidad Informalidas Terreno Urbano 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_terreno_40
    where  substring(codigo FROM 22 FOR 1)  in ('2','5');-- Se retiran las informalidades

--0
	

 /*******************************************************
 * Total Terrenos
 */
	with terreno as (
		select *,st_area(shape) area_
		from colsmart_snc_linea_base.z_y_r_terreno_40
		union all
		select *,st_area(shape) area_
		from colsmart_snc_linea_base.z_y_u_terreno_40
	)
	select count(*)
	from terreno;
---396872
 
  /*****************************************************
   * crea tabla terreno para casoes
   */
 	drop table 	colsmart_snc_linea_base.z_b_terreno;
 
 	create table colsmart_snc_linea_base.z_b_terreno as
	select *,st_area(shape) area_,
	objectid as t_id
	from colsmart_snc_linea_base.z_y_r_terreno_40
	union all
	select *,st_area(shape) area_,
	objectid+1000000 as t_id
	from colsmart_snc_linea_base.z_y_u_terreno_40;
	

 
	delete
	from colsmart_snc_linea_base.z_v_terrenos;
  /*******************************************************
 * Terreno caso longitud codigo, caso 1
 */
 	INSERT INTO colsmart_snc_linea_base.z_v_terrenos
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with terreno as (
		select *
		from colsmart_snc_linea_base.z_b_terreno
	)
	select 
	next_rowid('colsmart_snc_linea_base', 'z_v_terrenos') objectid,
	next_globalid(),
	codigo,'1'::int caso,'Npm longitud menor a 30'::text detalle, 
	globalid_snc,shape
	from terreno
  	where length(codigo)<30;
  
---6
 
  
  /*******************************************************
 * Terreno duplicados
 */
  
  	INSERT INTO colsmart_snc_linea_base.z_v_terrenos
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with terreno as (
		select *
		from colsmart_snc_linea_base.z_b_terreno
	),terreno_miss as (
		select t_id
		from terreno
		except
		select t_id
		from terreno
		where t_id in (
			select t_id
			from (
				select codigo,area_,min(t_id) t_id
				from terreno
				group by codigo,area_
			) t
		)
	)
	select 
	next_rowid('colsmart_snc_linea_base', 'z_v_terrenos') objectid,
	next_globalid(),
	codigo,'2'::int caso,'Terreno duplicados'::text detalle,
	globalid_snc, shape
	from terreno t,terreno_miss tm
	where t.t_id=tm.t_id;
  
  
  
 --8062	
  

   
  /*******************************************************
 * Terreno caso codigo municipio
 */
    INSERT INTO colsmart_snc_linea_base.z_v_terrenos
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
   	with terreno as (
		select *
		from colsmart_snc_linea_base.z_b_terreno
	),cod as (
		select left(codigo,5) mpcodigo
		from terreno
	  	where length(codigo)>=30
	  	group by left(codigo,5)
	  	except
	  	select mpcodigo
	  	from colsmart_snc_linea_base.igac_municipios_divipola
	   	where mpcodigo !='00000'
   	)
   	select 
	next_rowid('colsmart_snc_linea_base', 'z_v_terrenos') objectid,
	next_globalid(),
	codigo,'3'::int caso,'Codigo de Municipio no valido'::text detalle, 
	globalid_snc, shape
   	from terreno t,cod c
   	where c.mpcodigo=left(t.codigo,5)
   	
--10
  /*******************************************************
 * Geometria de terreno no valida
 */
    INSERT INTO colsmart_snc_linea_base.z_v_terrenos
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
   	with terreno as (
		select *
		from colsmart_snc_linea_base.z_b_terreno
	)	
	select 
	next_rowid('colsmart_snc_linea_base', 'z_v_terrenos') objectid,
	next_globalid(),
	codigo,'4'::int caso,
	'Tipo de geometria no valido '::text|| COALESCE(st_geometrytype(shape)::text,'No definido'::text) detalle, 
	globalid_snc,shape
	from terreno t
    where  st_geometrytype(shape)::text not in ('ST_POLYGON','ST_MULTIPOLYGON');
   	

	SELECT *--COUNT(*)
	from  colsmart_snc_linea_base.z_v_terrenos
	where caso='4';
 --6  	
  
/*******************************************************
 * Geometria de terreno no valida
 */
    INSERT INTO colsmart_snc_linea_base.z_v_terrenos
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
   	with terreno as (
		select *
		from colsmart_snc_linea_base.z_b_terreno
	)	
	select 
	next_rowid('colsmart_snc_linea_base', 'z_v_terrenos') objectid,
	next_globalid(),
	codigo,'5'::int caso,
	'geomtria no valido invalida'::text detalle, globalid_snc,shape
	FROM   terreno t
	WHERE  shape is null;
 
 ---2441

   	
 /*******************************************************
 * Terreno predio
 */
   INSERT INTO colsmart_snc_linea_base.z_v_terrenos
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with terreno as (
		select *
		from colsmart_snc_linea_base.z_b_terreno
	)
   	select 
	next_rowid('colsmart_snc_linea_base', 'z_v_terrenos') objectid,
	next_globalid(),
	codigo,'6' ::int caso,
	'Terreno sin predio'::text detalle,
	globalid_snc,m.shape
   	from terreno m
 	left join  colsmart_test5_owner.ilc_predio p  
	on left(m.codigo,22)=left(p.numero_predial_nacional,22)
 	where p.id_operacion is null;
   
 
  /*******************************************************
 * Resumen de predio
 */
   
   	select caso::int,detalle,count(*)
   	from colsmart_snc_linea_base.z_v_terrenos
	group by caso,detalle
   	order by caso,detalle;
   
	
   	
   	 	
 
 