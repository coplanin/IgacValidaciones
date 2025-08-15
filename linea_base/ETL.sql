
--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
DROP   TABLE colsmart_prod_indicadores.indicadores_linea_base;

CREATE TABLE colsmart_prod_indicadores.indicadores_linea_base (
    id SERIAL PRIMARY KEY,
    id_regla integer,
    nombre_regla text NOT NULL,
    nombre_tabla text NOT NULL,
    id_tabla integer,
    codigo_departamento TEXT NOT NULL,
    codigo_municipio TEXT NOT NULL,
    numero_predial TEXT  NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////

select *
from indicadores_linea_base
limit 5;

-- conteo por depto muni y regla 
select codigo_departamento , codigo_municipio ,  nombre_regla,  count(*)
from colsmart_prod_indicadores.indicadores_linea_base
group by codigo_departamento , codigo_municipio  , nombre_regla 



select *
from colsmart_prod_base_owner.v_union_terrenos
limit 5;

SELECT count(*)
FROM colsmart_prod_indicadores.indicadores_linea_base;

SELECT *
FROM colsmart_prod_indicadores.indicadores_linea_base
limit 10;

truncate colsmart_prod_indicadores.indicadores_linea_base;

SELECT id_regla, nombre_regla, count(*)
FROM colsmart_prod_indicadores.indicadores_linea_base
group by id_regla, nombre_regla
order by id_regla ;

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Implementación de reglas
--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 1 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, t.codigo as codigo_geo
	FROM colsmart_prod_base_owner.main_predio as p 
	left join colsmart_prod_base_owner.v_union_terrenos as t  on p.numero_predial = t.codigo
	where  substring(p.numero_predial,22,1)  != '5'
	and trim(p.tipo_avaluo)  = '00'
)
select 1, 'OMISIONES RURALES', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial
from a 
where a.codigo_geo is null; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 2 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, t.codigo as codigo_geo
	FROM colsmart_prod_base_owner.main_predio as p 
	left join colsmart_prod_base_owner.v_union_terrenos as t  on p.numero_predial = t.codigo
	where  substring(p.numero_predial,22,1)  != '5'
	and trim(p.tipo_avaluo)  = '01'
)
select 2, 'OMISIONES URBANOS', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial
from a 
where a.codigo_geo is null; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 3 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, 
	t.codigo as codigo_geo, t.codigo_municipio as geo_cod_muni , t.codigo_departamento as geo_cod_depto, t.codigo as geo_codigo
	FROM colsmart_prod_base_owner.main_predio as p 
	right join colsmart_prod_base_owner.v_union_terrenos as t  on p.numero_predial = t.codigo
	where  SUBSTRING(t.codigo, 6, 2)  = '00'
)
select 3, 'COMISIONES RURALES', 'PREDIO',  a.predio_id, a.geo_cod_depto, a.geo_cod_muni, a.geo_codigo
from a 
where a.predio_id is null; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 4 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, 
	t.codigo as codigo_geo, t.codigo_municipio as geo_cod_muni , t.codigo_departamento as geo_cod_depto, t.codigo as geo_codigo
	FROM colsmart_prod_base_owner.main_predio as p 
	right join colsmart_prod_base_owner.v_union_terrenos as t  on p.numero_predial = t.codigo
	where  SUBSTRING(t.codigo, 6, 2)  = '01'
)
select 4, 'COMISIONES URBANAS', 'PREDIO',  a.predio_id, a.geo_cod_depto, a.geo_cod_muni, a.geo_codigo
from a 
where a.predio_id is null; 


--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 5

INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.tipo_avaluo
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '01' and ( p.destino is null or trim(p.destino) in ('', '0') )
)
select 5, 'PREDIOS URBANOS SIN DESTINACIÓN ECONÓMICA', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial  -- , a.tipo_avaluo,  a.destino
from a ; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 6
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '00' and ( p.destino is null or trim(p.destino) in ('', '0') ) 
)
select 6, 'PREDIOS RURALES SIN DESTINACIÓN ECONÓMICA', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial --, a.destino
from a ; 
--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////

-- Regla 7
-- con área construída  debería ser el área > 0? 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.destino_nombre,  p.area_construccion
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '01' and  p.destino  in ('R', 'S', 'T')  and area_construccion > 0  
)
select 7, 'PREDIOS DESTINACION DE LOTE PERO CON AREA CONSTRUIDA URBANO', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial --, a.destino
from a ; 
--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////

-- Regla 8
-- con área construída  debería ser el área > 0? 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.destino_nombre,  p.area_construccion
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '00' and  p.destino  in ('R', 'S', 'T')  and area_construccion > 0  
)
select 8, 'PREDIOS DESTINACION DE LOTE PERO CON AREA CONSTRUIDA RURAL', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial --, a.destino
from a ; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 9
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.destino_nombre,  p.area_construccion
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '00' and  p.destino  in ('A', 'C')  and (area_construccion is null or area_construccion  = 0)   
)
select 9, 'PREDIOS DESTINACION HABITACIONAL O COMERCIAL SIN CONSTRUCCIÓN RURAL', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial --, a.destino
from a ; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 10
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.destino_nombre,  p.area_construccion
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '01' and  p.destino  in ('A', 'C')  and (area_construccion is null or area_construccion  = 0)   
)
select 10, 'PREDIOS DESTINACION HABITACIONAL O COMERCIAL SIN CONSTRUCCIÓN URBANO', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial --, a.destino
from a ; 


--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- Regla 11 

INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.destino_nombre,  p.area_construccion
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '00' and   substring(p.numero_predial,22,1)  = '5'  and (area_construccion is null or area_construccion  = 0)   
)
select 11, 'PREDIOS MEJORAS SIN ÁREA CONSTRUÍDA RURAL', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial 
from a ; 

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
-- REGLA 12 
INSERT INTO colsmart_prod_indicadores.indicadores_linea_base
(id_regla, nombre_regla, nombre_tabla, id_tabla, codigo_departamento, codigo_municipio, numero_predial)
with a as (
	select p.predio_id, p.numero_predial,  p.departamento_codigo, p.municipio_codigo, p.destino, p.destino_nombre,  p.area_construccion
	FROM colsmart_prod_base_owner.main_predio as p 
	where trim(p.tipo_avaluo) = '01' and   substring(p.numero_predial,22,1)  = '5'  and (area_construccion is null or area_construccion  = 0)   
)
select 12, 'PREDIOS MEJORAS SIN ÁREA CONSTRUÍDA URBANO', 'PREDIO',  a.predio_id, a.departamento_codigo, a.municipio_codigo, a.numero_predial 
from a ; 



--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////

--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////





--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////
delete from colsmart_prod_indicadores.indicadores_linea_base where id_regla = 5;

-- ATRIBUTOS PREDIO
SELECT objectid,  anio_numero_predial, circulo_registral, numero_registro,
matricula_inmobiliaria, departamento_nombre, municipio_nombre, zona_unidad_organica,
zona_unidad_organica_nombre, tipo_avaluo, tipo_avaluo_nombre, condicion_propiedad, 
condicion_propiedad_nombre, condicion_predio, edificio, piso, unidad, 
numero_predial_anterior, nombre, destino, destino_nombre, tipo, tipo_nombre, tipo_catastro,
tipo_catastro_nombre, area_terreno, area_construccion, area_registral, avaluo_catastral, 
fecha_inscripcion_catastral, anio_ultima_resolucion, nupre, interrelacionado_snr, 
proviene_informal, tipo_informalidad, fecha_corte, anio

select *
FROM colsmart_prod_base_owner.main_predio as p
limit 5

select destino,destino_nombre,  count(*)
FROM colsmart_prod_base_owner.main_predio as p
group by destino , destino_nombre
order by destino , destino_nombre
--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////


--////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////