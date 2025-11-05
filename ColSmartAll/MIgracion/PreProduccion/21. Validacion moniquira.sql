with prod as (
select m.marca_tipo,count(*) cantidad_prod
from colsmart_prod_reader.t_ilc_predio p,
colsmart_prod_reader.t_ilc_marcas m
where left(p.numero_predial_nacional,5)='15469'
and right(left(p.numero_predial_nacional,7),2)='01'
and p.globalid =m.predio_guid 
group by m.marca_tipo
),prep as (
select m.marca_tipo,count(*) cantidad_pre
from colsmart_preprod_migra.ilc_predio p,
colsmart_preprod_migra.ilc_marcas m
where left(p.numero_predial_nacional,5)='15469'
and right(left(p.numero_predial_nacional,7),2)='00'
and p.globalid =m.predio_guid 
group by m.marca_tipo 
)
select d.marca_tipo,coalesce(cantidad_pre,0),cantidad_prod
from prod d
left join prep p
on d.marca_tipo=p.marca_tipo;



select right(left(p.numero_predial_nacional,7),2),count(*)
from colsmart_prod_reader.t_ilc_predio p,
colsmart_prod_reader.t_ilc_marcas m
where left(p.numero_predial_nacional,5)='15469'
--and right(left(p.numero_predial_nacional,7),2)='00'
and p.globalid =m.predio_guid 
group by right(left(p.numero_predial_nacional,7),2)



select count(m.*) 
from colsmart_prod_reader.t_ilc_predio p,
colsmart_prod_reader.t_cr_unidadconstruccion  m
where left(p.numero_predial_nacional,5)='15469'
--and right(left(p.numero_predial_nacional,7),2)='00'
and p.globalid =m.predio_guid--18207



select count(m.*)
from colsmart_preprod_migra.ilc_predio p,
colsmart_preprod_migra.cr_unidadconstruccion  m
where left(p.numero_predial_nacional,5)='15469'
--and right(left(p.numero_predial_nacional,7),2)='00'
and p.globalid =m.predio_guid 
--15226


select count(m.*) 
from colsmart_prod_reader.t_ilc_predio p,
colsmart_prod_reader.t_cr_unidadconstruccion  m
where left(p.numero_predial_nacional,5)='15469'
and right(left(p.numero_predial_nacional,7),2)='00'
and p.globalid =m.predio_guid
and st_area(m.shape)>50
--11.048


select count(m.*)
from colsmart_preprod_migra.ilc_predio p,
colsmart_preprod_migra.cr_unidadconstruccion  m
where left(p.numero_predial_nacional,5)='15469'
and right(left(p.numero_predial_nacional,7),2)='00'
and p.globalid =m.predio_guid 
--6381
--guayata viracacha y moniquira
--Correles las 7 reglas
--calcular las edades de esas constryucciones
--generar marcas construcciones nuevas



select count(m.*) 
from colsmart_prod_reader.t_ilc_predio p,
colsmart_prod_reader.t_cr_unidadconstruccion  m
where left(p.numero_predial_nacional,5)='15469'
and right(left(p.numero_predial_nacional,7),2)='01'
and p.globalid =m.predio_guid--18207
--7159


select count(m.*)
from colsmart_preprod_migra.ilc_predio p,
colsmart_preprod_migra.cr_unidadconstruccion  m
where left(p.numero_predial_nacional,5)='15469'
and right(left(p.numero_predial_nacional,7),2)='01'
and p.globalid =m.predio_guid 
--8845



select *
from colsmart_preprod_migra.cr_unidadconstruccion 
where globalid='{AB2AA3EE-26B0-4B67-9991-1E2E4122E99F}'


group by m.marca_tipo 


