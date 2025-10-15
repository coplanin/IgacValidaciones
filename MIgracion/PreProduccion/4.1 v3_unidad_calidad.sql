
/****************************
* UNIDADES 
*/

/****************************
 * Cantidad unidades rurales 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_unidad;
    
--3323

/****************************
 * Cantidad Unidades rurales  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_unidad
	where length(codigo)<30;
	
--0
	
	
/****************************
 * Cantidad Unidades rurales informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_unidad
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');
	
--483
	
/****************************
 * Cantidad Unidades urbanas 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_unidad;
    
--148031

/****************************
 * Cantidad Unidades urbanas  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_unidad
	where length(codigo)<30;
	
--3
		
/****************************
 * Cantidad Unidades rurales informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_unidad
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');

--2623
	
/****************************
 * Cantidad Unidades 
 */
	select count(*)
	from (
	    SELECT *
	  	FROM colsmart_prod_insumos.z_f_r_unidad
	    union all
	    SELECT *
	  	FROM colsmart_prod_insumos.z_f_u_unidad
	) t;

--156326
 
  /*****************************************************
   * crea tabla terreno para casoes
   */

	drop table  colsmart_prod_insumos.z_b_unidad;	
 
 	create table colsmart_prod_insumos.z_b_unidad as
 	select *,st_area(shape) area_,
	objectid as t_id
	from colsmart_prod_insumos.z_f_r_unidad
	union all
	select *,st_area(shape) area_,
	objectid+1000000 as t_id
	from colsmart_prod_insumos.z_f_u_unidad;
	
--156326
 
 	drop table colsmart_prod_insumos.z_v_unidad;
 	
	select *
	from colsmart_prod_insumos.z_v_unidad;
 
  
  /*******************************************************
 * Unidades  duplicados
 */
  
  	INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	
	create table colsmart_prod_insumos.z_v_unidad as
	with unidad as (
		select *
		from colsmart_prod_insumos.z_b_unidad
	), unidad_uni as(
		select  codigo ,identificador,planta,st_area(shape) area_,
		max(globalid_snc) globalid_snc,
		max(t_id) t_id,count(*) cuenta
		from unidad
		group by codigo,identificador ,planta,st_area(shape)
	),duplicados as (
		select u.*
		from unidad_uni u
		where cuenta>1
	)
	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid() globalid,
	u.codigo,'1'::int caso,''::text detalle, 
	u.globalid_snc, u.shape
   	from duplicados d,unidad u
	where d.t_id=u.t_id;
	  
 --450	
  	
   
  /*******************************************************
 * Codigo no valido
 */
	
	INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)  
	with unidad as (
		select *
		from colsmart_preprod_migra.cr_unidadconstruccion
	),cod as (
		select left(codigo,5) mpcodigo
		from unidad
	  	group by left(codigo,5)
	  	except
	  	select mpcodigo
	  	from colsmart_prod_insumos.igac_municipios_divipola
	   	where mpcodigo !='00000'
   	)
   	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid() as globalid,
	codigo,'2'::int caso,'Geografica_Unidad_Codigo_No_Valido'::text detalle, 
	''::text globalid_snc, shape
   	from unidad t,cod c
   	where c.mpcodigo=left(t.codigo,5);
   	
--30
  /*******************************************************
 * Geometria de construccion no valida
 */
    INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *
		from colsmart_preprod_migra.cr_unidadconstruccion
	)	
	select --distinct  st_geometrytype(shape)::text
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'3'::int caso,
	'Geografica_Unidad_Geometria_No_Valida'::TEXT detalle, 
	''::TEXT globalid_snc,
	shape
	from unidad t
    where  st_geometrytype(shape)::text not in ('ST_Polygon')
	or shape is NULL;
   	
 --387  	
  
/*******************************************************
 * Sin identificador
 */
    INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	
	with unidad as (
		select *
		from colsmart_prod_insumos.z_b_unidad
	)	
	select 
	--sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	--sde.next_globalid(),
	codigo,'4'::int caso,
	'unidad sin identificador'::text detalle, globalid_snc,shape
	FROM   unidad t
	where identificador='' or  identificador is null;


 ---2441
 
 

 	
/*******************************************************
 * Unidad Sin piso o piso cero
 */
    INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *,
		CASE
		  WHEN planta='' THEN '0'::text
		  WHEN planta='' THEN '0'::text
		else planta
		END planta_fix
		from colsmart_prod_insumos.z_b_unidad		
	)	
	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'5'::int caso,
	'Unidad in pisos  o piso cero'::text detalle, globalid_snc,shape
	FROM  unidad t
	where   REGEXP_REPLACE(planta_fix, '[^\d]+', '', 'g')::int is null or  REGEXP_REPLACE(planta_fix, '[^\d]+', '', 'g')::int=0;

--0
 	
   	

   
   /*******************************************************
 * Unidad sin predio
 */
    INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	
	create table colsmart_prod_insumos.z_v_unidad as
	with unidad as (
		select *
		from colsmart_prod_insumos.z_b_unidad
	)	
	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid() globalid,
	codigo,'6'::int caso,
	'Geografica_Unidad_Sin_Predio'::text detalle,
	m.globalid_snc,m.shape
   	from unidad m
 	left join  colsmart_preprod_migra.ilc_predio p  
	on left(m.codigo,22)=left(p.numero_predial_nacional,22)
 	where p.id_operacion is null; --or codigo not in (' ','','0');
   
	
	INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid, globalid,  codigo, caso, detalle,globalid_snc, shape)
	with  unidad as (
		select *
		from colsmart_preprod_migra.cr_unidadconstruccion
		where  id_operacion_predio is  null
	)
	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'6'::int caso,
	'Geografica_Unidad_Sin_Predio'::text detalle,
	''::text	globalid_snc,m.shape
   	from unidad m;
 	
   

 	
 /*******************************************************
 * Unidad sin terreno
 */
    INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid, globalid,  codigo, caso, detalle,globalid_snc, shape)
	with  terreno as (
		select *,st_area(shape) area_,objectid t_id
		from colsmart_prod_insumos.z_f_r_terreno
		union all
		select *,st_area(shape) area_,objectid+1000000 t_id
		from colsmart_prod_insumos.z_f_u_terreno
	),unidad as (
		select u.*
		from colsmart_prod_insumos.z_b_unidad u
		left join terreno t
		on st_intersects(st_pointonsurface(u.shape),t.shape)
		where t.t_id is null
	)
	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'7'::int caso,
	'Geografica_Unidad_Sin_Terreno_Asociado'::text detalle,
	m.globalid_snc,m.shape
   	from unidad m;
 	
 /*******************************************************
 * Unidad_Construccion_Nueva
 */
    INSERT INTO colsmart_prod_insumos.z_v_unidad
	(objectid, globalid,  codigo, caso, detalle,globalid_snc, shape)
	with  unidad as (
		select *
		from colsmart_preprod_migra.cr_unidadconstruccion
		where id_caracteristicasunidadconstru is null
 		and id_operacion_predio is not null
	)
	select 
	sde.next_rowid('colsmart_prod_insumos', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'7'::int caso,
	'Geografica_Construccion_Nueva'::text detalle,
	''::text	globalid_snc,m.shape
   	from unidad m;
 	
	
	
	select codigo
	from colsmart_preprod_migra.cr_unidadconstruccion
	where length(codigo)<30;
    
   	select caso,detalle,count(*)
 	from colsmart_prod_insumos.z_v_unidad
 	group by caso,detalle
 	order by caso;
	
 	
 	delete 
 	from colsmart_prod_insumos.z_v_unidad
 	where caso=3;
   
	
   	
   	 	
 
 