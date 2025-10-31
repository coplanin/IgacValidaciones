select marca_tipo,split_part(detalle,';',1) as
Tabla,split_part(detalle,';',3),count(*) as Cantidad
from colsmart_preprod_migra.ilc_marcas
where marca_tipo='Geografica'
group by marca_tipo,split_part(detalle,';',1),split_part(detalle,';',3);


select id_operacion_predio,count(*)
from colsmart_preprod_migra.ilc_marcas
group by id_operacion_predio
order by count desc;


select id_operacion_predio,marca_tipo,split_part(detalle,';',1) as
Tabla,split_part(detalle,';',3),count(*) as Cantidad
from colsmart_preprod_migra.ilc_marcas
where marca_tipo='Geografica' and id_operacion_predio is not null 
group by id_operacion_predio,marca_tipo,split_part(detalle,';',1),split_part(detalle,';',3)
order by count(*) desc;


create table colsmart_prod_insumos.z_marcas_adicionales as
select mpio,"numero predial",'predios sin folio'::text detalle,"predios sin folio"::text cantidad
from colsmart_prod_insumos.z_f_marcas
where "predios sin folio"::int>0
union
select mpio,"numero predial",'libro antiguo'::text detalle,"libro antiguo"::text 
from colsmart_prod_insumos.z_f_marcas
where "libro antiguo"::int>0
union 
select mpio,"numero predial",'error en formato'::text detalle,"error en formato"::text
from colsmart_prod_insumos.z_f_marcas
where "error en formato"::int>0
union 
select mpio,"numero predial",'circulo registral diferente'::text detalle, "circulo registral diferente"::text
from colsmart_prod_insumos.z_f_marcas
where "circulo registral diferente"::int>0
union 
select mpio,"numero predial",'predios con folio duplicado'::text detalle,"predios con folio duplicado"::text
from colsmart_prod_insumos.z_f_marcas
where "predios con folio duplicado"::int>0
union 
select mpio,"numero predial",'identificado en snr'::text detalle,"identificado en snr"::text
from colsmart_prod_insumos.z_f_marcas
where "identificado en snr"::text!='0'
union 
select mpio,"numero predial",'total de informalidad vigente'::text detalle,"total de informalidad vigente"::text
from colsmart_prod_insumos.z_f_marcas
where "total de informalidad vigente"::int>0;


drop table colsmart_prod_insumos.z_marcas_adicionales;

CREATE TABLE colsmart_prod_insumos.z_marcas_adicionales as
SELECT mpio,
      numero_predial AS numero_predial,
       'Juridica_Predios_Sin_Folio'::text AS detalle,
       predios_sin_folio::text AS cantidad
FROM colsmart_prod_insumos.z_f_marcas
WHERE predios_sin_folio::int > 0
UNION
SELECT mpio,
      numero_predial,
       'Juridica_Libro_Antiguo',
       libro_antiguo::text
FROM colsmart_prod_insumos.z_f_marcas
WHERE libro_antiguo::int > 0
UNION
SELECT mpio,
      numero_predial,
       'Juridica_Error_En_Formato',
       error_en_formato::text
FROM colsmart_prod_insumos.z_f_marcas
WHERE error_en_formato::int > 0
UNION
SELECT mpio,
      numero_predial,
       'Juridica_Circulo_Registral_Diferente',
       circulo_registral_diferente::text
FROM colsmart_prod_insumos.z_f_marcas
WHERE circulo_registral_diferente::int > 0
UNION
SELECT mpio,
      numero_predial,
       'Juridica_Predios_Con_Folio_Duplicado',
       predios_con_folio_duplicado::text
FROM colsmart_prod_insumos.z_f_marcas
WHERE predios_con_folio_duplicado::int > 0
UNION
SELECT mpio,
      numero_predial,
       'Juridica_Identificado_En_Snr',
       identificado_en_snr::text
FROM colsmart_prod_insumos.z_f_marcas
WHERE identificado_en_snr::text <> '0'
UNION
SELECT mpio,
      numero_predial,
       'Juridica_Total_De_Informalidad_Vigente',
       total_de_informalidad_vigente::text
FROM colsmart_prod_insumos.z_f_marcas
WHERE total_de_informalidad_vigente::int > 0;



select *
from colsmart_prod_insumos.z_marcas_adicionales;


delete 
from colsmart_preprod_migra.ilc_marcas;
--where marca_tipo='Geografica'


INSERT INTO colsmart_preprod_migra.ilc_marcas
(objectid, id_operacion_predio, marca_tipo, fecha_ejecucion, marca_estado, detalle, 
globalid, predio_guid,  shape)
with marcas_geo as (
	select distinct coalesce(p.id_operacion,t.codigo) id_operacion_predio,
	detalle marca_tipo,
	'Terreno'||
	';'||t.detalle as detalle ,
	p.globalid predio_guid,
	ST_PointOnSurface(t.shape) shape
	from z_v_terrenos t 
	left join colsmart_preprod_migra.ilc_predio p
	on t.codigo =p.numero_predial_nacional
	where t.codigo is not null and t.codigo!='' and t.codigo!=' '
)
select 
sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas') objectid,
id_operacion_predio,
marca_tipo,
null as fecha_ejecucion,
'Abierta'::text as´marca_estado,
detalle,
sde.next_globalid() globalid,
predio_guid,
shape
from marcas_geo;


INSERT INTO colsmart_preprod_migra.ilc_marcas
(objectid, id_operacion_predio, marca_tipo, fecha_ejecucion, marca_estado, detalle, 
globalid, predio_guid,  shape)
with marcas_geo as (
	select distinct coalesce(p.id_operacion,t.codigo) id_operacion_predio,
	detalle marca_tipo,
	'Unidad'||
	';'||t.detalle as detalle,
	p.globalid predio_guid,
	ST_PointOnSurface(t.shape) shape
	from z_v_unidad t 
	left join colsmart_preprod_migra.ilc_predio p
	on t.codigo =p.numero_predial_nacional
	where t.codigo is not null and t.codigo!='' and t.codigo!=' '
)
select 
sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas') objectid,
id_operacion_predio,
marca_tipo,
null as fecha_ejecucion,
'Abierta'::text as´marca_estado,
detalle,
sde.next_globalid() globalid,
predio_guid,
shape
from marcas_geo;





INSERT INTO colsmart_preprod_migra.ilc_marcas
(objectid, id_operacion_predio, marca_tipo, fecha_ejecucion, marca_estado, detalle, 
globalid, predio_guid,  shape)
with marcas_geo as (
	select 
	coalesce(p.id_operacion,a.numero_predial::text) as id_operacion_predio,
	detalle marca_tipo,
	null as fecha_ejecucion,
	'Abierta'::text as marca_estado,
	'Predio;'||detalle||'; Cant: '||cantidad as detalle,
	sde.next_globalid() globalid,
	p.globalid as  predio_guid,
	ST_PointOnSurface(p.shape) shape
	from colsmart_prod_insumos.z_marcas_adicionales a
	left join colsmart_preprod_migra.ilc_predio p
	on a.numero_predial::text=p.numero_predial_nacional::text
)
select 
sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas') objectid,
id_operacion_predio,
marca_tipo,
null as fecha_ejecucion,
marca_estado,
detalle,
sde.next_globalid() globalid,
predio_guid,
shape
from marcas_geo;


INSERT INTO colsmart_preprod_migra.ilc_marcas
(objectid, id_operacion_predio, marca_tipo, fecha_ejecucion, marca_estado, detalle, 
globalid, predio_guid,  shape)
select sde.next_rowid('colsmart_preprod_migra', 'ilc_marcas') objectid,
id_operacion,marca_tipo,null fecha_ejecucion, 'Abierta'::text as marca_estado,marca_tipo detalle,
sde.next_globalid() globalid,globalid_predio,shape
from (
select distinct(pr.globalid), pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.1. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_derivado JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_consultado = 'ACTIVO' AND estado_snc_folio_consultado = 'ACTIVO'
AND estado_snr_folio_2_nivel = 'ACTIVO' AND estado_snc_folio_2_nivel IS NULL
union all
select distinct(pr.globalid), pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.2. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_derivado JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_consultado = 'ACTIVO' AND estado_snc_folio_consultado = 'ACTIVO'
AND estado_snr_folio_2_nivel = 'ACTIVO' AND estado_snc_folio_2_nivel = 'CANCELADO'
union all 
select distinct(pr.globalid), pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.3. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_derivado JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_consultado = 'ACTIVO' AND estado_snc_folio_consultado = 'CANCELADO'
AND estado_snr_folio_2_nivel = 'ACTIVO' AND estado_snc_folio_2_nivel = 'ACTIVO' 
union all 
select distinct(pr.globalid), pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.4. Folios no cruzados en catastro con posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Folios_No_Cruzados_En_Catastro' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_derivado JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_consultado = 'ACTIVO' AND estado_snc_folio_consultado IS NULL 
AND estado_snr_folio_2_nivel = 'ACTIVO' AND estado_snc_folio_2_nivel IS NULL
union all 
select pr.globalid, pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.5. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo ,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_matriz JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_matriz_2_nivel = 'ACTIVO' AND estado_snc_folio_matriz_2_nivel = 'ACTIVO'
AND estado_snr_folio_consultado = 'ACTIVO' AND estado_snc_folio_consultado IS NULL
union all 
select pr.globalid, pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.6. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_matriz JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_matriz_2_nivel = 'ACTIVO' AND estado_snc_folio_matriz_2_nivel = 'ACTIVO'
AND estado_snr_folio_consultado = 'ACTIVO' AND estado_snc_folio_consultado ='CANCELADO'
union all 
select pr.globalid, pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.7. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_matriz
JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_matriz_2_nivel = 'ACTIVO' AND estado_snc_folio_matriz_2_nivel = 'CANCELADO'
and (pr.codigo_orip||'-'||pr.matricula_inmobiliaria) =  folio_matriz_1_nivel
union all 
select  pr.globalid, pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.8. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_matriz JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_matriz_2_nivel = 'ACTIVO' AND estado_snc_folio_matriz_2_nivel IS NULL
and (pr.codigo_orip||'-'||pr.matricula_inmobiliaria) =  folio_matriz_1_nivel
union all 
select pr.globalid, pr.id_operacion::varchar as id_operacion, pr.globalid as globalid_predio, 'SICRE.9. Posible mutación de terreno' || num_folio_snr_consultado as etiqueta, pr.codigo_orip orig_fid, 'Juridica_Sicre_Posible_Mutacion_De_Terreno' as marca_tipo,pr.shape
from colsmart_prod_insumos.sicre_rep_marca_matriz
JOIN colsmart_preprod_migra.ilc_predio pr ON num_folio_snr_consultado=(pr.codigo_orip||'-'||pr.matricula_inmobiliaria)
where estado_snr_folio_matriz_2_nivel = 'ACTIVO' AND estado_snc_folio_matriz_2_nivel IS null
) t;

select marca_tipo, count(*)
from colsmart_preprod_migra.ilc_marcas
group by  marca_tipo;

select id_operacion_predio,count(*)
from colsmart_preprod_migra.ilc_marcas
group by id_operacion_predio
order by count(*) desc; 

select *
from colsmart_preprod_migra.ilc_marcas
where id_operacion_predio='1774152';

group by marca_tipo;


select *-- shape
from colsmart_preprod_migra.cr_unidadconstruccion cu 
where id_operacion_predio='1774152'


create table colsmart_prod_insumos.ilc_marcas_bkp as
select *
from colsmart_preprod_migra.ilc_marcas im;

delete 
from colsmart_preprod_migra.ilc_marcas im
where marca_tipo in (
'Geografica_Terreno_Npm_Longitud_Menor_A_30',
'Geografica_Terreno_Sin_Predio',
'Geografica_Unidad_Geometria_No_Valida',
'Geografica_Unidad_Sin_Predio',
'Juridica_Circulo_Registral_Diferente',
'Juridica_Error_En_Formato',
'Juridica_Identificado_En_Snr',
'Juridica_Libro_Antiguo');

select marca_tipo,count(*),((count(*)::numeric(20,2)/334411::numeric(20,2))*100)::numeric(20,2) porcentaje
from colsmart_preprod_migra.ilc_marcas im
group by marca_tipo;

select count(*)
from (
select id_operacion_predio 
from colsmart_preprod_migra.ilc_marcas im
group by id_operacion_predio
) t


select count(*)
from colsmart_preprod_migra.ilc_marcas im;
--group by marca_tipo;


-- 1️⃣  Marca qué filas son duplicadas
WITH duplicados AS (
    SELECT
        objectid,
        ROW_NUMBER() OVER (
            PARTITION BY marca_tipo, id_operacion_predio
            ORDER BY objectid          -- ⇦ aquí decides cuál “sobrevive”
        ) AS rn
    FROM colsmart_preprod_migra.ilc_marcas
)
DELETE FROM colsmart_preprod_migra.ilc_marcas m
USING duplicados d
WHERE m.objectid = d.objectid
  AND d.rn > 1;          -- solo las filas 2, 3, 4… del grupo









select  count(*)
from colsmart_preprod_migra.ilc_marcas
where shape is null;

update  colsmart_preprod_migra.ilc_marcas
set shape=p.shape
from colsmart_preprod_migra.ilc_predio p
where p.id_operacion=ilc_marcas.id_operacion_predio
and ilc_marcas.shape is null;


 


select id_operacion_predio 
from colsmart_preprod_migra.ilc_marcas
where marca_tipo='Depuracion'
group by id_operacion_predio;

/***
 * Ajuste juridico
 */

select *
from colsmart_preprod_migra.ilc_marcas
where marca_tipo='Juridica'
and detalle like '%ruzado%';

update colsmart_preprod_migra.ilc_marcas
set marca_tipo='Juridica_Sicre_Folios_No_Cruzados_En_Catastro'
where marca_tipo='Juridica'
and detalle like '%ruzado%';

update colsmart_preprod_migra.ilc_marcas
set marca_tipo='Juridica_Sicre_Posible_Mutacion_De_Terreno'
where marca_tipo='Juridica'
and detalle like '%mutación %';




 




