
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
     caracteristicasuc_guid        = coalesce( z.caracteristicasuc_guid, t.caracteristicasuc_guid), 
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
where u.observaciones like 'update_%'
and LEFT(codigo,5) = '15469';




create table colsmart_prod_reader.z_p_unidad_nueva as
select *
from colsmart_prod_reader.z_pro_cr_unidad
where LEFT(codigo,7) = '1546900'
and coalesce(observaciones,'-') not like 'update_%';











INSERT INTO colsmart_preprod_migra.ilc_marcas
(objectid, id_operacion_predio, marca_tipo, fecha_ejecucion, marca_estado, detalle, 
 globalid, predio_guid, shape)
WITH marcas_geo AS (
  SELECT
    tcu.predio_guid,
    /* id_operacion del predio */
    (SELECT id_operacion
     FROM colsmart_prod_reader.t_ilc_predio 
     WHERE globalid = tcu.predio_guid)         AS id_operacion,
    /* numero_predial_nacional para el filtro final */
    (SELECT numero_predial_nacional
     FROM colsmart_prod_reader.t_ilc_predio 
     WHERE globalid = tcu.predio_guid)         AS numero_predial_nacional,
    'Geografica_Construccion_Nueva'            AS marca_tipo,
    'Posterior;Unidad;Geografica_Construccion_Nueva' AS detalle,
    /* Punto representativo sobre la unión de las UC del predio */
      St_setsrid(ST_PointOnSurface(
        ST_Collect(tcu.shape) 
      ),0)::geometry(Point, 0)   AS shape
  FROM colsmart_prod_reader.t_cr_unidadconstruccion AS tcu
  WHERE tcu.globalid IN (
      SELECT globalid FROM colsmart_prod_reader.z_pro_cr_unidad
      EXCEPT
      SELECT globalid FROM colsmart_prod_reader.z_p_unidad_update
  )
  GROUP BY tcu.predio_guid
)
SELECT 
  sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas')             AS objectid,
  id_operacion                                                       AS id_operacion_predio,
  marca_tipo,
  NULL                                                               AS fecha_ejecucion,
  'Abierta'::text                                                    AS marca_estado,
  detalle,
  sde.next_globalid()                                                AS globalid,
  predio_guid,
  shape 
FROM marcas_geo
WHERE LEFT(numero_predial_nacional,7) = '1546900'
  AND shape IS NOT null;
--limit 10;

update colsmart_preprod_migra.ilc_marcas
set detalle='update_Unidad;Geografica_Construccion_Nueva'
where detalle='Posterior;Unidad;Geografica_Construccion_Nueva'


create table colsmart_prod_reader.z_p_marcas_update as
select *
from colsmart_preprod_migra.ilc_marcas
where detalle='update_Unidad;Geografica_Construccion_Nueva'

select distinct tip.numero_predial_nacional 
from colsmart_prod_reader.t_ilc_predio tip 
join colsmart_prod_reader.z_pro_cr_unidad u 
on u.predio_guid=tip.globalid 
where left(tip.numero_predial_nacional,7)='1546900'
and coalu.observaciones like  'update_%';

--4.667 Predio en moniquira rulaes 
--5508 exitian snc de la inforcion
--5540 Contrucciones nuevas que no cruzan con el r2 que parte alfanuemrica  del snc



select  (11048-5508)::int
--5540
--15407}}



ALTER TABLE colsmart_prod_insumos.z_puntos_rurales_mon
ADD COLUMN geo GEOMETRY(Point, 9377);

drop table colsmart_prod_reader.z_pro_cr_unidad_moni;

create table colsmart_prod_insumos.z_pro_cr_unidad_moni as
with unidad as (
	select u.*
	from colsmart_prod_reader.t_ilc_predio  p
	join colsmart_prod_reader.z_pro_cr_unidad u 
	on u.predio_guid=p.globalid 
	where left(p.numero_predial_nacional,7)='1546900'
	and st_area(u.shape)>20
),buffer as (
	select st_buffer(geo,10) geom 
	from colsmart_prod_insumos.z_puntos_rurales_mon
)select u.*
from unidad u,buffer b
where st_intersects(u.shape,b.geom)


---Construcciones menores a 20
update colsmart_prod_reader.z_p_unidad_nueva u
set caso1='ok'
from (
select  u.globalid
from colsmart_prod_reader.t_ilc_predio  p
join colsmart_prod_reader.z_p_unidad_nueva u 
on u.predio_guid=p.globalid 
where left(p.numero_predial_nacional,7)='1546900'
and st_area(u.shape)<20) t
where t.globalid =u.globalid 
-- menos de 20= 830 --473
-- mas de 80=5586 --2416
-- mas de 100=4359 --2918


---Construcciones mayores a 100
update colsmart_prod_reader.z_p_unidad_nueva u
set caso2='ok'
from (
select  u.globalid
from colsmart_prod_reader.t_ilc_predio  p
join colsmart_prod_reader.z_p_unidad_nueva u 
on u.predio_guid=p.globalid 
where left(p.numero_predial_nacional,7)='1546900'
and st_area(u.shape)>100) t
where t.globalid =u.globalid 



---Poligonos a 5 metros de puntos de comercio
--create table colsmart_prod_insumos.z_pro_cr_unidad_moni as
with unidad as (
	select u.*
	from colsmart_prod_reader.t_ilc_predio  p
	join colsmart_prod_reader.z_p_unidad_nueva u 
	on u.predio_guid=p.globalid 
	where left(p.numero_predial_nacional,7)='1546900'
	and st_area(u.shape)>20 and st_area(u.shape)<100
),buffer as (
	select st_buffer(geo,5) geom 
	from colsmart_prod_insumos.z_puntos_rurales_mon
	union 
	select st_buffer(st_setsrid(geom,9377),5) geom 
	from colsmart_prod_insumos.z_puntos_rurales_mon_2
),cruce as (
	select u.*
	from unidad u,buffer b
	where st_intersects(u.shape,b.geom)
)
update colsmart_prod_reader.z_p_unidad_nueva u
set caso3='ok'
from cruce c
where u.globalid=c.globalid;--21

---cruce con cobertura de construcciones
with unidad as (
	select u.*
	from colsmart_prod_reader.t_ilc_predio  p
	join colsmart_prod_reader.z_p_unidad_nueva u 
	on u.predio_guid=p.globalid 
	where left(p.numero_predial_nacional,7)='1546900'
	and st_area(u.shape)>20 and st_area(u.shape)<100
),zona as (
	select  *--gridcode,classname
	from colsmart_prod_insumos.z_p_landcover
	where gridcode=5
),cruce as (
	select u.*
	from zona z,unidad u
	where st_intersects(u.shape,z.geom)
)
update colsmart_prod_reader.z_p_unidad_nueva u
set caso4='ok'
from cruce c
where u.globalid=c.globalid;--21

select count(*)
from (
select distinct predio_guid 
from colsmart_prod_reader.z_p_unidad_nueva
where caso1='ok' or
caso2='ok' or caso3='ok' or caso4='ok') t

--2261


select count(caso1) caso1,count(caso2) caso2,
count(caso3) caso3,count(caso4) caso4,count(*) total_validados
from colsmart_prod_reader.z_p_unidad_nueva
where caso1='ok' or
caso2='ok' or caso3='ok' or caso4='ok'


update colsmart_prod_reader.z_p_unidad_nueva
set validar='ok'
where caso1='ok' or
caso2='ok' or caso3='ok' or caso4='ok'



select count(*)
from colsmart_prod_reader.z_p_unidad_nueva;

select distinct predio_guid 
from colsmart_prod_reader.z_p_unidad_nueva;


select *
from colsmart_prod_reader.t_ilc_predio
where globalid in (
select distinct predio_guid 
from colsmart_prod_reader.z_p_unidad_nueva
except
select predio_guid
from (
select distinct predio_guid 
from colsmart_prod_reader.z_p_unidad_nueva
where validar='ok'
except
select distinct predio_guid 
from colsmart_prod_reader.z_p_unidad_nueva
where validar is null
) t);

create table  colsmart_prod_reader.z_p_marca_cerrar as
select *
from colsmart_prod_reader.z_p_marcas_update
where predio_guid in (
	select distinct predio_guid 
	from colsmart_prod_reader.z_p_unidad_nueva
	where validar='ok'
	except
	select distinct predio_guid 
	from colsmart_prod_reader.z_p_unidad_nueva
	where validar is null
);


ALTER TABLE colsmart_prod_insumos.z_p_landcover
ALTER COLUMN geom TYPE  geometry(multipolygon, 9377)
USING ST_Transform(ST_SetSRID(geom,3857) , 9377);

-- menos de 20= 830 --473
-- mas de 80=5586 --2416
-- mas de 100=4359 --2918



--5540

select (839+4359+224)::int,
(473+2918+224)::int,
5540-(473+2918+224)::int;



select st_srid(shape)
from colsmart_prod_reader.z_pro_cr_unidad_moni


ALTER TABLE colsmart_prod_reader.z_pro_cr_unidad_moni
ALTER COLUMN shape TYPE geometry(polygon,9377);


ALTER TABLE colsmart_prod_reader.z_pro_cr_unidad_moni
ADD COLUMN geo GEOMETRY(MultiPolygon, 9377);

update colsmart_prod_reader.z_pro_cr_unidad_moni
set geo=Multi(ST_SetSRID(shape,9377));







