/**
 * Se verifica la tabla ilc_caracteristicasunidadconstruccion
 */
	select count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion u
	inner join colsmart_preprod_migra.cr_unidadconstruccion c
	on u.unidadconstruccion_guid=c.globalid;


	select count(*)
	from colsmart_preprod_migra.cr_unidadconstruccion c
	inner join  colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion u
	on u.globalid=c.caracteristicasuc_guid;


/**
 * Se limpia tabla ilc_caracteristicasunidadcxonstruccion
 */
	delete
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion;

/***
 * Definicion de la tabla tipo anexo
 * 
 */
	select *
	from colsmart_prod_insumos.z_f_anexo_final zfaf;

/***********
 * Insert Homologado e insercion de caracteristicas
 */

	delete 	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion;
	
	INSERT INTO colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	(objectid, globalid,  ia,detalle_ia, id_caracteristicas_unidad_cons,
	tipo_unidad_construccion, total_plantas,  uso,observaciones,
	usos_tradicionales_culturales,tipo_tipologia, conservacion_tipologia,  
	tipo_anexo,conservacion_anexo,unidadconstruccion_guid)
	select * from (
	with uso_tipologia as (
		select id_uso,puntaje, tipologia,
		CASE
			WHEN estado_de_conservacion = 'Excelente'     THEN 'Optimo_1'
			WHEN estado_de_conservacion = 'Bueno'         THEN 'Bueno_2'
			WHEN estado_de_conservacion = 'Regular'       THEN 'Regular_3'
			WHEN estado_de_conservacion = 'Malo'          THEN 'Malo_4'
			ELSE NULL  -- O podrías usar 'Sin_Homologar' u otro valor por defecto
		END AS estado		
		from colsmart_prod_insumos.z_g_uso u
		left join colsmart_prod_insumos.z_g_tipologia  t
		on u.id=t.uso
	), uso_anexo as (
		select id_uso,minimo,maximo,"estado conservacion" estado,anexo
		from colsmart_prod_insumos.z_f_anexo_final u
		where id_uso is not null
	),	predio as (
		select *,
		 CASE
		    WHEN total_puntaje = 0     THEN 1        -- reemplaza 0 por 1
		    WHEN total_puntaje > 99    THEN 99       -- recorta a 99 lo que supere 99
		    ELSE total_puntaje                      -- deja el valor sin cambios
		  END AS total_puntaje_normalizado 
		from colsmart_prod_base_owner.main_predio_unidad_construccion
	)
	select 
	sde.next_rowid('colsmart_preprod_migra', 'ilc_caracteristicasunidadconstruccion') objectid,
	sde.next_globalid() globalid,
	'No'::text as ia,''::text as detalle_ia,
	id::text as id_caracteristicas_unidad_cons,
    CASE UPPER(t.tipo_calificacion)        -- normalizo a mayúsculas para evitar problemas
        WHEN 'COMERCIAL'   THEN 'Comercial'
        WHEN 'ANEXO'       THEN 'Anexo'
        WHEN 'RESIDENCIAL' THEN 'Residencial'
        WHEN 'INDUSTRIAL'  THEN 'Industrial'
        WHEN 'INSTITUCIONAL' THEN 'Institucional'
        ELSE NULL           -- ó un valor por defecto ('Desconocido', etc.)
    END AS tipo_unidad_construccion,
    total_pisos_unidad as total_plantas,-- tomar el total pisos
    CASE
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_albercas - banaderas'                THEN 'Anexo_Albercas_Banaderas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_beneficiaderos'                      THEN 'Anexo_Beneficiaderos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_canchas de tenis'                    THEN 'Anexo_Canchas_De_Tenis'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_carretera'                           THEN 'Anexo_Carretera'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_cocheras - marraneras - porquerizas' THEN 'Anexo_Cocheras_Banieras_Porquerizas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_corrales'                            THEN 'Anexo_Corrales'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_establos - pesebreras - caballerizas' THEN 'Anexo_Establos_Pesebreras_Caballerizas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_galpones - gallineros'               THEN 'Anexo_Galpones_Gallineros'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_kioscos'                             THEN 'Anexo_Kioscos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_marquesinas - patios cubiertos'      THEN 'Anexo_Marquesinas_Patios_Cubiertos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_piscinas'                            THEN 'Anexo_Piscinas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_pozos'                               THEN 'Anexo_Pozos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_ramadas - cobertizos - caneyes'      THEN 'Anexo_Ramadas_Cobertizos_Caneyes'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_secaderos'                           THEN 'Anexo_Secaderos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_silos'                               THEN 'Anexo_Silos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_tanques'                             THEN 'Anexo_Tanques'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_toboganes'                           THEN 'Anexo_Toboganes'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'anexo_torres de enfriamiento'              THEN 'Anexo_Torres_De_Enfriamiento'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_estacion de bombeo'              THEN 'Anexo_Estacion_Bombeo'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_cimientos, estructura, muros y placa base' 
                                                                               THEN 'Anexo_Cimientos_Estructura_Muros_y_Placa_Base'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_aulas de clases'                 THEN 'Institucional_Aulas_de_Clases'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_biblioteca'                      THEN 'Institucional_Bibliotecas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_carceles'                        THEN 'Institucional_Carceles'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_casas de culto'                  THEN 'Institucional_Casas_De_Culto'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_clinicas - hospitales - centros medicos'
                                                                               THEN 'Institucional_Clinicas_Hospitales_Centros_Medicos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_colegio y universidades'         THEN 'Institucional_Colegio_y_Universidades'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_coliseos'                        THEN 'Institucional_Coliseos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_estadios - plaza de toros'       THEN 'Institucional_Estadios'          -- (o Plaza_de_Toros, según tu regla)
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_iglesia'                         THEN 'Institucional_Iglesia'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_jardin infantil en casa'         THEN 'Institucional_Jardin_Infantil_En_Casa'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_parque cementerios'              THEN 'Institucional_Parque_Cementerio'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_puestos de salud'                THEN 'Institucional_Puesto_De_Salud'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_bodegas comerciales en ph'       THEN 'Comercial_Bodegas_Comerciales_en_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_bodegas comerciales - grandes almacenes'
                                                                               THEN 'Comercial_Bodegas_Comerciales_Grandes_Almacenes'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_centros comerciales'             THEN 'Comercial_Centros_Comerciales'
        WHEN lower(destino_economico||'_'||uso_nombre) IN ('comercial_centros comerciales en ph',
                                     'centros comerciales en ph (lorenzo-pasto)') 
                                                                               THEN 'Comercial_Centros_Comerciales_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_clubes - casinos'                THEN 'Comercial_Clubes_Casinos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_comercio'                        THEN 'Comercial_Comercio'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_comercio colonial'               THEN 'Comercial_Comercio_Colonial'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_comercio en ph'                  THEN 'Comercial_Comercio_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_hotel colonial'                  THEN 'Comercial_Hotel_Colonial'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_hoteles'                         THEN 'Comercial_Hoteles'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_hoteles en ph'                   THEN 'Comercial_Hoteles_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_oficinas - consultorios'         THEN 'Comercial_Oficinas_Consultorios'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_oficinas - consultorios coloniales'
                                                                               THEN 'Comercial_Oficinas_Consultorios_Coloniales'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_oficinas consultorios en ph'     THEN 'Comercial_Oficinas_Consultorios_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_parqueaderos'                    THEN 'Comercial_Parqueaderos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_parqueaderos en ph'              THEN 'Comercial_Parqueaderos_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_pensiones y residencias'         THEN 'Comercial_Pensiones_Residencias'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_restaurantes'                    THEN 'Comercial_Restaurantes'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_restaurantes en ph'              THEN 'Comercial_Restaurante_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_teatro - cinemas'                THEN 'Comercial_Teatro_Cinemas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'comercial_teatro - cinemas en ph'          THEN 'Comercial_Teatro_Cinema_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'industrial_bodega casa bomba'              THEN 'Industrial_Bodega_Casa_Bomba'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'industrial_bodegas casa bomba en ph'       THEN 'Industrial_Bodegas_Casa_Bomba_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'industrial_industrias'                     THEN 'Industrial_Industrias'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'industrial_industrias en ph'               THEN 'Industrial_Industria_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'industrial_talleres'                       THEN 'Industrial_Talleres'
		WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_apartamentos 4 y más pisos en ph' THEN 'Residencial_Apartamentos_4_y_mas_Pisos_en_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) IN ('residencial_apartamentos en edificio de 4 y 5 pisos (cartagena)',
                                     'residencial_apartamentos mas de 4 pisos') THEN 'Residencial_Apartamentos_Mas_De_4_Pisos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_barracas'                      THEN 'Residencial_Barracas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_casa elbas'                    THEN 'Residencial_Casa_Elbas'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_garajes cubiertos'             THEN 'Residencial_Garajes_Cubiertos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_garajes en ph'                 THEN 'Residencial_Garajes_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_no especificado'               THEN 'Residencial_No_Especificado'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_vivienda colonial'             THEN 'Residencial_Vivienda_Colonial'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_vivienda hasta 3 pisos'        THEN 'Residencial_Vivienda_Hasta_3_Pisos'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_vivienda hasta 3 pisos en ph'  THEN 'Residencial_Vivienda_Hasta_3_Pisos_En_PH'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_vivienda recreacional'         THEN 'Residencial_Vivienda_Recreacional'
        WHEN lower(destino_economico||'_'||uso_nombre) = 'residencial_vivienda recreacional en ph'   THEN 'Residencial_Vivienda_Recreacional_En_PH'
		 ELSE lower(destino_economico||'_'||uso_nombre)   -- si no hay mapeo, conserva el texto original
    END as uso,
	'Puntaje:'||(t.total_puntaje_normalizado::int)::text ||', Id Uso:'||t.uso_id::text Observaciones,
	null as usos_tradicionales_culturales,
	s.tipologia as tipo_tipologia,
	s.estado as conservacion_tipologia,
	a.anexo as tipo_anexo,
	a.estado as conservacion_anexo,
	u.globalid as unidadconstruccion_guid
    from   predio t
	left join uso_tipologia s 
	on t.total_puntaje_normalizado=s.puntaje and t.uso_id=s.id_uso
	left join uso_anexo a
	on  t.uso_id=a.id_uso 
	and t.total_puntaje_normalizado>a.minimo
	and t.total_puntaje_normalizado<=a.maximo
	left join colsmart_preprod_migra.cr_unidadconstruccion u
	on u.id_caracteristicasunidadconstru::text=t.id::text
	) t where unidadconstruccion_guid is not null;
 
 /**
  * Ajuste de Tipologias a el dominio correpondiente de modelo interno
  */
	
	UPDATE colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	SET    tipo_tipologia = CASE
	WHEN tipo_tipologia ~ '^(403\d+)_Conservacion\.Residencial_'
	THEN    regexp_replace(
	           regexp_replace(
	               substring(tipo_tipologia FROM '^\d+_(.*)$'),
	       '\.', '_', 'g'),
	   '^Residencial', 'Construccion')
	|| '_' || substring(tipo_tipologia FROM '^(\d+)')
	   WHEN tipo_tipologia ~ '^\d+_'
	   THEN
	       regexp_replace(
	           substring(tipo_tipologia FROM '^\d+_(.*)$'),
	   '\.', '_', 'g')
	|| '_' || substring(tipo_tipologia FROM '^(\d+)')
	   ELSE 'Sin_definir_' || regexp_replace(tipo_tipologia, '\.', '_', 'g')
	   END;
	
	UPDATE colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	SET    tipo_tipologia = CASE
	           WHEN tipo_tipologia = 'Conservacion_Residencial_Tipo_3 _Restaurada_4024023'
	                THEN 'Conservacion_Residencial_Tipo_3_Restaurada_4024023'
	           WHEN tipo_tipologia = 'Conservacion_Residencial_Tipo_4_Restaurada_4034024'
	                THEN 'Conservacion_Construccion_Tipo_4_Restaurada_4034024'
	           WHEN tipo_tipologia = 'Conservacion_Residencial_Tipo_5_Restaurada_Con_Reforzamiento_4031035'
	                THEN 'Conservacion_Construccion_Tipo_5_Restaurada_Con_Reforzamiento_4031035'
	           WHEN tipo_tipologia = 'Nave Industrial_Pesada_2_3033443'
	                THEN 'Industrial_Pesada_2_3033443'
	           WHEN tipo_tipologia = 'Residencial_Tipo_3_Menos_1004113'
	                THEN 'Residencial_Tipo_3_menos_1004113'
	           WHEN tipo_tipologia = 'Residencial_Tipo_4_Menos_1024114'
	                THEN 'Residencial_Tipo_4_menos_1024114'
	           WHEN tipo_tipologia = 'Residencial_Tipo_5_Menos_1011115'
	                THEN 'Residencial_Tipo_5_menos_1011115'
	           ELSE tipo_tipologia
	       END;
	
/************************
* Residencial_No_Especificado  y comercial_cimientos No se encuentras deinifos quedan en la clasificaicon sin definir
*/		
		
	UPDATE colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	SET    uso = 'Sin_Definir'
	where uso='Residencial_No_Especificado' or
	uso like 'comercial_cimientos, estructura%'
 
/************************
* Residencial_No_Especificado  y comercial_cimientos No se encuentras deinifos quedan en la clasificaicon sin definir
*/		
		
	UPDATE colsmart_preprod_migra.cr_unidadconstruccion 
	SET    caracteristicasuc_guid=ic.globalid
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion ic 
	where cr_unidadconstruccion.id_caracteristicasunidadconstru=ic.id_caracteristicas_unidad_cons
	
	
/**************************
 * Estaditica de HOmologacion de Usoa
 */		
	
	select count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	where uso is not null;
	--300271
	
	select uso,count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	where tipo_tipologia is not null
	group by uso ;
	
/**************************
 * Estaditica de HOmologacion de tipologia
 */		
	
	select count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	where tipo_tipologia is not null;
	--300271
	
	select tipo_tipologia,conservacion_tipologia,count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	where tipo_tipologia is not null
	group by tipo_tipologia,conservacion_tipologia ;
	
	
/**************************
 * Estaditica de HOmologacion de Anoxo
 */		
	
	select count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	where tipo_anexo  is not null;
	--21973
	
	select tipo_anexo,conservacion_anexo,count(*)
	from colsmart_preprod_migra.ilc_caracteristicasunidadconstruccion
	where tipo_anexo is not null
	group by tipo_anexo,conservacion_anexo ;