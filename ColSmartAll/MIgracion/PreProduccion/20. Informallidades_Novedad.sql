/****************
 * Verifica Archivo cargado
 */

SELECT novedad_numero_predial,count(*) 
FROM  colsmart_prod_insumos.z_i_infor_lote1
group by novedad_numero_predial;

/***
 * se llena datosadicionales del rpedio visita
 */

	INSERT INTO colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral (
	  objectid,
	  globalid,
	  autoriza_notificaciones,
	  beneficio_comunidades_indigenas,
	  celular,
	  comodato,
	  correo_electronico,
	  domicilio_notificaciones,
	  fecha_visita_predial,
	  id_operacion_predio,
	  nombres_apellidos_quien_atendio,
	  num_doc_quien_atendio,
	  observaciones,
	  predio_guid,
	  resultado_visita,
	  tipo_doc_quien_atendio,
	  novedadfmi_numero,
	  novedadfmi_codigo_orip,
	  novedadfmi_tipo,
	  novedad_numero_predial,
	  novedad_numero_tipo
	)		
	WITH dom_nov_num AS (
	  SELECT unnest(ARRAY[
	    'Cambio_Numero_Predial_a_VIA',
	    'Cambio_Numero_Predial_Condominio_a_NPH',
	    'Cambio_Numero_Predial_Condominio_a_PH',
	    'Cambio_Numero_Predial_Manzana_a_Manzana',
	    'Cambio_Numero_Predial_Mejora_a_Informal',
	    'Cambio_Numero_Predial_Mejora_a_NPH',
	    'Cambio_Numero_Predial_Municipio_a_Municipio',
	    'Cambio_Numero_Predial_NPH_a_Bien_Uso_Publico',
	    'Cambio_Numero_Predial_NPH_a_Condominio',
	    'Cambio_Numero_Predial_NPH_a_Informal',
	    'Cambio_Numero_Predial_NPH_a_PH',
	    'Cambio_Numero_Predial_Rural_a_Urbano',
	    'Cambio_Numero_Predial_Urbano_a_Rural',
	    'Cambio_Numero_Predial_Vereda_a_Vereda',
	    'Cancelacion',
	    'Cancelacion_por_Desenglobe',
	    'Cancelacion_por_Englobe',
	    'Desenglobe_Division_Material',
	    'Desenglobe_Venta_Parcial',
	    'Englobe_Mantiene_FMI',
	    'Englobe_Nuevo_FMI',
	    'Predio_Nuevo'
	  ]) AS v
	), src AS (
	  select
		  distinct
	    pr.id_operacion                         AS id_operacion_predio,
	    pr.globalid                             AS predio_guid,
	    'No'::text as autoriza_notificaciones,
	    'No'::text as beneficio_comunidades_indigenas,
	    'No'::text as comodato,
	    '0'::int as celular,
	    ''::text as correo_electronico,    
	    ''::text as domicilio_notificaciones,
		null::timestamp   fecha_visita_predial,
		''::text as nombres_apellidos_quien_atendio,
		''::text as num_doc_quien_atendio,
		'Inf1_'||f.id::text as observaciones,
		''::text as tipo_doc_quien_atendio,	
		'Sin_Visita'::text as resultado_visita,	
		pr.codigo_orip      AS novedadfmi_codigo_orip,
	    pr.matricula_inmobiliaria as novedadfmi_numero,
	    NULL as novedadfmi_tipo,
	    novedad_numero_predial novedad_numero_tipo,
	    pr.numero_predial_nacional as novedad_numero_predial,
	    CASE
	      WHEN EXISTS (
	        SELECT 1
	        FROM dom_nov_num d
	        WHERE d.v = f.novedad_numero_predial
	      ) THEN TRUE
	      ELSE FALSE
	    END AS novedad_numero_predial_valido
	  FROM colsmart_prod_insumos.z_i_infor_lote1 f
	  JOIN colsmart_preprod_migra.ilc_predio pr
	  ON f.npn = pr.numero_predial_nacional 		  	
	) --select * from src where novedad_numero_predial_valido is false ;
	SELECT
	  sde.next_rowid('colsmart_preprod_migra','ilc_datosadicionaleslevantamientocatastral') AS objectid,
	  sde.next_globalid()  AS globalid,
	  autoriza_notificaciones,
	  beneficio_comunidades_indigenas,
	  celular,
	  comodato,
	  correo_electronico,
	  domicilio_notificaciones,
	  fecha_visita_predial,
	  id_operacion_predio,
	  nombres_apellidos_quien_atendio,
	  num_doc_quien_atendio,
	  observaciones,
	  predio_guid,
	  resultado_visita,
	  tipo_doc_quien_atendio,
	  novedadfmi_numero,
	  novedadfmi_codigo_orip,
	  novedadfmi_tipo,
	  novedad_numero_predial,
	  novedad_numero_tipo
	FROM src;
	
	select *
	from colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral
	where observaciones like 'Inf1_%'
	
	with prod as (
		select novedad_numero_tipo,count(*) cant_prod
		from colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral
		where observaciones like 'Inf1_%'
		group by novedad_numero_tipo 
	),pred as (
		SELECT novedad_numero_predial,count(*) cant_ored
		FROM  colsmart_prod_insumos.z_i_infor_lote1
		group by novedad_numero_predial
	)select  d.novedad_numero_predial,cant_ored,cant_prod
	from pred d left join prod p
	on d.novedad_numero_predial=novedad_numero_tipo;
	
	
	
	
	ALTER SEQUENCE public.seq_letras_num RESTART WITH 1;
	
	with base as (
		select pr.globalid,pr.numero_predial_nacional  ,
		left(numero_predial_nacional,17)
			||public.next_letra_num() 
			||'2'
			||right(numero_predial_nacional,8) npn,
			case 
		     	when f."predio tipo"='Privado_Privado' then 'Privado' 
		     	else f."predio tipo"
		    end predio_tipo,
			f."condicion prop"  condicion_predio
		FROM colsmart_prod_insumos.z_i_infor_lote1 f
		  JOIN colsmart_preprod_migra.ilc_predio pr
		  ON f.npn = pr.numero_predial_nacional 	 
		where  	f.novedad_numero_predial  in ('Cambio_Numero_Predial_NPH_a_Informal',
		'Cambio_Numero_Predial_Mejora_a_Informal')
	)
	update colsmart_preprod_migra.ilc_predio  p
	set numero_predial_nacional=b.npn,
	condicion_predio=b.condicion_predio,
	tipo=b.predio_tipo
	from base b
	where b.globalid=p.globalid
	
	
	ALTER SEQUENCE public.seq_letras_num RESTART WITH 1;
	
	
	
	   
  	with base as (
		 select 
	   		'Inf1_'||f.id::text as id_operacion,
			vereda
			||public.next_letra_num() 
			||'2'
			||'00000000' numero_predial_nacional,
			case 
		     	when f."predio tipo"='Privado_Privado' then 'Privado' 
		     	else f."predio tipo"
		    end tipo,
		    'Habitacional' destinacion_economica,
			f."condicion prop"  condicion_predio,
			left(vereda,5) municipio
		FROM colsmart_prod_insumos.z_i_infor_lote1 f
		where  	f.novedad_numero_predial  in ('Predio_Nuevo')	
	) 
	INSERT INTO colsmart_preprod_migra.ilc_predio
	  (objectid, globalid,
	  id_operacion, numero_predial_nacional, 
	  tipo, condicion_predio, destinacion_economica, 
	  municipio)
	  SELECT
	  next_rowid('colsmart_preprod_migra', 'ilc_predio'),
	  sde.next_globalid() globalid,
	  id_operacion, numero_predial_nacional, 
	  tipo, condicion_predio, destinacion_economica, 
	  municipio
	FROM base;
	
  	
  	

	INSERT INTO colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral (
	  objectid,
	  globalid,
	  autoriza_notificaciones,
	  beneficio_comunidades_indigenas,
	  celular,
	  comodato,
	  correo_electronico,
	  domicilio_notificaciones,
	  fecha_visita_predial,
	  id_operacion_predio,
	  nombres_apellidos_quien_atendio,
	  num_doc_quien_atendio,
	  observaciones,
	  predio_guid,
	  resultado_visita,
	  tipo_doc_quien_atendio,
	  novedadfmi_numero,
	  novedadfmi_codigo_orip,
	  novedadfmi_tipo,
	  novedad_numero_predial,
	  novedad_numero_tipo
	)		
	WITH dom_nov_num AS (
	  SELECT unnest(ARRAY[
	    'Cambio_Numero_Predial_a_VIA',
	    'Cambio_Numero_Predial_Condominio_a_NPH',
	    'Cambio_Numero_Predial_Condominio_a_PH',
	    'Cambio_Numero_Predial_Manzana_a_Manzana',
	    'Cambio_Numero_Predial_Mejora_a_Informal',
	    'Cambio_Numero_Predial_Mejora_a_NPH',
	    'Cambio_Numero_Predial_Municipio_a_Municipio',
	    'Cambio_Numero_Predial_NPH_a_Bien_Uso_Publico',
	    'Cambio_Numero_Predial_NPH_a_Condominio',
	    'Cambio_Numero_Predial_NPH_a_Informal',
	    'Cambio_Numero_Predial_NPH_a_PH',
	    'Cambio_Numero_Predial_Rural_a_Urbano',
	    'Cambio_Numero_Predial_Urbano_a_Rural',
	    'Cambio_Numero_Predial_Vereda_a_Vereda',
	    'Cancelacion',
	    'Cancelacion_por_Desenglobe',
	    'Cancelacion_por_Englobe',
	    'Desenglobe_Division_Material',
	    'Desenglobe_Venta_Parcial',
	    'Englobe_Mantiene_FMI',
	    'Englobe_Nuevo_FMI',
	    'Predio_Nuevo'
	  ]) AS v
	), src AS (
	  select
		  distinct
	    pr.id_operacion                         AS id_operacion_predio,
	    pr.globalid                             AS predio_guid,
	    'No'::text as autoriza_notificaciones,
	    'No'::text as beneficio_comunidades_indigenas,
	    'No'::text as comodato,
	    '0'::int as celular,
	    ''::text as correo_electronico,    
	    ''::text as domicilio_notificaciones,
		null::timestamp   fecha_visita_predial,
		''::text as nombres_apellidos_quien_atendio,
		''::text as num_doc_quien_atendio,
		'Inf1_'||f.id::text as observaciones,
		''::text as tipo_doc_quien_atendio,	
		'Sin_Visita'::text as resultado_visita,	
		pr.codigo_orip      AS novedadfmi_codigo_orip,
	    pr.matricula_inmobiliaria as novedadfmi_numero,
	    NULL as novedadfmi_tipo,
	    novedad_numero_predial novedad_numero_tipo,
	    pr.numero_predial_nacional as novedad_numero_predial,
	    CASE
	      WHEN EXISTS (
	        SELECT 1
	        FROM dom_nov_num d
	        WHERE d.v = f.novedad_numero_predial
	      ) THEN TRUE
	      ELSE FALSE
	    END AS novedad_numero_predial_valido
	  FROM colsmart_prod_insumos.z_i_infor_lote1 f
	  JOIN colsmart_preprod_migra.ilc_predio pr
	  ON 'Inf1_'||f.id::text = pr.id_operacion 	
	  where f.novedad_numero_predial  in ('Predio_Nuevo')	
	) --select * from src where novedad_numero_predial_valido is false ;
	SELECT
	  sde.next_rowid('colsmart_preprod_migra','ilc_datosadicionaleslevantamientocatastral') AS objectid,
	  sde.next_globalid()  AS globalid,
	  autoriza_notificaciones,
	  beneficio_comunidades_indigenas,
	  celular,
	  comodato,
	  correo_electronico,
	  domicilio_notificaciones,
	  fecha_visita_predial,
	  id_operacion_predio,
	  nombres_apellidos_quien_atendio,
	  num_doc_quien_atendio,
	  observaciones,
	  predio_guid,
	  resultado_visita,
	  tipo_doc_quien_atendio,
	  novedadfmi_numero,
	  novedadfmi_codigo_orip,
	  novedadfmi_tipo,
	  novedad_numero_predial,
	  novedad_numero_tipo
	FROM src;
	
	drop table colsmart_prod_insumos.z_inf1_reporte;
	
	create table colsmart_prod_insumos.z_inf1_reporte as 
	select pr.id_operacion_predio,
	p.numero_predial_nacional numero_predial_nacional_provisional,
	f.*
	FROM colsmart_prod_insumos.z_i_infor_lote1 f
	JOIN colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral  pr
	ON 'Inf1_'||f.id::text = pr.observaciones 
	JOIN colsmart_preprod_migra.ilc_predio  p
	ON  pr.predio_guid=p.globalid
	where  pr.observaciones like 'Inf1_%'
	
	
	select *
	from  colsmart_prod_insumos.z_inf1_carga ;
	
	create table colsmart_prod_insumos.z_inf1_carga as 
	select pr.id_operacion_predio,
	p.numero_predial_nacional,
	p.condicion_predio,
	p.tipo	
	FROM colsmart_prod_insumos.z_i_infor_lote1 f
	JOIN colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral  pr
	ON 'Inf1_'||f.id::text = pr.observaciones 
	JOIN colsmart_preprod_migra.ilc_predio  p
	ON  pr.predio_guid=p.globalid
	where  pr.observaciones like 'Inf1_%'
	
	select *
	from colsmart_preprod_migra.estructura
	where table_name='ilc_predio'
	and column_name='destinacion_economica'
	order by name_value;
	
	
	
	