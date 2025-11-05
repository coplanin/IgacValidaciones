

/****
 * Crea tabla de archivo con id operacion
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_reporte;


create table colsmart_prod_insumos.z_f_foliosmatricula_reporte  as
select pr.objectid, pr.id_operacion, f.*
from colsmart_prod_insumos.z_f8_foliosmatricula f
left join colsmart_preprod_migra.ilc_predio pr
on coalesce(f.folio_derivados,f.folio_matriz)=pr.codigo_orip||'-'||pr.matricula_inmobiliaria


select *
from colsmart_prod_insumos.z_f_foliosmatricula_reporte

create table colsmart_prod_insumos.z_f_foliosmatricula_reporte_idcrear  as
select id_operacion
from  colsmart_prod_insumos.z_f_foliosmatricula_reporte 
where objectid>=1634852;



update colsmart_preprod_migra.ilc_predio
set tipo='Privado'
where tipo='Privado_Privado';


	select id_operacion, pr.coeficiente coefiente_predio,f.coeficiente coefiente_archivo
	from colsmart_preprod_migra.ilc_predio pr
	left join colsmart_prod_insumos.z_f8_foliosmatricula f
	on coalesce(f.folio_derivados,f.folio_matriz)=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
	where pr.coeficiente is not null 	
	and id_operacion like 'L8_%'

with id_coeficiente as (
	select id_operacion, pr.coeficiente coefiente_predio,f.coeficiente coefiente_archivo,
	pr.area_coeficiente as area_coeficiente_predio,f."área coefieciente" area_coeficiente_archivo
	from colsmart_preprod_migra.ilc_predio pr
	 join colsmart_prod_insumos.z_f8_foliosmatricula f
	on 	pr.id_operacion like 'L8_%'
	and replace(pr.id_operacion,'L8_','')::int=f.id
)
update colsmart_preprod_migra.ilc_predio
set coeficiente=trim(replace(i.coefiente_archivo,',','.'))::numeric(50,12),
area_coeficiente=trim(replace(i.area_coeficiente_archivo,',','.'))::numeric(50,12)
from id_coeficiente i
where i.id_operacion=ilc_predio.id_operacion



select f.*,id.objectid 
from  colsmart_prod_insumos.z_f8_foliosmatricula f
left  join colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral id 
	on 	id.observaciones like 'L8_%'
	and replace(id.observaciones,'L8_','')::int=f.id
	where id.objectid  is null



select count(*)
from colsmart_prod_insumos.z_f6_foliosmatricula

select id_operacion
from colsmart_prod_insumos.z_f_foliosmatricula_reporte
except 
select id_operacion_predio 
from colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral



select  id_operacion_predio,count(*)
from colsmart_preprod_migra.ilc_marcas
group  by id_operacion_predio;




	