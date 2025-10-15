ALTER TABLE prod.t_cr_unidadconstruccion
DROP COLUMN geom;


ALTER TABLE prod.t_cr_unidadconstruccion
ADD COLUMN geom geometry(Point, 9377);


CREATE INDEX t_cr_unidadconstruccion_gist_geom
ON prod.t_cr_unidadconstruccion
USING GIST(geom);

update prod.t_cr_unidadconstruccion
set geom=ST_PointOnSurface(shape);


REINDEX INDEX t_cr_unidadconstruccion_gist_geom;
REINDEX INDEX  t_cr_terreno_shape_gist;



update prod.t_cr_unidadconstruccion
set observaciones='FixCode'
where codigo is null;

create table prod.t_cr_unidadconstruccion_codigo as 
select u.globalid, u.codigo, t.codigo codigo_terreno
from prod.t_cr_unidadconstruccion u
left join prod.t_cr_terreno  t
on ST_Intersects(u.geom,t.shape)
where u.codigo is null

drop table prod.t_cr_unidadconstruccion_codigo_uni;

create table prod.t_cr_unidadconstruccion_codigo_uni as
select  distinct on (globalid)
globalid,
codigo_terreno
from (
select distinct  globalid,codigo_terreno
from prod.t_cr_unidadconstruccion_codigo
)t
order  by globalid desc


delete
from prod.t_cr_unidadconstruccion_codigo_uni
where trim(codigo_terreno)=''

select *
from prod.t_cr_unidadconstruccion_codigo_uni
where codigo_terreno is not  null



select *
from prod.t_cr_unidadconstruccion
where globalid='{FFFE2AD4-47E1-4B09-A615-E90BA0913480}';


update prod.t_cr_unidadconstruccion
set codigo=t.codigo_terreno
from prod.t_cr_unidadconstruccion_codigo_uni t
where t.globalid =t_cr_unidadconstruccion.globalid;

