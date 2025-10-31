/****
 * Se debe refrescar la vista para actulizar la estrcutura de dominios
 */

REFRESH MATERIALIZED view colsmart_preprod_migra.estructura;

/****
 * Se debe refrescar la vista para actulizar los datos insertados ne la estructura de dominios
 */

REFRESH MATERIALIZED view colsmart_preprod_migra.estructura_data;


/****
 * Se consulta los dominios parametrizados en arcgis colocando la tabla y/o el campo de interes
 */

select *
from colsmart_preprod_migra.estructura
where table_name='ilc_datosadicionaleslevantamientocatastral'
--and column_name='coheficiente'
order by name_value;

PH_Unidad_Predial --PH_Undidad_Predial

/****
 * Se consulta los dominios insertados en las tablas colocando la tabla y/o el campo de interes
 */
select *
from  colsmart_preprod_migra.estructura_data
where table_name='ilc_predio'
--and column_name='tipo_documento';


/****
 * Indeitifica los errores de dominios en la base de datos de argis  sepude colocar opcionalmente
 * la tabla y/o el campo de interes
 */


select *
from (	
	select d.schema_name,d.table_name,d.column_name,d.name_value
	from estructura_data d
	except
	select distinct d.schema_name,d.table_name,d.column_name,d.name_value
	from  estructura e,estructura_data d
	where e.schema_name=d.schema_name and
	e.table_name=d.table_name and
	e.column_name=d.column_name and
	e.name_value=d.name_value
) t
where name_value is not null 
and table_name='ilc_datosadicionaleslevantamientocatastral'
--and column_name='tipo'
order by name_value;--table_name,column_name;

update colsmart_preprod_migra.ilc_predio
set tipo='Privado'
where tipo='Privado_Privado';


select *
from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
where tipo_tipologia in (
'Sin_definir_Anexos_Coliseos_Medio_Tipo_60',
'Sin_definir_Anexos_Coliseos_Plus_Tipo_80',
'Sin_definir_Anexos_Coliseos_Sencillo_Tipo_40',
'Sin_definir_Anexos_Estadios_Tipo_60',
'Sin_definir_Anexos_Plazas_de_Toros_Concreto_Tipo_80')


update colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
set tipo_anexo=replace(tipo_tipologia,'Sin_definir_Anexos',''), tipo_tipologia=null
where tipo_tipologia in (
'Sin_definir_Anexos_Coliseos_Medio_Tipo_60',
'Sin_definir_Anexos_Coliseos_Plus_Tipo_80',
'Sin_definir_Anexos_Coliseos_Sencillo_Tipo_40',
'Sin_definir_Anexos_Estadios_Tipo_60',
'Sin_definir_Anexos_Plazas_de_Toros_Concreto_Tipo_80') 


select *
from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
where tipo_anexo is not null;

UPDATE colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
SET tipo_anexo = REGEXP_REPLACE(tipo_anexo, '^_', '')
WHERE tipo_anexo LIKE '\_%' and tipo_anexo is not null;

Sin_Definir

UPDATE colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
SET uso='Sin_Definir'
WHERE uso='Sin_definir';


/****
 * Se actuliza servicios especiales
 */
update colsmart_preprod_migra.ilc_predio
set destinacion_economica='Servicios_Especiales'
where destinacion_economica='Servicios Especiales';


/****
 * Se actualizan items no validos
 */
update colsmart_preprod_migra.ilc_predio
set destinacion_economica=Null
where destinacion_economica=' ';


/****
 * Se actualizan items no validos
 */
update colsmart_preprod_migra.ilc_predio
set destinacion_economica=Null
where destinacion_economica='0';

/**
 * Se actualizan items no validos
 */
update colsmart_preprod_migra.ilc_derecho
set tipo='Sin_Definir'
where tipo='Sin definir';





