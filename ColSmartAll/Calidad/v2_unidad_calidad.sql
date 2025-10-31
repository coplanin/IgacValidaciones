
/****************************
* UNIDADES 
*/

/****************************
 * Cantidad unidades rurales 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_unidad_40;
    
--3323

/****************************
 * Cantidad Unidades rurales  nuevas
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_unidad_40
	where length(codigo)<30;
	
--0
	
	
/****************************
 * Cantidad Unidades rurales informales
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_unidad_40
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');
	
--483
	
/****************************
 * Cantidad Unidades urbanas 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_unidad_40;
    
--148031

/****************************
 * Cantidad Unidades urbanas  nuevas
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_unidad_40
	where length(codigo)<30;
	
--3
		
/****************************
 * Cantidad Unidades rurales informales
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_unidad_40
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');

--2623
	
/****************************
 * Cantidad Unidades 
 */
	select count(*)
	from (
	    SELECT *
	  	FROM colsmart_snc_linea_base.z_y_r_unidad_40
	    union all
	    SELECT *
	  	FROM colsmart_snc_linea_base.z_y_u_unidad_40
	) t;

--156326
 
  /*****************************************************
   * crea tabla terreno para casoes
   */

	drop table  colsmart_snc_linea_base.z_b_unidad;	
 
 	create table colsmart_snc_linea_base.z_b_unidad as
 	select *,sde.st_area(shape) area_,
	objectid as t_id
	from colsmart_snc_linea_base.z_y_r_unidad_40
	union all
	select *,sde.st_area(shape) area_,
	objectid+1000000 as t_id
	from colsmart_snc_linea_base.z_y_u_unidad_40;
	
--156326
 
	delete
	from colsmart_snc_linea_base.z_v_unidad;
 
  
  /*******************************************************
 * Unidades  duplicados
 */
  
  	INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *
		from colsmart_snc_linea_base.z_b_unidad
	), unidad_uni as(
		select  codigo ,identificador,planta,sde.st_area(shape) area_,
		max(globalid_snc) globalid_snc,
		max(t_id) t_id,count(*) cuenta
		from unidad
		group by codigo,identificador ,planta,sde.st_area(shape)
	),duplicados as (
		select u.*
		from unidad_uni u
		where cuenta>1
	)
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	u.codigo,'1'::int caso,'Unidad duplicada en codigo,piso,identificador,area'::text detalle, 
	u.globalid_snc, u.shape
   	from duplicados d,unidad u
	where d.t_id=u.t_id;
	  
 --450	
  	
   
  /*******************************************************
 * Codigo no valido
 */
    INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)   
	with unidad as (
		select *
		from colsmart_snc_linea_base.z_b_unidad
	),cod as (
		select left(codigo,5) mpcodigo
		from unidad
	  	where length(codigo)>=30
	  	group by left(codigo,5)
	  	except
	  	select mpcodigo
	  	from colsmart_snc_linea_base.igac_municipios_divipola
	   	where mpcodigo !='00000'
   	)
   	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'2'::int caso,'Codigo no valido'::text detalle, 
	globalid_snc, shape
   	from unidad t,cod c
   	where c.mpcodigo=left(t.codigo,5);
   	
--30
  /*******************************************************
 * Geometria de construccion no valida
 */
    INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *
		from colsmart_snc_linea_base.z_b_unidad
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'3'::int caso,
	'Tipo de geometria no valido '::text|| COALESCE(sde.st_geometrytype(shape)::text,'No definido'::text) detalle, 
	globalid_snc,shape
	from unidad t
    where  sde.st_geometrytype(shape)::text not in ('ST_POLYGON');
   	
 --387  	
  
/*******************************************************
 * Sin identificador
 */
    INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *
		from colsmart_snc_linea_base.z_b_unidad
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'4'::int caso,
	'unidad sin identificador'::text detalle, globalid_snc,shape
	FROM   unidad t
	where identificador='' or  identificador is null;


 ---2441
 
 

 	
/*******************************************************
 * Unidad Sin piso o piso cero
 */
    INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *
		from colsmart_snc_linea_base.z_b_unidad
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'5'::int caso,
	'Unidad in pisos  o piso cero'::text detalle, globalid_snc,shape
	FROM   unidad t
	where  REGEXP_REPLACE(planta, '[^\d]+', '', 'g')::int is null or  REGEXP_REPLACE(planta, '[^\d]+', '', 'g')::int=0;

--0
 	
   	

   
   /*******************************************************
 * Unidad sin predio
 */
    INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with unidad as (
		select *
		from colsmart_snc_linea_base.z_b_unidad
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'6'::int caso,
	'Unidad sin predio hasta la posicion 22'::text detalle,
	m.globalid_snc,m.shape
   	from unidad m
 	left join  colsmart_test5_owner.ilc_predio p  
	on left(m.codigo,22)=left(p.numero_predial_nacional,22)
 	where p.id_operacion is null and codigo not in (' ','','0');
   
   

 	
 /*******************************************************
 * Unidad sin terreno
 */
    INSERT INTO colsmart_snc_linea_base.z_v_unidad
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with  terreno as (
		select *,sde.st_area(shape) area_,objectid t_id
		from colsmart_snc_linea_base.z_y_r_terreno_40
		union all
		select *,sde.st_area(shape) area_,objectid+1000000 t_id
		from colsmart_snc_linea_base.z_y_u_terreno_40
	),unidad as (
		select u.*
		from colsmart_snc_linea_base.z_b_unidad u
		left join terreno t
		on sde.st_intersects(sde.st_pointonsurface(u.shape),t.shape)
		where t.t_id is null
	)
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_unidad') objectid,
	sde.next_globalid(),
	codigo,'7'::int caso,
	'Unidad sin terreno asociado'::text detalle,
	m.globalid_snc,m.shape
   	from unidad m;
 	

    
   	select caso,detalle,count(*)
 	from colsmart_snc_linea_base.z_v_unidad
 	group by caso,detalle
 	order by caso
	
   
	
   	
   	 	
 
 