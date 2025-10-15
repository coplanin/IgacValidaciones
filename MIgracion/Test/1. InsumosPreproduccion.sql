


/******
 * Se crea la tabla terreno segun cruce numero predial unica
 */
	create table colsmart_prod_insumos.z_u_r_unidad as
	with unidad as (
		select *,st_area(shape) area_
		from colsmart_prod_base_owner.r_unidad
		union all
		select *,st_area(shape) area_
		from colsmart_prod_base_owner.u_unidad
	), unidad_uni as(
		select  left(codigo,22) npn,st_area(shape) area_,max(objectid) objid
		from unidad
		group by left(codigo,22) ,st_area(shape)
	)
	select u.*
	from unidad u
	inner join unidad_uni  t 
	on left(u.codigo,22)=t.npn 
	and t.area_=u.area_
	and t.objid=u.objectid;

	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad;
	
--240595

/*
 * Total Unidades de Contruccion Inicial
 * 
 */

	with unidad as (
		select *,st_area(shape) area_
		from colsmart_prod_base_owner.r_unidad
		union all
		select *,st_area(shape) area_
		from colsmart_prod_base_owner.u_unidad
	)
	select count(*)
	from unidad;

---276824

/*
 * Datos alfanumerico finales de  unidad Construccion
 */
	drop table colsmart_prod_insumos.z_u_r_unidad_data;

	create table  colsmart_prod_insumos.z_u_r_unidad_data as
	with unidad as (
		select u.numero_predial, '2'::int altura,u.anio_construccion,u.area_construida as area_construccion,
		null::numeric(30,3) as area_privada_construida,u.unidad etiqueta, u.id as id_caracteristicasunidadconstru ,
		u.predio_id as id_operacion_predio,
		u.piso_ubicacion as planta_ubicacion,''::text predio_guid,'Piso'::text tipo_planta
		FROM colsmart_prod_base_owner.main_predio_unidad_construccion u		
	),
	unidad_dist as (
		select distinct numero_predial,
		altura,
		anio_construccion,
		area_construccion,
		area_privada_construida,
		etiqueta as identificador,
		etiqueta as etiqueta,
		id_caracteristicasunidadconstru,
		id_operacion_predio,
		planta_ubicacion,
		predio_guid,
		tipo_planta
		from unidad
	) 
	select *
	from unidad_dist;
	
---391571
