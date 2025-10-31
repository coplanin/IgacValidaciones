	INSERT INTO colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	(objectid, globalid,  ia,detalle_ia, id_caracteristicas_unidad_cons,
	tipo_unidad_construccion, total_plantas,  uso,observaciones,
	usos_tradicionales_culturales,tipo_tipologia, conservacion_tipologia,  
	tipo_anexo,conservacion_anexo,unidadconstruccion_guid)
	with unidad as (
		select * 
		from colsmart_preprod_migra.cr_unidadconstruccion
		where caracteristicasuc_guid is null
	)
	select 
	sde.next_rowid('colsmart_preprod_migra', 'ilc_caracteristicasunidadconstruccion') objectid,
	sde.next_globalid() globalid,
	'No'::text as ia,''::text as detalle_ia,
	'Dummy'::text as id_caracteristicas_unidad_cons,
   	'Residencial' AS tipo_unidad_construccion,
    0 as total_plantas,-- tomar el total pisos
    'Sin_Definir' as uso,
	'Dummy'::text AS Observaciones,
	null as usos_tradicionales_culturales,
	NULL as tipo_tipologia,
	NULL as conservacion_tipologia,
	NULL as tipo_anexo,
	NULL as conservacion_anexo,
	u.globalid as unidadconstruccion_guid
    from   unidad u;
	
 
 
 
/************************
* Actualiza el caracteristicasuc_guid y el id_caracteristicasunidadconstru ='Dummy'
*/		
		
	UPDATE colsmart_preprod_migra.cr_unidadconstruccion 
	SET    caracteristicasuc_guid=ic.globalid,
	id_caracteristicasunidadconstru='Dummy'
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion ic 
	where cr_unidadconstruccion.globalid=ic.unidadconstruccion_guid
	and cr_unidadconstruccion.caracteristicasuc_guid is null;
	
	
	
	