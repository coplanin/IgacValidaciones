/********
	Cantidad de destinos calculados
	cantidad de Edades asignadadas
	Cantidad de Tipologías homologadas
	Cantidad de propietarios actualizados en nombre y sexo
	Cantidad de predios cascarones realizados
***********/

select *--dominio
from colsmart_prod_insumos.z_f_tabla_homologacion
where modelo_o_fuente ='INTERNO'
and dominio='DESTINACION_ECONOMICA';
group by dominio;


select count(*) 
from (
select destinacion_economica 
FROM colsmart_preprod_migra.ilc_predio
where left(numero_predial_nacional,2)= '15'
and  destinacion_economica is null
) t;



select count(*)
from (
select p.destino,h.valor
from colsmart_prod_base_owner.main_predio p
left join (
select *--dominio
from colsmart_prod_insumos.z_f_tabla_homologacion
where modelo_o_fuente ='INTERNO'
and dominio='DESTINACION_ECONOMICA'
) h
on p.destino=h.valor_homologado_snc
where p.departamento_codigo::text = '15'
and h.valor is null
) t;


select sum(suma)
from (
select t.anio_construccion,count(*) suma
from ( 
select c.*
from colsmart_prod_base_owner.main_predio p
left join colsmart_prod_base_owner.main_predio_unidad_construccion c
on p.predio_id=c.predio_id
and anio_construccion>=1960 
where p.departamento_codigo::text = '15'
) t
where t.anio_construccion is  null
group by anio_construccion
) t;

select count(*) 
from (
select c.anio_construccion 
FROM colsmart_preprod_migra.ilc_predio p
left join   colsmart_preprod_migra.cr_unidadconstruccion c
on p.globalid=c.predio_guid 
where left(p.numero_predial_nacional,2)= '15'
and  c.anio_construccion is not null
) t;

select count(*) 
from (
select c.anio_construccion 
FROM colsmart_preprod_migra.ilc_predio p
left join   colsmart_preprod_migra.cr_unidadconstruccion c
on p.globalid=c.predio_guid 
where left(p.numero_predial_nacional,2)= '15'
and  c.shape is not null
) t;


select count(*)
from (
select  coalesce(c.tipo_tipologia,c.tipo_anexo)
FROM colsmart_preprod_migra.ilc_predio p
left join   colsmart_preprod_migra.cr_unidadconstruccion u
on p.globalid=u.predio_guid 
left join   colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion c
on u.globalid=c.unidadconstruccion_guid
where left(p.numero_predial_nacional,2)= '15'
and c.observaciones not IN ('Dummy')
) t




select count(*) 
from (
select i.* 
FROM colsmart_preprod_migra.ilc_predio p
join   colsmart_preprod_migra.ilc_derecho d
on p.globalid=d.predio_guid 
left join   colsmart_preprod_migra.ilc_interesado i
on d.globalid=i.derecho_guid 
where left(p.numero_predial_nacional,2)= '15'
) t;
455.836

select count(*) 
from (
select i.* 
FROM colsmart_preprod_migra.ilc_predio p
join   colsmart_preprod_migra.ilc_derecho d
on p.globalid=d.predio_guid 
 join   colsmart_preprod_migra.ilc_interesado i
on d.globalid=i.derecho_guid 
 join   colsmart_prod_insumos.z_g_homologacion_nombres_sexo n
on i.objectid=n.objectid 
where left(p.numero_predial_nacional,2)= '15'
) t;
302606


select count(*) 
from (
select p.* 
FROM colsmart_preprod_migra.ilc_predio p
join   colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral d 
on p.globalid=d.predio_guid 
where left(p.numero_predial_nacional,2)= '15'
) t;


/** 
 * Resultados boyaca
 */
Numero de predio 216.138
Predio sin destiniacion desde snc 6951
Predio enriquesidos por Corin 6495 faltantes 456 Urbanos
Construcciones con año de construccion 2142 de 214051
Construcciones año de construccion enriqeusida  2142 de 214051
Contrucciones con año de construccion enriqesidas 182092  de 214051
Construcciones con geometria homologada 182151  de 214051 
Caratetisticas homologadas en tipologia  122148  de 214051
Interesados se corrigieron y validaron con resgistraduria 302606 de 455.836
Se han creado de predio nuevos provenientes de analisis jurico 6.549





