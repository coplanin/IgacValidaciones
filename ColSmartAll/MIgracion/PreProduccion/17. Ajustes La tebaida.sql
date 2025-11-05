
/*
 * ANalisis LA TEBABIDA
 */

/*
 * Total Construcciones
 */

select count(*)
from (
select u.* 
from colsmart_preprod_migra.ilc_predio p
join colsmart_preprod_migra.cr_unidadconstruccion u
on  p.globalid=u.predio_guid
where left(numero_predial_nacional,5)in ('15879','15325','15469')
) t
--22411 Produccion


select count(*)
from (
select u.* 
from colsmart_prod_reader.t_ilc_predio p
join colsmart_prod_reader.t_cr_unidadconstruccion u
on  p.globalid=u.predio_guid
where left(numero_predial_nacional,5)in ('15879','15325','15469')
) t
--26145 Produccion


drop table colsmart_prod_reader.z_pre_cr_unidad;

create table colsmart_prod_reader.z_pre_cr_unidad as 
SELECT st_area(u.shape) area,
ROW_NUMBER() OVER (PARTITION BY st_area(u.shape) ORDER by  u.globalid DESC) AS orden,
u.*
  FROM colsmart_preprod_migra.ilc_predio p
  JOIN colsmart_preprod_migra.cr_unidadconstruccion u
    ON p.globalid = u.predio_guid
  WHERE LEFT(p.numero_predial_nacional, 5) in ('15879','15325','15469');



drop table colsmart_prod_reader.z_pro_cr_unidad;
create table colsmart_prod_reader.z_pro_cr_unidad as 
SELECT st_area(u.shape) area,
ROW_NUMBER() OVER (PARTITION BY st_area(u.shape) ORDER by  u.globalid DESC) AS orden,
u.*
  FROM colsmart_prod_reader.t_ilc_predio p
  JOIN colsmart_prod_reader.t_cr_unidadconstruccion u
    ON p.globalid = u.predio_guid
  WHERE LEFT(p.numero_predial_nacional, 5) in ('15879','15325','15469');

drop table colsmart_prod_reader.unidad_updateprod;

create table colsmart_prod_reader.unidad_updateprod as
WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad 
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND prod.area = pre.area
   and prod.orden = pre.orden
)select *
from t;


WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs(prod.area - pre.area) <120
   and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs(prod.area - pre.area) <1
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs((prod.area/pre.area)-100)<2
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs(prod.area - pre.area_construccion) <17
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);


WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs((prod.area/pre.area_construccion)-100)<6
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



select count(*)-- p.prod_globalid,prod_shape,count(*)
from colsmart_prod_reader.unidad_updateprod p;
--18748

 SELECT count(*)
  FROM colsmart_prod_reader.z_pro_cr_unidad u;
--26145
  
drop table colsmart_prod_reader.unidad_updateprod_uni;

create table  colsmart_prod_reader.unidad_updateprod_uni as
select *
from (
select *,
ROW_NUMBER() OVER (PARTITION BY prod_globalid ORDER by  abs(prod_shape-coalesce(area,area_construccion)) ASC) AS rn
from colsmart_prod_reader.unidad_updateprod
) t
where rn=1;


SELECT *
FROM  colsmart_prod_reader.z_pro_cr_unidad a;
--23676

UPDATE colsmart_prod_reader.z_pro_cr_unidad AS z
SET  altura                         = t.altura,
     anio_construccion             = t.anio_construccion,
     area_construccion             = coalesce(t.area_construccion,st_area(z.shape)),
     area_privada_construida       = t.area_privada_construida,
     etiqueta                      = t.etiqueta,
     id_caracteristicasunidadconstru = coalesce( z.id_caracteristicasunidadconstru, t.id_caracteristicasunidadconstru),
     id_operacion_predio           = t.id_operacion_predio,
     planta_ubicacion              = t.planta_ubicacion,
     tipo_planta                   = t.tipo_planta,
     caracteristicasuc_guid        = t.caracteristicasuc_guid,
     codigo                        = t.codigo,
     identificador                 = t.identificador,
     observaciones                 = 'update_'||t.observaciones
FROM colsmart_prod_reader.unidad_updateprod_uni t
WHERE z.globalid = t.prod_globalid;


drop table colsmart_prod_reader.z_p_unidad_update;

create table colsmart_prod_reader.z_p_unidad_update as
select u.globalid,altura,
anio_construccion::numeric(30,4),area_construccion::numeric(30,4),area_privada_construida,
etiqueta,id_caracteristicasunidadconstru,id_operacion_predio,
planta_ubicacion,tipo_planta,caracteristicasuc_guid,
codigo,identificador,observaciones
from colsmart_prod_reader.z_pro_cr_unidad u
where u.observaciones like 'update_%';


select *
from (
select tcu.predio_guid,
id_operacion_predio,
'Geografica_Construccion_Nueva' marca_tipo,
'Unidad;Geografica_Construccion_Nueva' as detalle,
ST_PointOnSurface(min(tcu.shape)) as shape
from colsmart_prod_reader.t_cr_unidadconstruccion tcu 
where tcu.globalid in (
select globalid from colsmart_prod_reader.z_pro_cr_unidad
except
select globalid from colsmart_prod_reader.z_p_unidad_update)
group by tcu.predio_guid,id_operacion_predio
) t


INSERT INTO colsmart_preprod_migra.ilc_marcas
(objectid, id_operacion_predio, marca_tipo, fecha_ejecucion, marca_estado, detalle, 
globalid, predio_guid,  shape)


with marcas_geo as (


	select tcu.predio_guid,
	(select id_operacion
	from colsmart_prod_reader.t_ilc_predio 
	where globalid=tcu.predio_guid),	
	id_operacion_predio,
	'Geografica_Construccion_Nueva' marca_tipo,
	'Unidad;Geografica_Construccion_Nueva' as detalle,
	ST_PointOnSurface(min(tcu.shape)) as shape
	from colsmart_prod_reader.t_cr_unidadconstruccion tcu 
	where tcu.globalid in (
	select globalid from colsmart_prod_reader.z_pro_cr_unidad
	except
	select globalid from colsmart_prod_reader.z_p_unidad_update)
	group by tcu.predio_guid,id_operacion_predio;
	
	
)
select 
sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas') objectid,
id_operacion_predio,
marca_tipo,
null as fecha_ejecucion,
'Abierta'::text as´marca_estado,
detalle,
sde.next_globalid() globalid,
predio_guid,
shape
from marcas_geo;





