	
drop table  colsmart_prod_insumos.z_f_foliosmatricula_3;


create table colsmart_prod_insumos.z_f_foliosmatricula_3 AS
select id,
folio_matriz,novedadfmi_tipo,npnmatriz, 
novedad_numero_predial,
folio_derivados,
"predio tipo",
"condicion prop derivado",
"área registral m2" as árearegistralm2,
coeficiente,
"área coefieciente",
count(*) 
from colsmart_prod_insumos.z_f6_foliosmatricula f
where  COALESCE(novedadfmi_tipo,'')||COALESCE(novedad_numero_predial,'')!=''
group by id,
folio_matriz,novedadfmi_tipo,npnmatriz, 
novedad_numero_predial,
folio_derivados,
"predio tipo",
"condicion prop derivado",
"área registral m2",
coeficiente,
"área coefieciente";

select *
from colsmart_prod_insumos.z_f_foliosmatricula_3
where count>1;

select novedad_numero_predial,count(*)
from colsmart_prod_insumos.z_f_foliosmatricula_3 f
group by novedad_numero_predial



/****
 * Crea la engloble
 *
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_valida;


create table colsmart_prod_insumos.z_f_foliosmatricula_valida  as
select *
from colsmart_prod_insumos.z_f_foliosmatricula_3 f;

--89


select *
from colsmart_prod_insumos.z_f_foliosmatricula_engloble;


/****
 * Revisa si los predios existen ya creados
 *
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_valida_exists;


create table colsmart_prod_insumos.z_f_foliosmatricula_valida_exists  as
select *
from colsmart_prod_insumos.z_f_foliosmatricula_valida f
where  exists (
	select 1
	from colsmart_preprod_migra.ilc_predio pr
	where  coalesce(f.folio_derivados,f.folio_matriz)=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
	
);


select *
from  colsmart_prod_insumos.z_f_foliosmatricula_valida_exists 

/****
 * Revisa si los predios no existen
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_valida_notexists;


create table colsmart_prod_insumos.z_f_foliosmatricula_valida_notexists  as
select *
from colsmart_prod_insumos.z_f_foliosmatricula_valida f
where  not exists (
	select 1
	from colsmart_preprod_migra.ilc_predio pr
	where  coalesce(f.folio_derivados,f.folio_matriz)=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
	
);

select count(*)
from  colsmart_prod_insumos.z_f_foliosmatricula_engloble_notexists 


