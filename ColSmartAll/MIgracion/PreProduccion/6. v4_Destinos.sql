/**
 * Tabla unida con las diferentes fuentes de Corin proyectando la geometria al sistema  snc
 */
	--DROP TABLE IF EXISTS colsmart_prod_insumos.z_x_clc4_main;

	CREATE TABLE colsmart_prod_insumos.z_x_clc4_main AS
	SELECT 
	objectid,
	"class",
	shape
	FROM colsmart_prod_insumos.z_x_clc4
	UNION ALL
	SELECT 
	objectid + 1000000,
	"class",
	shape
	FROM colsmart_prod_insumos.z_x_clc4_x2;


--Cantidad de registros: 94.324
	
/***
 Se crea indices necesario
*/



	CREATE INDEX z_x_clc4_main_shape_idx
	ON colsmart_prod_insumos.z_x_clc4_main
	USING GIST (shape);
	-- Índice espacial en la geometría (shape)
	CREATE INDEX idx_z_x_clc4_main_geom
	ON colsmart_prod_insumos.z_x_clc4_main
	USING GIST (shape);

	-- Índice en la columna "class" (para filtros y joins)
	CREATE INDEX idx_z_x_clc4_main_class
	ON colsmart_prod_insumos.z_x_clc4_main ("class");

	-- (Opcional) Índice en objectid si lo usas para identificar filas
	CREATE UNIQUE INDEX idx_z_x_clc4_main_objectid
	ON colsmart_prod_insumos.z_x_clc4_main (objectid);

/*
 * Crea llave primaria
 */
	ALTER TABLE colsmart_prod_insumos.z_x_clc4_main
	ADD CONSTRAINT z_x_clc4_main_pk PRIMARY KEY (objectid);

/****
 * Crea la tabla de resultados
 */

	drop table colsmart_prod_insumos.z_x_clc4_result;

	create table colsmart_prod_insumos.z_x_clc4_result as
	with cruce as (
		SELECT t.codigo,
		st_area(t.shape) area_terreno,
		"class" clase ,
		st_area(st_intersection(t.shape,c.shape)) area_intercepcion,
		st_intersection(t.shape,c.shape) AS shape
		 FROM colsmart_preprod_migra.cr_terreno  t, colsmart_prod_insumos.z_x_clc4_main c
		 WHERE t.shape is not null and c.shape is not null and ST_Intersects(t.shape,c.shape)
		 and right(left(t.codigo,7),2)='00' and c."class"!=''
	), clc as (
		select destinacioneconomicatipo_ladm_4 ladm,
		clc
		from colsmart_prod_insumos.z_x_clc4_ladm
		where activo=true	
	)select codigo,area_terreno,clase,area_intercepcion,
	c.ladm,
	((area_intercepcion/area_terreno)*100) porcentaje,shape
	from cruce t
	left join clc c on t.clase=c.clc;
	
	

/****
 * Informe destinos ladm
 */


	select ladm,count(*)
	from colsmart_prod_insumos.z_x_clc4_result
	where ladm is not null
	group by ladm;
	
	
/****
 * Si se necesita actualizar los destino.
 */

	update colsmart_prod_insumos.z_x_clc4_result 
	set ladm=c.destinacioneconomicatipo_ladm_4 
	from colsmart_prod_insumos.z_x_clc4_ladm c
	where activo=true	and colsmart_prod_insumos.z_x_clc4_result.clase=c.clc;
	
	
/****
 * Revisa cual es el destino con mas porcetaje de area en el terreno y lo asiga al terreno
 */

	create table colsmart_prod_insumos.z_x_clc4_final as
	with grupo  as (
		select  codigo,ladm,sum(porcentaje) suma_porc
		from colsmart_prod_insumos.z_x_clc4_result
		where ladm is not null and left(codigo,4)!='0000'
		group by codigo,ladm
	),grupo_max as (
		select codigo,max(suma_porc) suma_porc_max
		from grupo
		group by codigo
	),grupo_selec as (
		select  g.*
		from grupo g, grupo_max m
		where g.codigo=m.codigo 
		and g.suma_porc=m.suma_porc_max
	)
	select t.codigo,
	coalesce(g.ladm,'Sin Definicion') destino,
	coalesce(g.suma_porc,0) porcentaje,
	t.shape
	from colsmart_preprod_migra.cr_terreno t 
	left join grupo_selec g
	on t.codigo=g.codigo
	where right(left(t.codigo,7),2)='00';
	
	
	


/****
 * Asignar el destino a cada predio segun selecion
 */

	create table colsmart_prod_insumos.z_x_clc4_predios as
	select *
	from colsmart_preprod_migra.ilc_predio
	where right(left(numero_predial_nacional ,7),2)='00'
	and destinacion_economica in (' ','0');

/****
 * Asignar el destino a cada predio segun selecion
 */	
	
	--drop table colsmart_prod_insumos.z_x_clc4_predios_update;
	
	create table colsmart_prod_insumos.z_x_clc4_predios_update as
	
	
	select f.codigo,f.destino, p.destinacion_economica
	from colsmart_prod_insumos.z_x_clc4_final f
	left join colsmart_prod_insumos.z_x_clc4_predios  p
	on f.codigo=p.numero_predial_nacional
	where   p.destinacion_economica is not null and destino!='Sin Definicion';
	
	
	update colsmart_preprod_migra.ilc_predio
	set destinacion_economica=u.destino
	from colsmart_prod_insumos.z_x_clc4_predios_update u
	where u.codigo=ilc_predio.numero_predial_nacional;


/****
 * update el destino a cada predio segun selecion
 */		
	update colsmart_preprod_migra.ilc_predio
	set destinacion_economica=u.destino
	from colsmart_prod_insumos.z_x_clc4_predios_update u
	where u.codigo=ilc_predio.numero_predial_nacional;
	

/****
 * devolver el destino a cada predio segun selecion
 */	
	update colsmart_preprod_migra.ilc_predio
	set destinacion_economica=''
	from colsmart_prod_insumos.z_x_clc4_predios_update u
	where u.codigo=ilc_predio.numero_predial_nacional;
	
	with ladm as (
		select destinacion_economica,count(*)
		from colsmart_preprod_migra.ilc_predio
		group by destinacion_economica
		order by destinacion_economica
	), destino as (
		select distinct  destinacioneconomicatipo_ladm_4 
		from colsmart_prod_insumos.z_x_clc4_ladm
		order by destinacioneconomicatipo_ladm_4
	)select destinacion_economica,destinacioneconomicatipo_ladm_4
	from destino 
	left join ladm
	on destinacion_economica=destinacioneconomicatipo_ladm_4;



select destinacion_economica,count(*)
from colsmart_preprod_migra.ilc_predio 
group by destinacion_economica;
