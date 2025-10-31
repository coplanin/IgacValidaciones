 
/****************************
 * Cantidad Construcciones rurales 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_construccion_40;
	

    
--78228

/****************************
 * Cantidad Construcciones rurales  nuevas
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_construccion_40
	where length(z_y_r_construccion_40.codigo)<30;
	
--67829
	
	
/****************************
 * Cantidad Construcciones rurales informales
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_r_construccion_40
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');
	
--453
	
/****************************
 * Cantidad Construcciones urbanas 
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_construccion_40;
    
--131656

/****************************
 * Cantidad Construcciones urbanas  nuevas
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_construccion_40
	where length(codigo)<30;
	
--2069
	
	
/****************************
 * Cantidad Construcciones urbanas informales
 */

	SELECT count(*)
  	FROM colsmart_snc_linea_base.z_y_u_construccion_40
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');

--4028
	
/****************************
 * Cantidad construcciones 
 */
	select count(*)
	from (
	    SELECT *
	  	FROM colsmart_snc_linea_base.z_y_u_construccion_40
	    union all
	    SELECT *
	  	FROM colsmart_snc_linea_base.z_y_u_construccion_40
	) t;

--263312

 
  /*****************************************************
   * crea tabla terreno para casoes
   */
	drop table colsmart_snc_linea_base.z_b_construccion;

 
 	create table colsmart_snc_linea_base.z_b_construccion as
 	select *,sde.st_area(shape) area_,
	objectid as t_id
	from colsmart_snc_linea_base.z_y_r_construccion_40
	union all
	select *,sde.st_area(shape) area_,
	objectid+1000000 as t_id
	from colsmart_snc_linea_base.z_y_u_construccion_40;
	
		
  	
  
	delete 
	from colsmart_snc_linea_base.z_v_construccion;
   
  /*******************************************************
 * Construccion  caso codigo municipio
 */
    INSERT INTO colsmart_snc_linea_base.z_v_construccion
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)   
	with construccion as (
		select *
		from colsmart_snc_linea_base.z_b_construccion
	),cod as (
		select left(codigo,5) mpcodigo
		from construccion
	  	where length(codigo)>=30
	  	group by left(codigo,5)
	  	except
	  	select mpcodigo
	  	from colsmart_snc_linea_base.igac_municipios_divipola
	   	where mpcodigo !='00000'
   	)
   	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_construccion') objectid,
	sde.next_globalid(),
	codigo,'1'::int caso,'Codigo no valido'::text detalle, 
	globalid_snc, shape
   	from construccion t,cod c
   	where c.mpcodigo=left(t.codigo,5);
   	
--76
  /*******************************************************
 * Geometria de construccion no valida
 */
    INSERT INTO colsmart_snc_linea_base.z_v_construccion
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with construccion as (
		select *
		from colsmart_snc_linea_base.z_b_construccion
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_construccion') objectid,
	sde.next_globalid(),
	codigo,'2'::int caso,
	'Tipo de geometria no valido '::text|| COALESCE(sde.st_geometrytype(shape)::text,'No definido'::text) detalle, 
	globalid_snc,shape
	from construccion t
    where  sde.st_geometrytype(shape)::text not in ('ST_POLYGON');
   	
 --2363  	
  
/*******************************************************
 * Sin identificador
 */
    INSERT INTO colsmart_snc_linea_base.z_v_construccion
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with construccion as (
		select *
		from colsmart_snc_linea_base.z_b_construccion
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_construccion') objectid,
	sde.next_globalid(),
	codigo,'3'::int caso,
	'Construccion sin identificador'::text detalle, globalid_snc,shape
	FROM   construccion t
	where identificador='' or  identificador is null;


	select * 
	from colsmart_snc_linea_base.z_v_construccion
	where caso=3;
 ---2441
 
 

 	
/*******************************************************
 * Sin piso o piso cero
 */
    INSERT INTO colsmart_snc_linea_base.z_v_construccion
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with construccion as (
		select *
		from colsmart_snc_linea_base.z_b_construccion
	)	
	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_construccion') objectid,
	sde.next_globalid(),
	codigo,'4'::int caso,
	'Sin pisos  o piso cero'::text detalle, globalid_snc,shape
	FROM   construccion t
	where  numero_pisos is null or  numero_pisos=0;

 --	5768
   	
 /*******************************************************
 * Construcciones sin predio hasta la posicion 22
 */
    INSERT INTO colsmart_snc_linea_base.z_v_construccion
	(objectid,globalid,  codigo, caso, detalle,globalid_snc, shape)
	with construccion as (
		select *
		from colsmart_snc_linea_base.z_v_construccion
	)	
   	select 
	sde.next_rowid('colsmart_snc_linea_base', 'z_v_construccion') objectid,
	sde.next_globalid(),
	codigo,'5'::int caso,
	'Construcciones sin predio hasta la posicion 22'::text detalle,
	globalid_snc,m.shape
   	from construccion m
 	left join  colsmart_test5_owner.ilc_predio p  
	on left(m.codigo,22)=left(p.numero_predial_nacional,22)
 	where p.id_operacion is null and codigo not in (' ','','0');
   
   
   	select caso,detalle,count(*)
 	from colsmart_snc_linea_base.z_v_construccion
 	group by caso,detalle
 	order by caso
	
   
	
   	
   	 	
 
 