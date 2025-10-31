/**
 * Tabla unida con las diferentes fuentes de Corin proyectando la geometria al sistema  snc
 */

	--drop table colsmart_snc_linea_base.z_x_clc4_main;
	
	create table  colsmart_snc_linea_base.z_x_clc4_main as
	select objectid,
	"class",
	sde.st_transform(shape,3) shape
	from colsmart_snc_linea_base.z_x_clc4 
	union all
	select objectid+1000000,"class",sde.st_transform(shape,3)
	from  colsmart_snc_linea_base.z_x_clc4_x2  ;

--Cantidad de registros: 94.324
	
/****
 * Registro de la tabla Corin Main para que luego crear indices correspondientes
 */


	SELECT sde.st_register_spatial_column (
	  current_database(),               -- nombre de la BD
	  'colsmart_snc_linea_base',        -- esquema
	  'z_x_clc4_main',                  -- tabla
	  'shape',                          -- columna espacial
	  3,                             -- SRID
	  2                                 -- 2 = XY (sin Z/M)
	);

/****
 *  Valida el registro de la tabla de Corin
 */

	SELECT sde.st_isregistered_spatial_column(
	       current_database(),            -- o escribe el nombre de tu BD
	       'colsmart_snc_linea_base',
	       'z_x_clc4_main',
	       'shape',
	       3
	);
/****
 * Crea indice a la  tabla de Corin
 */

	CREATE INDEX z_x_clc4_main_shape_sidx
	  ON colsmart_snc_linea_base.z_x_clc4_main
	  USING GIST (shape sde.st_geometry_ops);   -- ArcGIS usa sde.st_geometry_ops
/****
 * Analiza el indice para reindexarlo
 */
	ANALYZE colsmart_snc_linea_base.z_x_clc4_main;
 
/****
 * Crea llave primaria
 */
	ALTER TABLE colsmart_snc_linea_base.z_x_clc4_main
	ADD CONSTRAINT z_x_clc4_main_pk PRIMARY KEY (objectid);

/****
 * Crea la tabla de resultados
 */

	---drop table colsmart_snc_linea_base.z_x_clc4_result;

	create table colsmart_snc_linea_base.z_x_clc4_result as
	with cruce as (
		SELECT t.codigo,
		sde.st_area(t.shape) area_terreno,
		"class" clase ,
		sde.st_area(sde.st_intersection(t.shape,c.shape)) area_intercepcion,
		sde.st_intersection(t.shape,c.shape) AS shape
		 FROM colsmart_test5_owner.cr_terreno  t, colsmart_snc_linea_base.z_x_clc4_main c
		 WHERE t.shape is not null and c.shape is not null and sde.ST_Intersects(t.shape,c.shape)
		 and right(left(t.codigo,7),2)='00' and c."class"!=''
	), clc as (
		select destinacioneconomicatipo_ladm_4 ladm,
		clc
		from colsmart_snc_linea_base.z_x_clc4_ladm
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
	from colsmart_snc_linea_base.z_x_clc4_result
	where ladm is not null
	group by ladm;
	
	
/****
 * Si se necesita actualizar los destino.
 */

	update colsmart_snc_linea_base.z_x_clc4_result 
	set ladm=c.destinacioneconomicatipo_ladm_4 
	from colsmart_snc_linea_base.z_x_clc4_ladm c
	where activo=true	and colsmart_snc_linea_base.z_x_clc4_result.clase=c.clc;
	
	
/****
 * Revisa cual es el destino con mas porcetaje de area en el terreno y lo asiga al terreno
 */

	create table colsmart_snc_linea_base.z_x_clc4_final as
	with grupo  as (
		select  codigo,ladm,sum(porcentaje) suma_porc
		from colsmart_snc_linea_base.z_x_clc4_result
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
	from colsmart_test5_owner.cr_terreno t 
	left join grupo_selec g
	on t.codigo=g.codigo;
	where right(left(t.codigo,7),2)='00';

	
/****
 * Registra tabla final en la gdb
 */
	SELECT sde.st_register_spatial_column (
	  current_database(),               -- nombre de la BD
	  'colsmart_snc_linea_base',        -- esquema
	  'z_x_clc4_final',                  -- tabla
	  'shape',                          -- columna espacial
	  3,                             -- SRID
	  2                                 -- 2 = XY (sin Z/M)
	);

/****
 * Revisa el registro tabla final en la gdb
 */

	SELECT sde.st_isregistered_spatial_column(
	       current_database(),            -- o escribe el nombre de tu BD
	       'colsmart_snc_linea_base',
	       'z_x_clc4_final',
	       'shape',
	       3
	);

/****
 * Crea los indices
 */
	CREATE INDEX z_x_clc4_final_shape_sidx
	  ON colsmart_snc_linea_base.z_x_clc4_final
	  USING GIST (shape sde.st_geometry_ops);   -- ArcGIS usa sde.st_geometry_ops
	
	ANALYZE colsmart_snc_linea_base.z_x_clc4_final;

/****
 * Asignar el destino a cada predio segun selecion
 */

	create table colsmart_snc_linea_base.z_x_clc4_predios as
	select *
	from colsmart_test5_owner.ilc_predio
	where right(left(numero_predial_nacional ,7),2)='00'
	and destinacion_economica in (' ','0');
	
	
	
	