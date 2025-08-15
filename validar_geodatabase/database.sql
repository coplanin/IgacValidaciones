--##############################################################################
drop table colsmart_prod_indicadores.validacion_sesiones;

CREATE TABLE colsmart_prod_indicadores.validacion_sesiones (
    id serial NOT NULL PRIMARY KEY,
	id_sesion text NULL,
	fecha text NULL,
	usuario text NULL,
	sistema text NULL,
	version_so text NULL,
	python text NULL,
	sde_conn text NULL,
	filter_schema_name text NULL,
	output_path text NULL,
    created_at timestamp DEFAULT now(),
    updated_at timestamp DEFAULT now()
);

CREATE INDEX idx_validacion_sesiones_id_sesion ON colsmart_prod_indicadores.validacion_sesiones (id_sesion);
-- ##############################################################################
DROP TABLE colsmart_prod_indicadores.validacion_resultados;

CREATE TABLE colsmart_prod_indicadores.validacion_resultados (
	id serial NOT NULL PRIMARY KEY,
	id_sesion text NULL,
	tipo text NULL,
	objeto text NULL,
	tabla text NULL,
	tabla_objectid int4 NOT NULL,
	descripcion text NULL,
	valor text NULL,
    created_at timestamp DEFAULT now(),
    updated_at timestamp DEFAULT now()
);

CREATE INDEX idx_validacion_resultados_id_sesion ON colsmart_prod_indicadores.validacion_resultados (id_sesion);
CREATE INDEX idx_validacion_resultados_tipo ON colsmart_prod_indicadores.validacion_resultados (tipo);

--##############################################################################
truncate colsmart_prod_indicadores.validacion_sesiones ;
truncate colsmart_prod_indicadores.validacion_resultados ;
--##############################################################################


select * 
from  colsmart_prod_indicadores.validacion_sesiones 
order by id desc;

select count(*) 
from  colsmart_prod_indicadores.validacion_resultados 

select * 
from  colsmart_prod_indicadores.validacion_resultados 
--where tabla_objectid = -1    # relaciones de attachments 
where id_sesion = '2025_06_16_19_10' 
order by id desc
limit 20;


delete from  colsmart_prod_indicadores.validacion_resultados 
where id_sesion = '2025_06_09_12_00';

-- conteo de datos
select tabla, tabla_objectid as total_registros  
from  colsmart_prod_indicadores.validacion_resultados 
where tipo = 'CONTEO REGISTROS' and id_sesion = '2025_06_14_08_55'





--##############################################################################
select id_sesion, tipo, objeto, tabla,  count(*) 
from  colsmart_prod_indicadores.validacion_resultados 
where tipo <> 'CONTEO REGISTROS' --id_sesion = '2025_06_14_08_55' and 
group by id_sesion, tipo,  objeto, tabla;

--##############################################################################
/*
select id_sesion, tipo, objeto, tabla,  valor, count(*) 
from  colsmart_prod_indicadores.validacion_resultados 
where
objeto = 'edgeograficos.colsmart_test5_owner.ILC_PRE_CR_TER'
and id_sesion = '2025_06_09_15_13'
group by id_sesion, tipo,  objeto, tabla, valor;
*/


select * 
from  colsmart_prod_indicadores.validacion_resultados 
where
tipo = 'INTEGRIDAD REFERENCIAL'   and id_sesion = '2025_06_14_08_55'
--objeto = 'edgeograficos.colsmart_test5_owner.ILC_PRE_CR_TER'
--valor <> 'foreign_fk: None'
--order by objeto
limit 1000 
--offset 100000;

-- exportar datos
select objeto, tabla, tabla_objectid , descripcion  , valor
from  colsmart_prod_indicadores.validacion_resultados 
where id_sesion = '2025_06_14_08_55'
--and tipo = 'INTEGRIDAD REFERENCIAL'    
--limit 1000 

--##############################################################################
--////////////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////////////


--////////////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////////////
-- Ejemplos sql generados par validación
--////////////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////////////

with a as (
                        SELECT  o.objectid,  o.GlobalID as pk, d.objectid as foreign_objectid,  d.Derecho_GUID as foreign_fk 
                        FROM edgeograficos.colsmart_test5_owner.ILC_Derecho o  
                        RIGHT JOIN edgeograficos.colsmart_test5_owner.ILC_Interesado d      
                        ON o.GlobalID = d.Derecho_GUID
                    ) 
                    select a.foreign_objectid, a.foreign_fk 
                    from a   WHERE a.foreign_fk  null and  a.pk IS NULL

select * 
FROM edgeograficos.colsmart_test5_owner.ILC_Predio

select * 
from edgeograficos.colsmart_test5_owner.ILC_Interesado 
                    
                    
select * 
FROM edgeograficos.colsmart_test5_owner.CR_FuenteEspacial
limit 10



SELECT objectid, id_operacion, codigo_orip, matricula_inmobiliaria, area_catastral_terreno, numero_predial_nacional, tipo, condicion_predio, destinacion_economica, area_registral_m2, tipo_referencia_fmi_antiguo, coeficiente, area_coeficiente, globalid, predioinformal_guid, shape, municipio, created_user, created_date, last_edited_user, last_edited_date, gdb_branch_id, gdb_from_date, gdb_is_delete, gdb_deleted_at, gdb_deleted_by, gdb_archive_oid, gdb_row_replica_guid
FROM colsmart_test5_owner.ilc_predio
where objectid >= 518089 and objectid < 518099;

select tipo, count(*)
from colsmart_test5_owner.ilc_predio
group by tipo 




--////////////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * 
 * Consultas al diccionario de SDE para validar relationships
 */
https://pro.arcgis.com/en/pro-app/latest/help/data/geodatabases/manage-sql-server/geodatabase-system-tables-sqlserver.htm
https://desktop.arcgis.com/es/arcmap/latest/manage-data/using-sql-with-gdbs/returning-a-list-of-relationship-classes.htm
SELECT
 (xpath('//CatalogPath/text()', definition))::text AS "Relationship class and dataset",
 (xpath('//OriginClassNames/text()', definition))::text AS "Origin class",
 (xpath('//DestinationClassNames/text()', definition))::text AS "Destination class"
FROM 
 sde.gdb_items items INNER JOIN sde.gdb_itemtypes itemtypes
 ON items.type = itemtypes.uuid
WHERE 
 itemtypes.name = 'Relationship class';


select t.*, it.* , t.definition::text, 
 (xpath('//CatalogPath/text()', t.definition))::text AS "Relationship class and dataset",
 (xpath('//OriginClassNames/text()', t.definition))::text AS "Origin class",
 (xpath('//DestinationClassNames/text()', t.definition))::text AS "Destination class"
from sde.gdb_items t inner join sde.gdb_itemtypes it  on (t.type = it.uuid)
where it.name = 'Relationship Class'
and t.name ilike '%colsmart_test5_owner%'

select it.*
from sde.gdb_itemtypes it 
where it.name = 'Relationship Class'

--////////////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////////////