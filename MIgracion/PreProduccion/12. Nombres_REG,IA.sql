/**
 * Actualizacion de Geomtrias tipo punto apartir de capa generada por Juan
 */
select nombre_completo,reg_nombre_completo,lev_dist_nombre_apellido-- count(*)
from colsmart_prod_insumos.z_g_homologacion_nombres
where reg_nombre_completo!='' and nombre_completo!='';
--372708

select (15000::numeric(20,2)/372708::numeric(20,2))::numeric(20,2)


select count(*)
--nombre_completo,reg_nombre_completo,lev_dist_nombre_apellido
from colsmart_prod_insumos.z_g_homologacion_nombres
where  lev_dist_nombre_apellido>2 and
reg_nombre_completo!='' and nombre_completo!='';
--and pk_interesado ='223397';
--326431 /0
--17338 /1
--3599 /2
--25340 >3
--359467



select pk_interesado, nombre_completo,reg_nombre_completo--,lev_dist_nombre_apellido --count(*)--nombre_completo,reg_nombre_completo,lev_dist_nombre_apellido
from colsmart_prod_insumos.z_g_homologacion_nombres
where  lev_dist_nombre_apellido>2
and reg_nombre_completo!='' and nombre_completo!='';


with update_ia as (


select pk_interesado,n.nombre_completo,n.reg_nombre_completo,n.lev_dist_nombre_apellido,
replace(i."similarity_%",',','.')::numeric(50,5) similarity
from colsmart_prod_insumos.z_g_homologacion_nombres n
inner join  colsmart_prod_insumos.z_g_homologacion_nombres_ia2   i
on n.pk_interesado::text =i."PK"::text
where replace(i."similarity_%",',','.')::numeric(50,5)>70 and 
n.reg_nombre_completo!='' and n.nombre_completo!=''


)
update colsmart_prod_insumos.z_g_homologacion_nombres
set similaridad=u.similarity
from update_ia u
where u.pk_interesado=z_g_homologacion_nombres.pk_interesado;


drop table colsmart_prod_insumos.z_g_homologacion_nombres_sexo;

create table colsmart_prod_insumos.z_g_homologacion_nombres_sexo as
with update_name as (
	select *
	from colsmart_prod_insumos.z_g_homologacion_nombres
	where (similaridad>70 or lev_dist_nombre_apellido<3) 
	and reg_nombre_completo!='' and nombre_completo!=''
)
select i.objectid,i.primer_apellido,u.reg_firstlastname_clean,
i.segundo_apellido,u.reg_secondlastname_clean,
i.primer_nombre,u.reg_firstname_clean,
i.segundo_nombre,u.reg_secondname_clean,
i.sexo,initcap(u.colsmart_gender) sexo_fix
from update_name u
inner join colsmart_preprod_migra.ilc_interesado i
on u.documento_identidad::text=i.documento_identidad::text;
--where u.similaridad=60;
--357367

select *
from z_g_homologacion_nombres_sexo;

create table colsmart_prod_insumos.ilc_interesado_bkp as
select *
from colsmart_preprod_migra.ilc_interesado;


update colsmart_preprod_migra.ilc_interesado
set primer_apellido=h.reg_firstlastname_clean,
segundo_apellido=h.reg_secondlastname_clean,
primer_nombre=h.reg_firstname_clean,
segundo_nombre=h.reg_secondname_clean,
sexo=h.sexo_fix
from colsmart_prod_insumos.z_g_homologacion_nombres_sexo h
where h.objectid=colsmart_preprod_migra.ilc_interesado.objectid;

select count(*)
from colsmart_preprod_migra.ilc_interesado
where tipo='Persona_Natural';
--682518 /620000


select *
from anexos_homologacion_propuesta ahp 
where 

select (620000::numeric(20,2)/682518::numeric(20,2))::numeric(20,2);

--91% Pesona natural


