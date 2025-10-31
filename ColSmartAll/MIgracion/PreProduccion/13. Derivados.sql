--create table colsmart_prod_insumos.z_d_derivados as
with mutacion_terreno as (
	select p.*
	from colsmart_preprod_migra.ilc_predio p, colsmart_preprod_migra.ilc_marcas m
	where detalle='Juridica_Sicre_Posible_Mutacion_De_Terreno'
	and p.id_operacion =m.id_operacion_predio
), rep as (
	select m.id_operacion,d.num_folio_snr_consultado,count(*) cant_derivados
	from colsmart_prod_insumos.sicre_rep_marca_derivado d
	inner join 	mutacion_terreno m
	on d.num_folio_snr_consultado =m.codigo_orip||'-'||m.matricula_inmobiliaria
	group by m.id_operacion,d.num_folio_snr_consultado
)
select distinct
m.id_operacion,
m.codigo_orip,
m.matricula_inmobiliaria,
m.area_catastral_terreno,
m.numero_predial_nacional,
m.tipo,
m.condicion_predio,
m.destinacion_economica,
m.area_registral_m2,
m.tipo_referencia_fmi_antiguo,
m.coeficiente,
m.area_coeficiente,
r.cant_derivados,
m.shape
from mutacion_terreno m
left join rep r
on r.num_folio_snr_consultado =m.codigo_orip||'-'||m.matricula_inmobiliaria
where m.codigo_orip='040' and m.matricula_inmobiliaria='62887'