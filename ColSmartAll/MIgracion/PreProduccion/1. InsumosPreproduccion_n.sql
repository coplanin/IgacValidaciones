
/**
 * Se replamza la tabla de unidad, de terreno y costruccion
 * 
 */
	DROP TABLE colsmart_prod_insumos.z_f_r_unidad;

	CREATE TABLE colsmart_prod_insumos.z_f_r_unidad as
	SELECT 
	objectid,
	dump.path[1]         AS parte,                     -- orden del polígono dentro del Multi
	codigo,
	terreno_codigo,
	construccion_codigo,
	planta,
	tipo_construccion,
	tipo_dominio,
	etiqueta,
	identificador,
	usuario_log,
	fecha_log,
	globalid,
	globalid_snc,
	codigo_municipio,
	gdb_geomattr_data,
	dump.geom::geometry(Polygon, 0) AS shape
	FROM   colsmart_prod_base_owner.r_unidad AS t
	CROSS JOIN LATERAL ST_Dump(t.shape) AS dump;

	with codido_remplazar as (
		select c.objectid,numero_predial_nacional,p.numero_predial_nacional , c.shape
		from colsmart_prod_insumos.z_f_r_unidad c
		left join colsmart_preprod_migra.ilc_predio p
		on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
		where p.numero_predial_nacional is null
	)
	update colsmart_prod_insumos.z_f_r_unidad 
	set codigo=t.codigo
	from colsmart_preprod_migra.cr_terreno t,codido_remplazar r
	where ST_Intersects(t.shape, ST_PointOnSurface(z_f_r_unidad.shape))
	and  z_f_r_unidad.objectid=r.objectid;


	DROP TABLE colsmart_prod_insumos.z_f_u_unidad;

	CREATE TABLE colsmart_prod_insumos.z_f_u_unidad as
	SELECT 
	objectid,
	dump.path[1]         AS parte,                     -- orden del polígono dentro del Multi
	codigo,
	terreno_codigo,
	construccion_codigo,
	planta,
	tipo_construccion,
	tipo_dominio,
	etiqueta,
	identificador,
	usuario_log,
	fecha_log,
	globalid,
	globalid_snc,
	codigo_municipio,
	gdb_geomattr_data,
	dump.geom::geometry(Polygon, 0) AS shape
	FROM   colsmart_prod_base_owner.u_unidad AS t
	CROSS JOIN LATERAL ST_Dump(t.shape) AS dump;

	
	with codido_remplazar as (
		select c.objectid,numero_predial_nacional,p.numero_predial_nacional , c.shape
		from colsmart_prod_insumos.z_f_u_unidad c
		left join colsmart_preprod_migra.ilc_predio p
		on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
		where p.numero_predial_nacional is null
	)
	update colsmart_prod_insumos.z_f_u_unidad 
	set codigo=t.codigo
	from colsmart_preprod_migra.cr_terreno t,codido_remplazar r
	where ST_Intersects(t.shape, ST_PointOnSurface(z_f_u_unidad.shape))
	and  z_f_u_unidad.objectid=r.objectid;

	
	DROP TABLE colsmart_prod_insumos.z_f_r_construccion;
	
	CREATE TABLE colsmart_prod_insumos.z_f_r_construccion as
	SELECT
    objectid,
    dump.path[1]         AS parte,                     -- orden del polígono dentro del Multi
   	codigo,
	terreno_codigo,
	tipo_construccion,
	tipo_dominio,
	numero_pisos,
	numero_sotanos,
	numero_mezanines,
	numero_semisotanos,
	etiqueta,
	identificador,
	codigo_edificacion,
	codigo_anterior,
	usuario_log,
	fecha_log,
	globalid,
	globalid_snc,
	codigo_municipio,
	gdb_geomattr_data,
	dump.geom::geometry(Polygon, 0) AS shape
FROM   colsmart_prod_base_owner.r_construccion AS t
CROSS JOIN LATERAL ST_Dump(t.shape) AS dump;


with codido_remplazar as (
	select c.objectid,numero_predial_nacional,p.numero_predial_nacional , c.shape
	from colsmart_prod_insumos.z_f_r_construccion c
	left join colsmart_preprod_migra.ilc_predio p
	on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
	where p.numero_predial_nacional is null
)
update colsmart_prod_insumos.z_f_r_construccion 
set codigo=t.codigo
from colsmart_preprod_migra.cr_terreno t,codido_remplazar r
where ST_Intersects(t.shape, ST_PointOnSurface(z_f_r_construccion.shape))
and  z_f_r_construccion.objectid=r.objectid;



DROP TABLE colsmart_prod_insumos.z_f_u_construccion;

CREATE TABLE colsmart_prod_insumos.z_f_u_construccion as
SELECT
    objectid,
    dump.path[1]         AS parte,                     -- orden del polígono dentro del Multi
   	codigo,
	terreno_codigo,
	tipo_construccion,
	tipo_dominio,
	numero_pisos,
	numero_sotanos,
	numero_mezanines,
	numero_semisotanos,
	etiqueta,
	identificador,
	codigo_edificacion,
	codigo_anterior,
	usuario_log,
	fecha_log,
	globalid,
	globalid_snc,
	codigo_municipio,
	gdb_geomattr_data,
	dump.geom::geometry(Polygon, 0) AS shape
FROM   colsmart_prod_base_owner.u_construccion AS t
CROSS JOIN LATERAL ST_Dump(t.shape) AS dump;

with codido_remplazar as (
	select c.objectid,numero_predial_nacional,p.numero_predial_nacional , c.shape
	from colsmart_prod_insumos.z_f_u_construccion c
	left join colsmart_preprod_migra.ilc_predio p
	on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
	where p.numero_predial_nacional is null
)
update colsmart_prod_insumos.z_f_u_construccion 
set codigo=t.codigo
from colsmart_preprod_migra.cr_terreno t,codido_remplazar r
where ST_Intersects(t.shape, ST_PointOnSurface(z_f_u_construccion.shape))
and  z_f_u_construccion.objectid=r.objectid;




select c.objectid,numero_predial_nacional,p.numero_predial_nacional  
from colsmart_prod_insumos.z_f_r_construccion c
left join colsmart_preprod_migra.ilc_predio p
on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
where p.numero_predial_nacional is null; 


select c.objectid,numero_predial_nacional,p.numero_predial_nacional  
from colsmart_prod_insumos.z_f_u_unidad c
left join colsmart_preprod_migra.ilc_predio p
on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
where p.numero_predial_nacional is null; 


select c.objectid, numero_predial_nacional,p.numero_predial_nacional  
from colsmart_prod_insumos.z_f_r_unidad c
left join colsmart_preprod_migra.ilc_predio p
on  left(c.codigo,22)=left(p.numero_predial_nacional,22)
where p.numero_predial_nacional is null; 






select *
from colsmart_prod_insumos.z_f_u_construccion c
left join colsmart_preprod_migra.ilc_predio p
on c.codigo =p.numero_predial_nacional;

DROP TABLE colsmart_prod_insumos.z_f_r_terreno;

CREATE TABLE colsmart_prod_insumos.z_f_r_terreno as
SELECT *
FROM colsmart_prod_base_owner.r_terreno;


DROP TABLE colsmart_prod_insumos.z_f_u_terreno;

CREATE TABLE colsmart_prod_insumos.z_f_u_terreno as
SELECT *
FROM colsmart_prod_base_owner.u_terreno;


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
		etiqueta,
		id_caracteristicasunidadconstru,
		id_operacion_predio,
		planta_ubicacion,
		predio_guid,
		tipo_planta
		from unidad
	) 
	select *
	from unidad_dist;
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_unidad_data;
	
	select count(*)
	FROM colsmart_prod_base_owner.main_predio_unidad_construccion u	
	
---391561
