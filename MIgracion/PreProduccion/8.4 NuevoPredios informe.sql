

/****
 * Crea tabla de archivo con id operacion
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_reporte;


create table colsmart_prod_insumos.z_f_foliosmatricula_reporte  as
select pr.objectid, pr.id_operacion, f.*
from colsmart_prod_insumos.z_f5_foliosmatricula f
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
	
	