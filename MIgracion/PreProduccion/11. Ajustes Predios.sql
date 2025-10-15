/**
 * Actualizacion de Geomtrias tipo punto apartir de capa generada por Juan
 */

with geometrias as (
	select p.objectid,c.shape
	from colsmart_preprod_migra.ilc_predio p
	left join  colsmart_prod_base_owner.colsmart_terrenos_generados c
	on p.numero_predial_nacional =c.numero_predial
)
update colsmart_preprod_migra.ilc_predio
set shape=ST_PointOnSurface(g.shape)
from geometrias g
where g.objectid=ilc_predio.objectid;

/**
 * Actualizacion matricula inmobiliaria
 */

with predio as (
	select objectid, CASE
	    WHEN matricula_inmobiliaria LIKE '%-%'          -- contiene guion
	    THEN split_part(matricula_inmobiliaria, '-', 2) -- parte posterior
	    ELSE matricula_inmobiliaria                     -- sigue igual
	END AS matricula_inmobiliaria
	from colsmart_preprod_migra.ilc_predio
) 
update colsmart_preprod_migra.ilc_predio
set matricula_inmobiliaria=g.matricula_inmobiliaria
from predio g
where g.objectid=ilc_predio.objectid;

/**
 * Actualizacion matricula inmobiliaria y 
 */
with unidades as (
	select u.* 
	from colsmart_preprod_migra.cr_unidadconstruccion u
	left join colsmart_preprod_migra.ilc_predio p
	on p.numero_predial_nacional=u.codigo
	where p.numero_predial_nacional is null
)
select count(*)
from unidades;


select count(*)
from colsmart_preprod_migra.cr_unidadconstruccion u
where predio_guid is null;


select observaciones,count(*)
from colsmart_preprod_migra.cr_unidadconstruccion u
where observaciones in ('Caso 11','Caso 12')
and predio_guid is null
group by observaciones;
--289052



,cantidad as (
	select u.codigo unidad_npm,t.codigo as terreno_npm
	from unidades u,colsmart_preprod_migra.cr_terreno t 
	where ST_Intersects(st_pointonsurface(u.shape),t.shape)
	and u.codigo=t.codigo
)
select count(*) --distinct u.*-- count(*) --169705
from cantidad u
left join colsmart_preprod_migra.ilc_predio p
on p.numero_predial_nacional=u.terreno_npm
--where left(u.terreno_npm,5)='15599';


select *
from colsmart_preprod_migra.cr_unidadconstruccion  p
where left(p.codigo,5)='15599' 
and predio_guid is null;


with terreno as (
	select u.* 
	from colsmart_preprod_migra.cr_terreno u
	left join colsmart_preprod_migra.ilc_predio p
	on p.numero_predial_nacional=u.codigo
	where p.numero_predial_nacional  is null
)
select u.*-- count(*) --169705
from terreno u
where left(u.codigo,5)='15599'




select count(*)
from (
select distinct p.*
from colsmart_preprod_migra.ilc_predio p
inner join colsmart_preprod_migra.ilc_derecho d
on d.predio_guid =p.globalid
inner join colsmart_preprod_migra.ilc_interesado i
on i.derecho_guid =d.globalid
) t




select count(*)
from (
select distinct d.*
from colsmart_preprod_migra.ilc_derecho d
inner join colsmart_preprod_migra.ilc_fuenteadministrativa f
on f.derecho_guid =d.globalid
) t

select count(*)
from colsmart_preprod_migra.ilc_fuenteadministrativa 

select count(*)
from (
select distinct u.*
from  colsmart_preprod_migra.cr_unidadconstruccion u
inner join colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion d
on u.caracteristicasuc_guid =d.globalid
where u.shape is not null and u.predio_guid is not null
) t

select count(*)
from (
select distinct u.*
from  colsmart_preprod_migra.cr_unidadconstruccion u
where u.shape is not null and u.predio_guid is not null 
and  u.caracteristicasuc_guid is  null
) t


select count(*)
from (
select distinct u.*
from  colsmart_preprod_migra.cr_unidadconstruccion u
where u.shape is not null and u.predio_guid is  null 
and  u.caracteristicasuc_guid is  null
) t


select *
from  colsmart_preprod_migra.cr_unidadconstruccion
where observaciones ='Caso 12'


select  predio_guid,count(*)
from  colsmart_preprod_migra.cr_unidadconstruccion u
group by predio_guid
having count(*)>3
order by count(*) desc


where u.shape is not null and (u.predio_guid is  null or u.predio_guid 

select count(*)
from (
select distinct p.*
from colsmart_preprod_migra.ilc_predio p
inner join colsmart_preprod_migra.cr_unidadconstruccion u
on u.predio_guid =p.globalid
) t

select count(*)
from (
select distinct u.predio_guid
from colsmart_preprod_migra.cr_unidadconstruccion u
where u.predio_guid is not null 
and u.predio_guid::text  not  like '%0000%'
)t;


select id_caracteristicasunidadconstru::text 
from colsmart_prod_insumos.z_u_r_unidad_data
except
select id_caracteristicasunidadconstru::text
from colsmart_preprod_migra.cr_unidadconstruccion u


select count(*) 
from colsmart_prod_insumos.z_u_r_unidad_data


select count(*)
from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion ic
where tipo_tipologia is not null
and tipo_unidad_construccion='Anexo';


update colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_caracteristicasunidadconstruccion')



update colsmart_preprod_migra.cr_unidadconstruccion
set objectid=sde.next_rowid('colsmart_preprod_migra', 'cr_unidadconstruccion')



update colsmart_preprod_migra.cr_terreno 
set objectid=sde.next_rowid('colsmart_preprod_migra', 'cr_terreno')


update colsmart_preprod_migra.ilc_predio  
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_predio')


update colsmart_preprod_migra.ilc_derecho   
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_derecho');


update colsmart_preprod_migra.ilc_interesado    
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_interesado');



update colsmart_preprod_migra.ilc_fuenteadministrativa  
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_fuenteadministrativa');



update colsmart_preprod_migra.cr_fuenteespacial  
set objectid=sde.next_rowid('colsmart_preprod_migra', 'cr_fuenteespacial');


update colsmart_preprod_migra.ilc_estructuraavaluo  
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_estructuraavaluo');


update colsmart_preprod_migra.ilc_estructuraavaluo  
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_estructuraavaluo');



update colsmart_preprod_migra.ilc_estructuraavaluo  
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_estructuraavaluo');


delete 
from colsmart_preprod_migra.ilc_estructuraavaluo;


create table colsmart_preprod_migra.ilc_estructuraavaluo_old as


INSERT INTO colsmart_preprod_migra.ilc_estructuraavaluo
(objectid, globalid, autoestimacion, avaluo_catastral, avaluo_catastral_terreno, 
avaluo_catastral_total_unidades, fecha_avaluo_catastral, id_operacion_predio, predio_guid, 
valor_comercial, valor_comercial_terreno, valor_comercial_total_unidadesc)
select sde.next_rowid('colsmart_preprod_migra', 'ilc_estructuraavaluo') objectid,
sde.next_globalid() globalid,
autoestimacion,
avaluo_catastral,
avaluo_catastral_terreno,
avaluo_catastral_total_unidades,
fecha_avaluo_catastral,
id_operacion_predio,
predio_guid,
valor_comercial,
valor_comercial_terreno,
valor_comercial_total_unidadesc
from colsmart_preprod_migra.ilc_estructuraavaluo_old  

update colsmart_preprod_migra.ilc_predio 
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_predio');




update colsmart_preprod_migra.ilc_predio_informalidad
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_predio_informalidad');


update colsmart_preprod_migra.ilc_tramitesderechosterritoriales   
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_tramitesderechosterritoriales');



update colsmart_preprod_migra.extdireccion   
set objectid=sde.next_rowid('colsmart_preprod_migra', 'extdireccion');



delete
from colsmart_preprod_migra.extdireccion;


INSERT INTO colsmart_preprod_migra.extdireccion
(objectid, globalid, clase_via_principal, codigo_postal, complemento, es_direccion_principal, 
id_operacion_predio, letra_via_generadora, letra_via_principal, localizacion, nombre_predio, 
numero_predio, predio_guid, sector_ciudad, sector_predio, tipo_direccion, valor_via_generadora, valor_via_principal)
select sde.next_rowid('colsmart_preprod_migra', 'ilc_interesado') objectid,
sde.next_globalid() globalid,
clase_via_principal,
codigo_postal,
null as complemento,
es_direccion_principal,
id_operacion_predio,
letra_via_generadora,
letra_via_principal,
localizacion,
complemento as nombre_predio,
numero_predio,
predio_guid,
sector_ciudad,
sector_predio,
tipo_direccion,
valor_via_generadora,
valor_via_principal
from colsmart_preprod_migra.extdireccion_old;

create table colsmart_preprod_migra.extdireccion_old as	
select *
from colsmart_preprod_migra.extdireccion ;


update colsmart_preprod_migra.ilc_marcas 
set objectid=sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas');


create table colsmart_prod_insumos.z_f_anexos_homologacion as
select *
from colsmart_preprod_migra.anexos_homologacion_propuesta ahp;



create table colsmart_prod_insumos.z_f_marcas as
select *
from colsmart_preprod_migra.marcas_julio


update colsmart_preprod_migra.ilc_fuenteadministrativa
set ia='No';


select distinct autorreco_campesino
from colsmart_preprod_migra.ilc_interesado;

update colsmart_preprod_migra.ilc_interesado
set autorreco_campesino='No';


select documento_identidad,tipo_documento 
from colsmart_preprod_migra.ilc_interesado
where tipo_documento in ('Libreta Militar','Otro')


-- Si es 'Libreta Militar','Secuencial' se debe colocar un secuencial
WITH numerados AS (
    SELECT
        objectid,
        row_number() OVER (ORDER BY objectid) AS nuevo_doc
    FROM colsmart_preprod_migra.ilc_interesado
    WHERE tipo_documento IN ('Libreta Militar', 'Otro')
)
UPDATE colsmart_preprod_migra.ilc_interesado AS t
SET  documento_identidad = numerados.nuevo_doc::text,   -- o ::integer si la columna es numérica
     tipo_documento      = 'Secuencial'
FROM numerados
WHERE t.objectid = numerados.objectid;

/********
 * 
 * 
 */


select *
from colsmart_prod_base_owner.main_predio mp
where area_terreno is not null;-- and area_terreno>0;
--518075


select distinct tipo-- count(*) 
from colsmart_preprod_migra.ilc_predio
where tipo is not null;





/****
 * Actualiza el area terreno en la tabla de predio
 */

update colsmart_preprod_migra.ilc_predio
set  area_catastral_terreno=m.area_terreno::int
from colsmart_prod_base_owner.main_predio m
where m.predio_id::text =id_operacion::text;


/****
 * Actualiza la codicion de predio
 */

UPDATE colsmart_preprod_migra.ilc_predio p
SET condicion_predio = CASE SUBSTR(LPAD(p.numero_predial_nacional::text, 30, '0'), 22, 1)
  WHEN '0' THEN 'NPH'
  WHEN '9' THEN 'PH_Unidad_Predial'
  WHEN '8' THEN 'Condominio_Unidad_Predial'
  WHEN '7' THEN 'Parque_Cementerios'
  WHEN '4' THEN 'Via'
  WHEN '3' THEN 'Bien_Uso_Publico'
  WHEN '2' THEN 'Informal'
  WHEN '5' THEN 'Mejoras_Terreno_Ajeno_No_PH'  -- o 'Mejoras_Terreno_Ajeno_No_PH' si crean el dominio específico
  ELSE p.condicion_predio  -- conserva el valor actual si no hay mapeo
END
WHERE p.numero_predial_nacional IS NOT NULL
  AND SUBSTR(LPAD(p.numero_predial_nacional::text, 30, '0'), 22, 1) IN ('0','9','8','7','4','3','2','5');




-- Habilita unaccent si no está
CREATE EXTENSION IF NOT EXISTS unaccent;

WITH map(src, dst) AS (
  VALUES
    ('P', 'Privado'),
    ('PARTICULAR', 'Privado'),
    ('PRIVADO', 'Privado'),
    ('G', 'Privado'),
    ('A', 'Privado'),
    ('C', NULL),
    ('I', NULL),
    ('F', NULL),
    (' ', NULL),
    ('T', 'Privado_Colectivo'),
    ('TIERRA DE COMUNIDADES NEGRAS', 'Privado_Colectivo'),
    ('R', 'Reserva_Indigena'),
    ('RESGUARDO INDIGENA', 'Reserva_Indigena'),
    ('RESGUARDO INDÍGENA', 'Reserva_Indigena'),
    ('B', 'Publico_Baldio'),
    ('BALDIO', 'Publico_Baldio'),
    ('BALDÍO', 'Publico_Baldio'),
    ('N', 'Publico_Fiscal_Patrimonial'),
    ('NACIONAL', 'Publico_Fiscal_Patrimonial'),--Pubico_Fiscal_Patrimonial
    ('D', 'Publico_Fiscal_Patrimonial'),
    ('DEPARTAMENTAL', 'Publico_Fiscal_Patrimonial'),
    ('M', 'Publico_Fiscal_Patrimonial'),
    ('MUNICIPAL', 'Publico_Fiscal_Patrimonial'),
    ('E', 'Publico_Uso_Publico'),    -- Ejido
    ('EJIDO', 'Publico_Uso_Publico'),
    ('V', 'Publico_Uso_Publico'),    -- Reservas Naturales
    ('RESERVAS NATURALES', 'Publico_Uso_Publico')
)
SELECT
  p.tipo AS valor_original,
  upper(trim(p.tipo)) AS normalizado,
  m.dst AS dominio_objetivo,
  COUNT(*) AS cantidad
FROM colsmart_preprod_migra.ilc_predio p
LEFT JOIN map m
  ON upper(trim(p.tipo)) = m.src
GROUP BY 1,2,3
ORDER BY 4 DESC, 1;


select tipo,condicion_predio,destinacion_economica,count(*)
FROM colsmart_preprod_migra.ilc_predio p
--where tipo='A'
group by tipo,condicion_predio,destinacion_economica ;


WITH map(src, dst) AS (
  VALUES
  ('P', 'Privado'),
    ('PARTICULAR', 'Privado'),
    ('PRIVADO', 'Privado'),
    ('G', 'Privado'),
    ('A', 'Privado'),
    ('C', NULL),
    ('I', NULL),
    ('F', NULL),
    (' ', NULL),
    ('', NULL),
    ('T', 'Privado_Colectivo'),
    ('TIERRA DE COMUNIDADES NEGRAS', 'Privado_Colectivo'),
    ('R', 'Reserva_Indigena'),
    ('RESGUARDO INDIGENA', 'Reserva_Indigena'),
    ('RESGUARDO INDÍGENA', 'Reserva_Indigena'),
    ('B', 'Publico_Baldio'),
    ('BALDIO', 'Publico_Baldio'),
    ('BALDÍO', 'Publico_Baldio'),
    ('N', 'Publico_Fiscal_Patrimonial'),
    ('NACIONAL', 'Publico_Fiscal_Patrimonial'),--Pubico_Fiscal_Patrimonial
    ('D', 'Publico_Fiscal_Patrimonial'),
    ('DEPARTAMENTAL', 'Publico_Fiscal_Patrimonial'),
    ('M', 'Publico_Fiscal_Patrimonial'),
    ('MUNICIPAL', 'Publico_Fiscal_Patrimonial'),
    ('E', 'Publico_Uso_Publico'),    -- Ejido
    ('EJIDO', 'Publico_Uso_Publico'),
    ('V', 'Publico_Uso_Publico'),    -- Reservas Naturales
    ('RESERVAS NATURALES', 'Publico_Uso_Publico')
)
UPDATE colsmart_preprod_migra.ilc_predio p
SET tipo = m.dst
FROM map m
WHERE upper(trim(p.tipo)) = m.src;




