-- 1) Asegurar PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2) Agregar PK (IDENTITY moderno en PG 17)
ALTER TABLE colsmart_prod_insumos.databricks_reporte_topologias
  ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY;

ALTER TABLE colsmart_prod_insumos.databricks_reporte_topologias
  ADD CONSTRAINT databricks_reporte_topologias_pkey PRIMARY KEY (id);

-- 3) Agregar columna espacial en EPSG:9377 (geometry Point)
ALTER TABLE colsmart_prod_insumos.databricks_reporte_topologias
  ADD COLUMN geom geometry(Point, 9377);

-- 4) Poblarla a partir de lon/lat en 4326
--    (asumiendo que centroide_x_4326 = LONGITUD y centroide_y_4326 = LATITUD)
UPDATE colsmart_prod_insumos.databricks_reporte_topologias
SET geom = ST_SetSRID(ST_MakePoint(centroide_x, centroide_y), 9377)
WHERE centroide_x IS NOT NULL
  AND centroide_y IS NOT NULL;

-- 5) Índice espacial GiST
CREATE INDEX databricks_reporte_topologias_geom_punto_gist
  ON colsmart_prod_insumos.databricks_reporte_topologias
  USING GIST (geom);

-- 6) (Opcional) Analizar para optimizador
ANALYZE colsmart_prod_insumos.databricks_reporte_topologias;


-- A) Agrega columnas destino
ALTER TABLE colsmart_prod_insumos.databricks_reporte_topologias
  ADD COLUMN terreno_globalid text,
  ADD COLUMN terreno_predio_guid text;

-- B) Actualiza con el match espacial (asumiendo ambos en 9377)
WITH match AS (
  SELECT
    d.id,
    t.globalid,
    t.predio_guid,
    ROW_NUMBER() OVER (PARTITION BY d.id 
    ORDER BY ST_Distance(d.geom, ST_Transform(t.shape, 9377) ) asc) AS rn
  FROM colsmart_prod_insumos.databricks_reporte_topologias d
  JOIN colsmart_prod_reader.t_cr_terreno t
    ON d.geom && t.shape
   AND ST_DWithin(d.geom, ST_Transform(t.shape, 9377), 100)
  WHERE d.geom IS NOT NULL
)
UPDATE colsmart_prod_insumos.databricks_reporte_topologias d
SET terreno_globalid   = m.globalid,
    terreno_predio_guid = m.predio_guid
FROM match m
WHERE m.id = d.id
  AND m.rn = 1;



select count(*)
FROM colsmart_prod_insumos.databricks_reporte_topologias d
where d.terreno_globalid is null

CREATE INDEX databricks_reporte_topologias_guid_idx 
ON colsmart_prod_insumos.databricks_reporte_topologias (terreno_predio_guid);
  
-- B) Actualiza con el match espacial conn el mas cercaqno a un ranfo de 100 metros
drop table colsmart_prod_insumos.databricks_reporte_topologias_unidad;

create table colsmart_prod_insumos.databricks_reporte_topologias_unidad as
with base as (
  SELECT
    d.id,
    t.globalid unidad_guid,
    t.predio_guid,
    t.caracteristicasuc_guid,
    ST_Distance(d.geom, ST_Transform(t.shape, 9377)) dist,
    ROW_NUMBER() OVER (PARTITION BY d.id ORDER BY ST_Distance(d.geom, ST_Transform(t.shape, 9377))) AS rn
  FROM colsmart_prod_insumos.databricks_reporte_topologias d
  JOIN colsmart_prod_reader.t_cr_unidadconstruccion t
    ON d.geom && t.shape
   AND ST_DWithin(d.geom, ST_Transform(t.shape, 9377), 100)
   and terreno_predio_guid=t.predio_guid 
  WHERE d.geom IS NOT null and d.terreno_predio_guid is not null
) 
select distinct u.*,t.rn2
from base u
join (
	select *,
	ROW_NUMBER() OVER (PARTITION BY unidad_guid ORDER BY dist asc) AS rn2
	from base
) t
on u.unidad_guid=t.unidad_guid and u.id=t.id and u.dist=t.dist and rn2=1;


select  *
from  colsmart_prod_insumos.databricks_reporte_topologias_unidad
order by unidad_guid,dist

--false	64314
--true	2899



drop table if exists colsmart_prod_insumos.databricks_reporte_topologias_caracteristicas;

create table  colsmart_prod_insumos.databricks_reporte_topologias_caracteristicas as
with homologacion as (
	SELECT clave_norm, destino FROM (
	  VALUES
	    ('comercial ninguna',                     NULL),
	    ('comercial no aplica',                   NULL),
	    ('comercial tipo comercial basico 2',     'Comercial.Basico_2_2014111'),
	    ('comercial tipo comercial intermedio 1', 'Comercial.Intermedio_1_2021132'),
	    ('comercial tipo comercial intermedio 2', 'Comercial.Intermedio_2_2021532'),
	    ('comercial tipo comercial intermedio 3', 'Comercial.Intermedio_3_2026532'),
	    ('comercial tipo comercial especializado 1','Comercial.Especializado_1_2023123'),
	    ('comercial tipo comercial especializado 2','Comercial.Especializado_2_2036543'),
	    ('comercial tipo comercial especializado 3',NULL),
	    ('comercial tipo comercial especializado 4',NULL),
	    ('residencial',                           NULL),
	    ('residencial no aplica',                 NULL),
	    ('residencial no aplicable',              NULL),
	    ('residencial no clasificable',           NULL),
	    ('residencial tipo 0',                    'Residencial.Tipo_0_1002311'),
	    ('residencial tipo 1',                    'Residencial.Tipo_1_1014011'),
	    ('residencial tipo 2',                    'Residencial.Tipo_2_1004122'),
	    ('residencial tipo 3 mas',                'Residencial.Tipo_3_mas_1011133'),
	    ('residencial tipo 3 menos',              'Residencial.Tipo_3_menos_1004113'),
	    ('residencial tipo 4',                    'Residencial.Tipo_4_1021134'),
	    ('residencial tipo 4 menos',              'Residencial.Tipo_4_menos_1024114'),
	    ('residencial tipo 5',                    'Residencial.Tipo_5_1021125'),
	    ('residencial tipo 5 mas',                'Residencial.Tipo_5_mas_1031135'),
	    ('residencial tipo 5 menos',              'Residencial.Tipo_5_menos_1011115'),
	    ('residencial tipo 6',                    NULL),
	    ('residencial tipo 6 mas',                NULL),
	    ('residencial tipo prefabricado 1',       'Residencial.Prefabricado_1_1005510'),
	    ('residencial tipo prefabricado 2',       'Residencial.Prefabricado_2_1005530')
	) v(clave_norm, destino)
),homologacion2 as (
	SELECT clave_norm, destino FROM (
	  VALUES
	    ('comercial ninguna',                     NULL),
	    ('comercial no aplica',                   NULL),
	    ('comercial tipo comercial basico 2',     'Comercial.Basico_2_2014111'),
	    ('comercial tipo comercial intermedio 1', 'Comercial.Intermedio_1_2021132'),
	    ('comercial tipo comercial intermedio 2', 'Comercial.Intermedio_2_2021532'),
	    ('comercial tipo comercial intermedio 3', 'Comercial.Intermedio_3_2026532'),
	    ('comercial tipo comercial especializado 1','Comercial.Especializado_1_2023123'),
	    ('comercial tipo comercial especializado 2','Comercial.Especializado_2_2036543'),
	    ('comercial tipo comercial especializado 3','Comercial.Especializado_2_2036543'),
	    ('comercial tipo comercial especializado 4','Comercial.Especializado_2_2036543'),
	    ('residencial',                           NULL),
	    ('residencial no aplica',                 NULL),
	    ('residencial no aplicable',              NULL),
	    ('residencial no clasificable',           NULL),
	    ('residencial tipo 0',                    'Residencial.Tipo_0_1002311'),
	    ('residencial tipo 1',                    'Residencial.Tipo_1_1014011'),
	    ('residencial tipo 2',                    'Residencial.Tipo_2_1004122'),
	    ('residencial tipo 3 mas',                'Residencial.Tipo_3_mas_1011133'),
	    ('residencial tipo 3 menos',              'Residencial.Tipo_3_menos_1004113'),
	    ('residencial tipo 4',                    'Residencial.Tipo_4_1021134'),
	    ('residencial tipo 4 menos',              'Residencial.Tipo_4_menos_1024114'),
	    ('residencial tipo 5',                    'Residencial.Tipo_5_1021125'),
	    ('residencial tipo 5 mas',                'Residencial.Tipo_5_mas_1031135'),
	    ('residencial tipo 5 menos',              'Residencial.Tipo_5_menos_1011115'),
	    ('residencial tipo 6',                    'Residencial.Tipo_5_mas_1031135'),
	    ('residencial tipo 6 mas',                'Residencial.Tipo_5_mas_1031135'),
	    ('residencial tipo prefabricado 1',       'Residencial.Prefabricado_1_1005510'),
	    ('residencial tipo prefabricado 2',       'Residencial.Prefabricado_2_1005530')
	) v(clave_norm, destino)
), cruce as (
	select 
	lower(d.tipologia_categoria||' '||d.tipologia_tipologia_estimacion),
	(select replace(destino,'.','_')
	from homologacion 
	where clave_norm=
	lower(d.tipologia_categoria||' '||d.tipologia_tipologia_estimacion)) tipologia_tipologia_estimacion,
	(select replace(destino,'.','_')
	from homologacion
	where clave_norm=
	lower(d.tipologia_categoria||' '||d.tipologia_segunda_tipologia)) tipologia_segunda_tipologia,
	c.tipo_tipologia,
	d.tipologia_num_pisos,
	d.view_google_streetview_url,
	d.id_fachadas_linea_visible_fotos,
	coalesce(c.created_user,'IA'::TEXT)  create_user_carac,
	u.*
	from  colsmart_prod_insumos.databricks_reporte_topologias_unidad u
	join colsmart_prod_insumos.databricks_reporte_topologias d
	on u.id=d.id 
	left join colsmart_prod_reader.t_ilc_caracteristicasunidadconstruccion c
	on u.caracteristicasuc_guid=c.globalid 
	where coalesce(c.created_user,'IA'::TEXT)  IN ('COLSMART_PROD_OWNER','administrador.colsmart','IA') 
), unidad as (
	select 
	unidad_guid ,
	caracteristicasuc_guid,
	id_fachadas_linea_visible_fotos,
	view_google_streetview_url,
	create_user_carac,
	split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1) tipo_unidad_construccion,
	coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia) tipo_tipologia,
	tipologia_num_pisos,
	case 
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial'
		and tipologia_num_pisos<4 then 'Residencial_Vivienda_Hasta_3_Pisos'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial'
		and tipologia_num_pisos>3 then 'Residencial_Apartamentos_4_y_mas_pisos'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Comercial'
		 then 'Comercial_Comercial'
		else 'Sin_Definir'
	end uso ,	
	case
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='0'
		then 'Malo_4'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='1'
		then 'Deficiente_3_5'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='2'
		then 'Deficiente_3_5'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='3'
		then 'Regular_3'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='4'
		then 'Regular_3'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='5'
		then 'Intermedio_2_5'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Residencial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='6'
		then 'Intermedio_2_5'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Comercial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3)='0'
		then ''
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Comercial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',2)='Basico' 
		then 'Deficiente_3_5'
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Comercial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',2)='Intermedio' 
		then 'Regular_3'		
		when split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)='Comercial' and
		split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',2)='Especializado' 
		then 'Intermedio_2_5'		
		else  'Regular_3'	
	end conservacion_tipologia
	from cruce
) --select * from unidad
select 
	caracteristicasuc_guid globalid,
	unidad_guid unidadconstruccion_guid,	
	'Si'::text as ia,
	view_google_streetview_url as detalle_ia,
	'IA'::text as id_caracteristicas_unidad_cons,
    tipo_unidad_construccion,
    tipologia_num_pisos as total_plantas,-- tomar el total pisos
     uso,
	'IA1_'::text||id_fachadas_linea_visible_fotos AS Observaciones,
	null as usos_tradicionales_culturales,
	tipo_tipologia,
	conservacion_tipologia,
	NULL as tipo_anexo,
	NULL as conservacion_anexo,
	create_user_carac
    from   unidad u;
--where caracteristicasuc_guid is null;
	
select nuevo,count(*)
from (
	select case when c.globalid is null then true
	else false 
	end nuevo ,c.*
	from databricks_reporte_topologias_caracteristicas c
) t
group by nuevo


validacion as (
	select 
	case 
		when tipologia_tipologia_estimacion=tipo_tipologia then true
		else false
	end tipo1_igual,
	case 
		when tipologia_segunda_tipologia=tipo_tipologia then true
		else false
	end tipo2_igual,
	case 
		when coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia)=tipo_tipologia then true
		else false
	end tipo12_igual,
	case 
		when regexp_replace(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia), '_[^_]+$', '')
		=regexp_replace(tipo_tipologia, '_[^_]+$', '') then true
		else false
	end tipo12_igual_tipo,
	split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',1)
	|| '_' ||split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',2)
	|| '_' ||split_part(coalesce(tipologia_tipologia_estimacion,tipologia_segunda_tipologia),'_',3) t1,
	split_part(tipo_tipologia,'_',1)|| '_' ||split_part(tipo_tipologia,'_',2)|| '_' ||split_part(tipo_tipologia,'_',3) t2
	from cruce
	where tipo_tipologia is not null
)
select tipo12_igual_tipo,count(*) from validacion group by tipo12_igual_tipo;
select count(*) from validacion where t1=t2;


