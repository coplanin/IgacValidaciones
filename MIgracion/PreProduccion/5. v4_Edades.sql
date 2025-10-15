--union all
--select numero_predial,primer_anio, 'unidad_u'::text fuente,2::int nivel
--from  colsmart_prod_insumos.z_h_rconstruccion_edades

--incluirle al script la carga de parkers  y documetcar

/******
 * Crea tabla unica de edades
 */
	drop table z_h_edades;

	create table z_h_edades as
		select numero_predial,primer_anio, 'unidad_r'::text fuente,1::int nivel  
		from  colsmart_prod_insumos.z_h_runidad_edades
		union all
			select numero_predial,primer_anio, 'unidad_r_i'::text fuente,1::int nivel  
			from  colsmart_prod_insumos.z_h_runidad_informal_edades
		union all
			select numero_predial,primer_anio, 'unidad_u'::text fuente,1::int nivel 
			from  colsmart_prod_insumos.z_h_uunidad_edades
		union all
			select numero_predial,primer_anio, 'unidad_u_i'::text fuente,1::int nivel 
			from  colsmart_prod_insumos.z_h_uunidad_informal_edades
		union all
			select numero_predial,primer_anio, 'construccion_u'::text fuente,2::int nivel 
			from  colsmart_prod_insumos.z_h_uconstruccion_edades
		union all
			select numero_predial,primer_anio, 'construccion_u_i'::text fuente,2::int nivel 
			from  colsmart_prod_insumos.z_h_uconstruccion_informal_edades
		union all
			select numero_predial,primer_anio, 'construccion_r_i'::text fuente,2::int nivel 
			from  colsmart_prod_insumos.z_h_rconstruccion_informal_edades
		union all
			select numero_predial,primer_anio, 'construccion_r'::text fuente,2::int nivel 
			from  colsmart_prod_insumos.z_h_rconstruccion_edades
		union all
			select numero_predial,primer_anio, 'terreno_u'::text fuente ,3::int nivel 
			from  colsmart_prod_insumos.z_h_uterreno_edades
		union all
			select numero_predial,primer_anio, 'terreno_u_i'::text fuente ,3::int nivel 
			from  colsmart_prod_insumos.z_h_uterreno_informal_edades
		union all
			select numero_predial,primer_anio, 'terreno_u'::text fuente ,3::int nivel
			from  colsmart_prod_insumos.z_h_rterreno_edades
		union all
			select numero_predial,primer_anio, 'terreno_u_i'::text fuente ,3::int nivel 
			from  colsmart_prod_insumos.z_h_uterreno_informal_edades;
	
	select *
	from z_h_edades;

/******
 * Seleccion de edad de la construccion
 */
	drop table z_h_edades_anio;
	
	create table z_h_edades_anio as
	with npm_nivel as (
		select numero_predial,nivel,min(primer_anio) primer_anio_m
		from z_h_edades
		group by  numero_predial,nivel
	),npm_unico as (
		select numero_predial
		from npm_nivel
		group by numero_predial
	), npm_anios as (
		select nu.numero_predial,n1.primer_anio_m anio_unidad,
		n2.primer_anio_m anio_construccion,n3.primer_anio_m anio_terreno
		from npm_unico nu
		left join npm_nivel n1 on nu.numero_predial=n1.numero_predial and n1.nivel=1
		left join npm_nivel n2 on nu.numero_predial=n2.numero_predial and n2.nivel=2
		left join npm_nivel n3 on nu.numero_predial=n3.numero_predial and n3.nivel=3
		--where 
			--n2.primer_anio_m is not null and
			--n2.primer_anio_m is not null and
			--n3.primer_anio_m is not null
	)
	select numero_predial,anio_unidad,anio_construccion,anio_terreno,
	coalesce(anio_construccion,anio_unidad,anio_terreno) anio_final
	from npm_anios;
	
	select count(*)
	from z_h_edades_anio;
	
--571.585
/******
 * Validacion
 */

	with terreno as (
		select *
		from z_h_edades_anio
		where anio_unidad is null and anio_construccion is null 
		limit 1
	)
	, construccion as (
		select *
		from z_h_edades_anio
		where anio_unidad is null and anio_construccion is not  null 
		limit 1
	)
	, unidad as (
		select *
		from z_h_edades_anio
		where anio_unidad is not  null and anio_construccion is not null 
		and anio_unidad=2024
		limit 2
	)
	, unidad2 as (
		select *
		from z_h_edades_anio
		where anio_unidad is  not null and anio_construccion is  null 
		limit 2
	)
	select *
	from terreno
	union 
		select *
		from construccion
	union 
		select *
		from unidad
	union 
		select *
		from unidad2
		order by anio_unidad,anio_construccion;
	
/************
 * anio_construccion inicial 
 */	
	
	select count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion cu 
	where anio_construccion is  null;
	
--531.327
	
/************
 * Cruzar con la informacion de unidad de construccion
 */	
	drop table z_h_edades_anio_cruce;

	create table z_h_edades_anio_cruce as
	with unidad_sinanio as (	
		select *
		from colsmart_preprod_migra.cr_unidadconstruccion cu 
		where anio_construccion is null
	),unidad_cruce as (
		select a.anio_final, s.*
		from unidad_sinanio s
		inner join z_h_edades_anio a on s.codigo=a.numero_predial
	)
	select codigo,globalid,anio_final
	from unidad_cruce;

/************
 * Update edades con la informacion de unidad de construccion
 */	
	
	update colsmart_preprod_migra.cr_unidadconstruccion
	set anio_construccion=c.anio_final
	from z_h_edades_anio_cruce c
	where c.globalid=cr_unidadconstruccion.globalid;
	
	
	update colsmart_preprod_migra.cr_unidadconstruccion
	set anio_construccion=null
	where anio_construccion<1900
	
	
	
		
	update colsmart_preprod_migra.cr_unidadconstruccion
	set anio_construccion=null
	from z_h_edades_anio_cruce c
	where c.globalid=cr_unidadconstruccion.globalid;
	
	
/****
 * Edadres informes 
 * 
 */	
	select count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion
	where anio_construccion is NOT null 
	
	39651
	551968
	
	group by anio_construccion
	
	select anio_construccion,count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion
	group by anio_construccion