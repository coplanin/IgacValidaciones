
select count(*)
from (
select *
from colsmart_prod_owner.cr_unidadconstruccion_ 
where predio_guid is not null
and  gdb_branch_id='0'
and last_edited_user='juan.gaitan'
and last_edited_date>'2025-10-19'
) t
--224002

select count(*)
from (
select *
from colsmart_prod_owner.cr_unidadconstruccion_ 
where predio_guid is not null
and  gdb_branch_id='0'
and last_edited_user='juan.gaitan'
and last_edited_date>'2025-10-01'
and altura is null
and anio_construccion  is null
and area_construccion is null
and area_privada_construida  is null
and caracteristicasuc_guid  is null
--and predio_guid is null
) t
--133922


select count(*)
from (
select predio_guid
from colsmart_prod_owner.cr_unidadconstruccion_ 
where predio_guid is null
and  gdb_branch_id='0'
and last_edited_user='juan.gaitan'
) t;
--19712

select count(*)
from (
select predio_guid
from colsmart_prod_owner.cr_unidadconstruccion_ 
where predio_guid is not null
and  gdb_branch_id='0'
and last_edited_user='juan.gaitan'
) t
--293732


select *
from (
select predio_guid,st_area(shape),count(*)
from colsmart_prod_owner.cr_unidadconstruccion_ 
where predio_guid is not null
and  gdb_branch_id='0'
and last_edited_user='juan.gaitan'
group by predio_guid,st_area(shape)
having count(*)<2
) t
--163710

WITH u_unidad_ AS (
    SELECT 
        predio_guid,
        ST_Area(shape) AS area,
        COUNT(*) AS num_registros
    FROM colsmart_prod_owner.cr_unidadconstruccion_
    WHERE predio_guid IS NOT NULL
      AND gdb_branch_id = '0'
      AND last_edited_user = 'juan.gaitan'
    GROUP BY predio_guid, ST_Area(shape)
    HAVING COUNT(*) < 2
),
u_unidad AS (
    SELECT 
        predio_guid,
        ST_Area(shape) AS area,
        COUNT(*) AS num_registros
    FROM colsmart_preprod_migra.cr_unidadconstruccion
    WHERE predio_guid IS NOT NULL
    GROUP BY predio_guid, ST_Area(shape)
    HAVING COUNT(*) < 2
)
SELECT 
    p.predio_guid,
    p.area,
    p.num_registros AS registros_prod,
    m.num_registros AS registros_preprod
FROM u_unidad_ p
JOIN u_unidad m
  ON p.predio_guid = m.predio_guid
 AND p.area = m.area;


select  count(*)
from colsmart_preprod_migra.cr_unidadconstruccion m
where exists (
select 1
from  colsmart_prod_owner.cr_unidadconstruccion_ p
where p.predio_guid =m.predio_guid
and p.gdb_branch_id='0'
and p.last_edited_user='juan.gaitan')

/*
 * Constrcciniones municio 
 */



select count(u.*)
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='13836';


select sum(st_area(u.shape))
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='13836';
6.039.264

select  sum(st_area(u.shape))
from colsmart_preprod_migra.ilc_predio p
join colsmart_preprod_migra.cr_unidadconstruccion u
on p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='13836';
3.827.124

/*
 * Contrccuones repetidas  en produccion
 */

select count(*)
from (
select altura,
anio_construccion,
area_construccion,
area_privada_construida,
id_operacion_predio,
etiqueta,
planta_ubicacion,
tipo_planta,st_area(u.shape),count(*)
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='13836'
and u.anio_construccion is not null
group by altura,
anio_construccion,
area_construccion,
area_privada_construida,
etiqueta,
planta_ubicacion,
id_operacion_predio,
tipo_planta,st_area(u.shape)
having count(*)>1
) t

6.039.264

select  sum(st_area(u.shape))
from colsmart_preprod_migra.ilc_predio p
join colsmart_preprod_migra.cr_unidadconstruccion u
on p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='13836';
3.827.124


/*
 * ANalisis LA TEBABIDA
 */

/*
 * Total Construcciones
 */

select count(*)
from (
select u.anio_construccion 
from colsmart_preprod_migra.ilc_predio p
join colsmart_preprod_migra.cr_unidadconstruccion u
on  p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
) t
--24984 Produccion


select count(*)
from (
select u.anio_construccion 
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
) t
--53480 Produccion

select 53480-29439


/*
 * CONTRUCCIONES REPETIDAS
 */
select *--count(*)
from (
select altura,
anio_construccion,
area_construccion,
area_privada_construida,
id_operacion_predio,
etiqueta,
planta_ubicacion,
tipo_planta,st_area(u.shape),count(*)
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
and u.anio_construccion is not null
group by altura,
anio_construccion,
area_construccion,
area_privada_construida,
etiqueta,
planta_ubicacion,
id_operacion_predio,
tipo_planta,st_area(u.shape)
having count(*)>1
) t
--4262 Repetidas

WITH u_unidad_ AS (
select u.* 
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
), unidad as (
select u.*
from colsmart_preprod_migra.ilc_predio p
join colsmart_preprod_migra.cr_unidadconstruccion u
on  p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
)
select count(*)
from (
select prod.area_privada_construida,pre.area_privada_construida
from u_unidad_ prod
join unidad  pre
on prod.globalid=pre.globalid
and coalesce(prod.altura,'0')=coalesce(pre.altura ,'0')
and coalesce(prod.anio_construccion,'0')=coalesce(pre.anio_construccion,'0')
and coalesce(prod.area_construccion,'0')=coalesce(pre.area_construccion ,'0')
and coalesce(prod.area_privada_construida,'0')=coalesce(pre.area_privada_construida ,'0')
and coalesce(prod.etiqueta,'0')=coalesce(pre.etiqueta ,'0')
and coalesce(prod.planta_ubicacion,'0')=coalesce(pre.planta_ubicacion ,'0')
and coalesce(prod.id_operacion_predio,'0')=coalesce(pre.id_operacion_predio ,'0')
--and coalesce(prod.caracteristicasuc_guid,'0') =coalesce(pre.caracteristicasuc_guid,'0') 
) t
--29439


WITH u_unidad_ AS (
select u.* 
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='0' and  u.gdb_branch_id='0'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
), unidad as (
select u.*
from colsmart_preprod_migra.ilc_predio p
join colsmart_preprod_migra.cr_unidadconstruccion u
on  p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
)
select count(*)
from (
select prod.area_privada_construida,pre.area_privada_construida
from u_unidad_ prod
join unidad  pre
on prod.globalid=pre.globalid
and coalesce(prod.altura,'0')=coalesce(pre.altura ,'0')
and coalesce(prod.anio_construccion,'0')=coalesce(pre.anio_construccion,'0')
and coalesce(prod.area_construccion,'0')=coalesce(pre.area_construccion ,'0')
and coalesce(prod.area_privada_construida,'0')=coalesce(pre.area_privada_construida ,'0')
and coalesce(prod.etiqueta,'0')=coalesce(pre.etiqueta ,'0')
and coalesce(prod.planta_ubicacion,'0')=coalesce(pre.planta_ubicacion ,'0')
and coalesce(prod.id_operacion_predio,'0')=coalesce(pre.id_operacion_predio ,'0')
--and coalesce(prod.caracteristicasuc_guid,'0') =coalesce(pre.caracteristicasuc_guid,'0') 
) t


select u.* 
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  p.gdb_branch_id='1' and  u.gdb_branch_id='1'
AND p.gdb_is_delete = 0  AND u.gdb_is_delete = 0  
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
and  u.globalid='{82B06C6D-E46C-4BBB-B797-ADD7B0221641}'



SELECT
  t.objectid,
  t.globalid,
  t.gdb_from_date      AS deleted_at,
  t.last_edited_user   AS deleted_by
FROM colsmart_prod_owner.cr_unidadconstruccion_ AS t
WHERE
  -- DEFAULT: usa el que aplique en tu BD
  (
    t.gdb_branch_id = '0'  -- si tu BD marca DEFAULT como '0'
    OR t.gdb_branch_id = (
       SELECT version_id      -- si usa GUID de versión
	   FROM sde.sde_versions
	      WHERE name = 'DEFAULT'
	      LIMIT 1
    )
  )
  AND t.gdb_is_delete = 1
  AND t.gdb_from_date IS NULL            -- eliminación vigente
ORDER BY t.gdb_from_date DESC;

select *
FROM   sde.sde_versions sv 

  SELECT version_id      -- si usa GUID de versión
   FROM sde.sde_versions
      WHERE name = 'DEFAULT'
      LIMIT 1;

  
 --744 431  
 --744.423
  
SELECT OBJECTID
FROM colsmart_prod_owner.cr_unidadconstruccion_
WHERE cr_unidadconstruccion_.globalid IN
(
SELECT MB_.globalid 
FROM
(SELECT globalid,row_number() OVER (PARTITION BY objectid ORDER BY gdb_from_date desc )rn, gdb_is_delete
FROM colsmart_prod_owner.cr_unidadconstruccion_
WHERE (gdb_branch_id = 0)
) MB_
WHERE rn = 1 AND gdb_is_delete = '0');



select distinct u.* 
from colsmart_prod_owner.ilc_predio_ p
join colsmart_prod_owner.cr_unidadconstruccion_ u
on  --p.gdb_branch_id='0' and  u.gdb_branch_id='0'
--AND 
p.gdb_is_delete = 0  AND u.gdb_is_delete = 0 
--and u.gdb_archive_oid= '2942455'
and p.globalid=u.predio_guid
where left(numero_predial_nacional,5)='63401'
and  u.globalid in ('{F3592A4B-5E37-49D7-8649-E95F0628F10D}','{82B06C6D-E46C-4BBB-B797-ADD7B0221641}')


select *-- distinct on (last_edited_date)
from  colsmart_prod_owner.cr_unidadconstruccion_ 
where  globalid in ('{F3592A4B-5E37-49D7-8649-E95F0628F10D}','{82B06C6D-E46C-4BBB-B797-ADD7B0221641}')


select count(*)
from colsmart_prod_owner.cr_unidadconstruccion_ u,(
select globalid,gdb_from_date,
row_number() OVER (PARTITION BY u0.globalid  ORDER BY gdb_from_date desc ) rn
from  colsmart_prod_owner.cr_unidadconstruccion_ u0
where gdb_branch_id=0  and not exists (
	select 1
	from  colsmart_prod_owner.cr_unidadconstruccion_ u1
	where gdb_branch_id=0 and gdb_is_delete=1 and 
	u0.globalid =u1.globalid
)) t
where u.globalid=t.globalid --and u.gdb_from_date=t.gdb_from_date 
and rn=1


select count(*)
from (
	select objectid,gdb_from_date,
	row_number() OVER (PARTITION BY u0.objectid   ORDER BY gdb_from_date desc ) as rn
	from  colsmart_prod_owner.cr_unidadconstruccion_ u0
	where gdb_branch_id=0  and not exists (
		select 1
		from  colsmart_prod_owner.cr_unidadconstruccion_ u1
		where gdb_branch_id=0 and gdb_is_delete=1 and 
		u0.globalid =u1.globalid
	) 
) t
where rn=1



--744423
select *
from sde.sde_version sv 

drop table colsmart_prod_reader.z_p_ilc_predio_;


create table colsmart_prod_reader.z_p_ilc_predio_ as
 SELECT *
	FROM (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY OBJECTID ORDER BY GDB_FROM_DATE DESC) AS rank
	  FROM colsmart_prod_owner.ilc_predio_ u0
	 -- where  gdb_branch_id=0 and globalid in ('{F3592A4B-5E37-49D7-8649-E95F0628F10D}','{82B06C6D-E46C-4BBB-B797-ADD7B0221641}')
  ) AS ranked_table
  WHERE rank = 1 AND GDB_IS_DELETE = 0;



drop table colsmart_prod_reader.z_p_cr_unidadconstruccion_;

create table colsmart_prod_reader.z_p_cr_unidadconstruccion_ as
SELECT *
	FROM (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY OBJECTID ORDER BY GDB_FROM_DATE DESC) AS rank
	  FROM colsmart_prod_owner.cr_unidadconstruccion_ u0
  -- where  gdb_branch_id=0 and globalid in ('{F3592A4B-5E37-49D7-8649-E95F0628F10D}','{82B06C6D-E46C-4BBB-B797-ADD7B0221641}')
  ) AS ranked_table
  WHERE rank = 1 AND GDB_IS_DELETE = 0;


create table colsmart_prod_reader.z_p_ilc_caracteristicasunidadconstruccion_ as
SELECT *
	FROM (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY OBJECTID ORDER BY GDB_FROM_DATE DESC) AS rank
	  FROM colsmart_prod_owner.ilc_caracteristicasunidadconstruccion_ u0
	  where  gdb_branch_id=0
	  ) AS ranked_table
	  WHERE rank = 1 AND GDB_IS_DELETE = 0;

drop table colsmart_prod_reader.z_pre_cr_unidad;

create table colsmart_prod_reader.z_pre_cr_unidad as 
SELECT st_area(u.shape) area,
ROW_NUMBER() OVER (PARTITION BY st_area(u.shape) ORDER by  u.globalid DESC) AS orden,
u.*
  FROM colsmart_preprod_migra.ilc_predio p
  JOIN colsmart_preprod_migra.cr_unidadconstruccion u
    ON p.globalid = u.predio_guid
  WHERE LEFT(p.numero_predial_nacional, 5) = '63401';

drop table colsmart_prod_reader.z_pro_cr_unidad;

create table colsmart_prod_reader.z_pro_cr_unidad as 
SELECT st_area(u.shape) area,
ROW_NUMBER() OVER (PARTITION BY st_area(u.shape) ORDER by  u.globalid DESC) AS orden,
u.*
  FROM colsmart_prod_reader.z_p_ilc_predio_ p
  JOIN colsmart_prod_reader.z_p_cr_unidadconstruccion_ u
    ON p.globalid = u.predio_guid
  WHERE LEFT(p.numero_predial_nacional, 5) = '63401';

drop table colsmart_prod_reader.unidad_updateprod;

create table colsmart_prod_reader.unidad_updateprod as
WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad 
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND prod.area = pre.area
   and prod.orden = pre.orden
)select *
from t;


WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs(prod.area - pre.area) <1
   and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);

WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs((prod.area/pre.area)-100)<6
   and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);

WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs(prod.area - pre.area) <5
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs((prod.area/pre.area)-100)<5
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs(prod.area - pre.area_construccion) <
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);


WITH u_unidad_ AS (
  SELECT *
  FROM colsmart_prod_reader.z_pro_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.prod_globalid
  )
),
unidad AS (
  SELECT *
  FROM colsmart_prod_reader.z_pre_cr_unidad u
  where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where u.globalid=u1.pre_globalid
  )
),
t AS (
  SELECT 
    prod.globalid AS prod_globalid,st_area(prod.shape) prod_shape,
    pre.globalid  AS pre_globalid,
    pre.*
  FROM u_unidad_ AS prod
  JOIN unidad     AS pre
    ON prod.predio_guid = pre.predio_guid
   AND abs((prod.area/pre.area_construccion)-100)<6
   --and prod.orden = pre.orden
)
insert into colsmart_prod_reader.unidad_updateprod 
select *
from t
where  not exists (
  	select 1
  	from  colsmart_prod_reader.unidad_updateprod u1
  	where t.globalid=u1.prod_globalid
);



select count(*)-- p.prod_globalid,prod_shape,count(*)
from colsmart_prod_reader.unidad_updateprod p;

group by prod_globalid,prod_shape
having count(*)>1


--2288
 SELECT count(*)
  FROM colsmart_prod_reader.z_pro_cr_unidad u

  23676
  
drop table colsmart_prod_reader.unidad_updateprod_uni;

create table  colsmart_prod_reader.unidad_updateprod_uni as
select *
from (
select *,
ROW_NUMBER() OVER (PARTITION BY prod_globalid ORDER by  abs(prod_shape-coalesce(area,area_construccion)) ASC) AS rn
from colsmart_prod_reader.unidad_updateprod
) t
where rn=1;


select st_area(shape)
from colsmart_prod_reader.z_p_cr_unidadconstruccion_
where globalid='{4C2582EC-88C4-46A9-9C1A-7B2994301F2E}'

SELECT a.globalid,u.prod_globalid  
FROM colsmart_prod_reader.unidad_updateprod u
left join colsmart_prod_reader.z_pro_cr_unidad a
on a.globalid =u.prod_globalid 
where u.prod_globalid is null;
--23676

UPDATE colsmart_prod_reader.z_p_cr_unidadconstruccion_ AS z
SET  altura                         = t.altura,
     anio_construccion             = t.anio_construccion,
     area_construccion             = coalesce(t.area_construccion,st_area(z.shape)),
     area_privada_construida       = t.area_privada_construida,
     etiqueta                      = t.etiqueta,
     id_caracteristicasunidadconstru = coalesce( z.id_caracteristicasunidadconstru, t.id_caracteristicasunidadconstru),
     id_operacion_predio           = t.id_operacion_predio,
     planta_ubicacion              = t.planta_ubicacion,
     tipo_planta                   = t.tipo_planta,
     caracteristicasuc_guid        = t.caracteristicasuc_guid,
     codigo                        = t.codigo,
     identificador                 = t.identificador,
     observaciones                 = 'update_'||t.observaciones
FROM colsmart_prod_reader.unidad_updateprod_uni t
WHERE z.globalid = t.prod_globalid;


drop table colsmart_prod_reader.z_p_cr_unidadconstruccion_teaida;

create table colsmart_prod_reader.z_p_cr_unidadconstruccion_teaida as
select u.globalid,altura,
anio_construccion::numeric(30,4),area_construccion::numeric(30,4),area_privada_construida,
etiqueta,id_caracteristicasunidadconstru,id_operacion_predio,
planta_ubicacion,tipo_planta,caracteristicasuc_guid,
codigo,identificador,observaciones
from colsmart_prod_reader.z_p_cr_unidadconstruccion_ u
where u.observaciones like 'update_%';



select *
from colsmart_prod_reader.z_p_cr_unidadconstruccion_teaida

select *
from 

select c.*
from colsmart_prod_reader.z_p_cr_unidadconstruccion_ u
left join colsmart_prod_reader.z_p_ilc_caracteristicasunidadconstruccion_ c 
on u.caracteristicasuc_guid=c.globalid 
where u.observaciones like 'update_%' 


select left(numero_predial_nacional,5)
from  colsmart_prod_reader.z_p_ilc_predio_ 
group by left(numero_predial_nacional,5)


select left(numero_predial_nacional,5)
from  colsmart_prod_reader.z_p_ilc_predio_
where left(numero_predial_nacional,5) not in (
'	1559','00000','08832','A0280')
group by left(numero_predial_nacional,5)

