
select novedad_numero_predial,count(*)
from colsmart_prod_insumos.z_f5_foliosmatricula f
group by novedad_numero_predial;


--having count(*)>1;

drop table colsmart_prod_insumos.z_f_foliosmatricula_derivados;

-- Folios origen 
create table colsmart_prod_insumos.z_f_foliosmatricula_derivados  as
select *
from colsmart_prod_insumos.z_f_foliosmatricula_3
where novedad_numero_predial 
in ('Cambio_Numero_Predial_NPH_a_Bien_Uso_Publico',
'Predio_Nuevo',
'Cambio_Numero_Predial_Condominio_a_NPH',
'Desenglobe_Venta_Parcial',
'Desenglobe_Division_Material',
'Cambio_Numero_Predial_NPH_a_PH');


select  *--count(*)
from colsmart_prod_insumos.z_f_foliosmatricula_derivados
--1843

	
/****
 * Revisa si los predios existen ya creados
 *
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_derivados_exists;


create table colsmart_prod_insumos.z_f_foliosmatricula_derivados_exists  as
select *
from colsmart_prod_insumos.z_f_foliosmatricula_derivados f
where exists (
	select 1
	from colsmart_preprod_migra.ilc_predio pr
	where  f.folio_derivados=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
);


select count(*)
from  colsmart_prod_insumos.z_f_foliosmatricula_derivados_exists

/****
 * Revisa si los predios no existen
 */
drop table colsmart_prod_insumos.z_f_foliosmatricula_derivados_notexists;


create table colsmart_prod_insumos.z_f_foliosmatricula_derivados_notexists  as
select distinct on (folio_derivados) *
from colsmart_prod_insumos.z_f_foliosmatricula_derivados f
where not exists (
	select 1
	from colsmart_preprod_migra.ilc_predio pr
	where  f.folio_derivados=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
)
order by folio_derivados desc;
	
	ALTER SEQUENCE public.seq_letras_num RESTART WITH 1;
	
	
	drop table  colsmart_prod_insumos.z_f_predionuevo;
	
	create table  colsmart_prod_insumos.z_f_predionuevo as 
	WITH numerados AS (
		SELECT
		    id,                           -- identificador interno de la fila
			folio_matriz,
		    npnmatriz,
		    -- parte “fija” = todo menos los 4 últimos dígitos
		    left(npnmatriz, length(npnmatriz) - 8) AS prefijo,
		    row_number() OVER (
		        PARTITION BY left(npnmatriz, length(npnmatriz) - 8)   -- agrupa
		        ORDER BY ctid                                   -- orden dentro del grupo
		    ) AS rn,"condicion prop derivado"     condicion_predio                                    -- 1,2,3…
		FROM colsmart_prod_insumos.z_f_foliosmatricula_derivados_notexists f
		where not exists (
			select 1
			from colsmart_preprod_migra.ilc_predio p
			where f.folio_derivados=p.codigo_orip||'-'||p.matricula_inmobiliaria
		)--2942 ya creados
		--where length(npnmatriz)=30
	),folio as (
		select f.id, f.folio_matriz,f.folio_derivados, 
		n.condicion_predio,
		f.npnmatriz ,
		f.novedad_numero_predial ,
		f."predio tipo" tipo,
		f.árearegistralm2 area_registral,
		f.coeficiente,
		f.novedadfmi_tipo,
		f."área coefieciente" area_coeficiente,	
		left(n.prefijo,17)
		||public.next_letra_num() 
		||(
		CASE n.condicion_predio
	        WHEN 'Bien_Uso_Publico'                 THEN 3   -- Bienes de uso público (≠ vías)
	        WHEN 'Condominio_Matriz'                THEN 8
	        WHEN 'Condominio_Unidad_Predial'        THEN 8
	        WHEN 'Informal'                         THEN 5   -- Mejoras en terreno ajeno no reglamentadas en PH
	        WHEN 'NPH'                              THEN 0
	        WHEN 'Parque_Cementerio_Matriz'         THEN 7
	        WHEN 'Parque_Cementerio_Unidad_Predial' THEN 7
	        WHEN 'PH_Matriz'                        THEN 9
	        WHEN 'PH_Unidad_Predial'                THEN 9
	        WHEN 'Via'                              THEN 4
	        ELSE 0        -- o un código por defecto (-1, 99, etc.)
	    END)||lpad(n.rn::text, 8, '0') npm_new,
		f.npnmatriz npm
		FROM numerados AS n, colsmart_prod_insumos.z_f_foliosmatricula_derivados f
		WHERE f.id = n.id
	), rep as (
		select m.id,d.folio_derivado_2_nivel,report_muni,count(*) cant_derivados
		from colsmart_prod_insumos.sicre_rep_marca_derivado d
		inner join 	folio m
		on  d.folio_derivado_2_nivel =m.folio_derivados 
		group by m.id,d.folio_derivado_2_nivel,report_muni
	)
	select 
	--next_rowid('colsmart_test5_owner', 'ilc_predio') objectid,
	'L6_'||f.id id_operacion,
	coalesce(SPLIT_PART(f.folio_derivados,'-',1),SPLIT_PART(f.folio_matriz,'-',1)) codigo_orip,
	SPLIT_PART(f.folio_matriz,'-',2) matricula_inmobiliaria_antigua,
	SPLIT_PART(f.folio_derivados,'-',2) matricula_inmobiliaria,
	0 as area_catastral_terreno,
	f.npm as numero_predial_nacional_antiguo,
	replace(f.npm_new,'SIN NP',coalesce(r.report_muni||'00000000000','0000000000000000')||'0') as numero_predial_nacional,
	p.tipo tipo_antiguo,
	f.tipo,
	f.condicion_predio,
	'Habitacional'::text destinacion_economica,
	f.novedad_numero_predial ,
	f.novedadfmi_tipo,
	f.area_registral,
	f.folio_matriz as tipo_referencia_fmi_antiguo,
	f.coeficiente,
	f.area_coeficiente,
	sde.next_globalid() globalid,
	CASE
     when left(p.numero_predial_nacional,5)='SIN N'  THEN r.report_muni
     when p.numero_predial_nacional is null   THEN r.report_muni
     else left(p.numero_predial_nacional,5)
	end	
	 as  municipio,
	 r.report_muni,
	p.shape
	from folio f 
	left join colsmart_preprod_migra.ilc_predio p
	on f.folio_matriz=p.codigo_orip||'-'||p.matricula_inmobiliaria
	left join rep r
	on f.id =r.id ;
	
	select *
	from colsmart_prod_insumos.z_f_predionuevo
	
	
	
	
	INSERT INTO colsmart_preprod_migra.ilc_predio
	  (objectid, id_operacion, codigo_orip, matricula_inmobiliaria, area_catastral_terreno, 
	   numero_predial_nacional, tipo, condicion_predio, destinacion_economica, area_registral_m2, 
	   tipo_referencia_fmi_antiguo, coeficiente, area_coeficiente, globalid, municipio, shape)
	SELECT
	  next_rowid('colsmart_preprod_migra', 'ilc_predio'),
	  id_operacion,
	  codigo_orip,
	  matricula_inmobiliaria,
	  area_catastral_terreno,
	  numero_predial_nacional,
	  tipo,
	  condicion_predio,
	  destinacion_economica,
	  CASE
	    WHEN COALESCE(area_registral::text,'') ~ '^[0-9]+([.,][0-9]+)?$'
	      THEN REPLACE(area_registral::text, ',', '.')::numeric(30,5)
	    ELSE 0::numeric(30,5)
	  END AS area_registral_m2,
	  tipo_referencia_fmi_antiguo,
	  CASE
	    WHEN COALESCE(coeficiente::text,'') ~ '^[0-9]+([.,][0-9]+)?$'
	      THEN REPLACE(coeficiente::text, ',', '.')::numeric(30,5)
	    ELSE 0::numeric(30,5)
	  END AS coeficiente,
	  CASE
	    WHEN COALESCE(area_coeficiente::text,'') ~ '^[0-9]+([.,][0-9]+)?$'
	      THEN REPLACE(area_coeficiente::text, ',', '.')::numeric(30,5)
	    ELSE 0::numeric(30,5)
	  END AS area_coeficiente,
	  globalid,
	  municipio,
	  shape
	FROM colsmart_prod_insumos.z_f_predionuevo;
	
	
	
	select  *
	from colsmart_preprod_migra.ilc_predio p
	where exists ( 	select 1 
	from colsmart_prod_insumos.z_f_predionuevo n	
	where p.id_operacion=n.id_operacion);



/********************************************
 * se llena el derecho
 ***************************************/
	
	INSERT INTO colsmart_preprod_migra.ilc_derecho
	(objectid, globalid, fecha_inicio_tenencia, id_operacion_predio, 
	posecion_ancestral_y_o_tradicio,tipo, predio_guid)
	with base_derecho as (
		select j.foliomatricula, pr.id_operacion predio_id,j.fechaanotacion,codigonaturalezajuridica,numeroanotacion
		,j.rolpersona
		from colsmart_prod_insumos.sicre_rep_justificacion_folio j,
		colsmart_preprod_migra.ilc_predio pr
		where  exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion=n.id_operacion) 
			and  j.foliomatricula=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
			--j.rolpersona='A' and --REVISAR LOS ROLES POQEU ACA ERAN SOLO LOS A
		 --pr.id_operacion like '%-%' and 
		--and pr.id_operacion='1097944-172'
		 --- Revisar 976 porque se pierde el numero de anotacion
		--and j.Codigonaturalezajuridica::int in (select codigonaturalezajuridica
		--from colsmart_prod_insumos.sicre_justificacion_code
		--where tipo='Dominio')
		 -- incluir en la tabla de codigo 0976
	),ocupacion as (
	select 'Ocupacion'::text tipo_derecho,*
	from base_derecho
	where left((codigonaturalezajuridica ::int)::text,1)='6'
	and numeroanotacion='1'
	),posesion as (
	select 'Posesion'::text tipo_derecho,*
	from base_derecho
	where left((codigonaturalezajuridica ::int)::text,1)='6'
	and numeroanotacion!='1'
	),dominio as (
	select 'Dominio'::text tipo_derecho,*
	from base_derecho
	where left((codigonaturalezajuridica ::int)::text,1)!='6' --and numeroanotacion='1' tice que solo la anpcioan 1 revisar
	), dom_unic as (
		SELECT DISTINCT ON (t.predio_id)
		       t.predio_id,
		       t.fechaanotacion,
		       t.codigonaturalezajuridica,
		       t.numeroanotacion,
		       t.rolpersona,
		       tipo_derecho
		FROM dominio AS t
		ORDER BY
		  t.predio_id,
		  t.fechaanotacion DESC,     -- más reciente
		  t.numeroanotacion desc,    -- desempate opcional
		  t.tipo_derecho
	), derecho_cruce as(
		select distinct		
		to_date(fechaanotacion,'DD/MM/YYYY')  fecha_inicio_tenencia,
		predio_id id_operacion_predio,
		'No' as posecion_ancestral_y_o_tradicio,
		tipo_derecho tipo,
		p.globalid predio_guid
		from dom_unic u
		left join colsmart_preprod_migra.ilc_predio p
		on u.predio_id=p.id_operacion
	)
	select 
	next_rowid('colsmart_preprod_migra', 'ilc_derecho') objectid,
	sde.next_globalid() globalid,
	*
	from derecho_cruce
	union all
	select 
	next_rowid('colsmart_preprod_migra', 'ilc_derecho') objectid,
	sde.next_globalid() globalid,
	to_date('01/01/1900','DD/MM/YYYY') fecha_inicio_tenencia,
	n.id_operacion id_operacion_predio,
	'No' as posecion_ancestral_y_o_tradicio,
	'Sin_Definir'::text tipo,
	p.globalid predio_guid
	from colsmart_prod_insumos.z_f_predionuevo n
	left join colsmart_preprod_migra.ilc_predio p
	on n.id_operacion=p.id_operacion
	where not exists (
		select 
		from derecho_cruce d
		where d.id_operacion_predio=n.id_operacion
	);
	
	
	
	
	
	
	select *
	from colsmart_preprod_migra.ilc_derecho pr
	where exists ( 	select 1 
	from colsmart_prod_insumos.z_f_predionuevo n	
	where pr.id_operacion_predio=n.id_operacion);
	
	
	delete
	from colsmart_preprod_migra.ilc_derecho pr
	where exists ( 	select 1 
	from colsmart_prod_insumos.z_f_predionuevo n	
	where pr.id_operacion_predio=n.id_operacion);
	
	

/********************************************
 * se llena ILC_FUENETE_ADMINISTRATIVA
 ***************************************/
	INSERT INTO colsmart_preprod_migra.ilc_fuenteadministrativa
	(objectid, globalid, derecho_guid, ia,detalle_ia, ente_emisor, estado_disponibilidad, 
	fecha_documento_fuente,  id_operacion_predio, numero_fuente, observacion, tipo, tipo_principal)
	with fuente_admin as (
		select j.*,id_operacion predio_id
		from colsmart_prod_insumos.sicre_rep_justificacion_folio j,
		colsmart_preprod_migra.ilc_predio pr
		where  exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion=n.id_operacion) 
			and j.foliomatricula=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
		--j.rolpersona='A' and REVISAR LOS ROLES POQEU ACA ERAN SOLO LOS A
		 --pr.id_operacion like '%-%' 
	),fuente as (
		select distinct CASE UPPER(tipodocumento)
	       WHEN 'CERTIFICADO'             THEN 'Otro_Documento_fuente'
	       WHEN 'AUTO'                    THEN 'Auto'
	       WHEN 'RESOLUCION ADMINISTRATIVA' THEN 'Acto_Administrativo'
	       WHEN 'OFICIO'                  THEN 'Otros_Documentos'
	       WHEN 'ACTA'                    THEN 'Otro_Documento_fuente'
	       WHEN 'JUICIO DE SUCESION'      THEN 'Sentencia_Judicial'
	       WHEN 'SIN INFORMACION'         THEN 'Sin_Documento'
	       WHEN 'RESOLUCION'              THEN 'Acto_Administrativo'
	       WHEN 'ESCRITURA'               THEN 'Escritura_Publica'
	       WHEN 'DEMANDA'                 THEN 'Documento_Privado'
	       WHEN 'DOCUMENTO'               THEN 'Otro_Documento_fuente'
	       WHEN 'SENTENCIA'               THEN 'Sentencia_Judicial'
	       WHEN 'PROVIDENCIA'             THEN 'Auto'
	       WHEN 'SEPARACION DE BIENES'    THEN 'Sentencia_Judicial'
	       WHEN 'ACTO ADMINISTRATIVO'     THEN 'Acto_Administrativo'
	       WHEN 'REMATE'                  THEN 'Auto'
	       WHEN 'DESPACHO COMISORIO'      THEN 'Auto'
	       WHEN 'DILIGENCIA'              THEN 'Otros_Documentos'
	       WHEN 'SUCESION'                THEN 'Sentencia_Judicial'
	       WHEN 'ACTA DE CONCILIACION'    THEN 'Otro_Documento_fuente'
	       WHEN 'DECLARACIONES'           THEN 'Otros_Documentos'
	       WHEN 'CORRECCION'              THEN 'Otros_Documentos'
	       /* En caso de que no coincida nada, lo enviamos a un dominio por defecto */
	       ELSE 'Otros_Documentos'  end tipodocumento,--Homologar dominio ladm
			REGEXP_REPLACE(numerodocumento, '[^\d]+', '', 'g') numerodocumento ,-- expresion regular quitar caracteres
			to_date(fechadocumento,'DD/MM/YYYY') Fecha_Documento_Fuente,
			oficinaorigendocumento,predio_id
			from fuente_admin f
	)
	select 
	 DISTINCT ON (f.predio_id)
	next_rowid('colsmart_preprod_migra', 'ilc_fuenteadministrativa') objectid,
	sde.next_globalid() globalid,
	d.globalid derecho_guid,
	'Si'::text ai,
	'Nuevo Derivado Colsmart'::text  detalle_ia,
	''::text  ente_emisor,
	''::text  estado_disponibilidad,
	fecha_documento_fuente,
	predio_id id_operacion_predio,
	numerodocumento,
	oficinaorigendocumento observacion,
	tipodocumento tipo,
	''::text  tipo_principal
	from fuente  f
	inner join colsmart_preprod_migra.ilc_predio p
	on f.predio_id=p.id_operacion
	inner join colsmart_preprod_migra.ilc_derecho d
	on f.predio_id=d.id_operacion_predio
	ORDER BY
		  predio_id desc,
		  fecha_documento_fuente desc;

	
	

	select *
	from colsmart_preprod_migra.ilc_fuenteadministrativa pr
	where exists ( select 1 
	from colsmart_prod_insumos.z_f_predionuevo n	
	where pr.id_operacion_predio=n.id_operacion);
	
	
	delete
	from colsmart_preprod_migra.ilc_fuenteadministrativa pr
	where exists ( select 1 
	from colsmart_prod_insumos.z_f_predionuevo n	
	where pr.id_operacion_predio=n.id_operacion);

/***
 * se llena los interesados
 */

	INSERT INTO colsmart_preprod_migra.ilc_interesado (
	    objectid,
	    globalid,
	    autoriza_notificacion_correo,
	    autorreco_campesino,
	    correo_electronico,
	    departamento,
	    derecho_guid,
	    direccion_residencia,
	    documento_identidad,
	    domicilio_notificacion,
	    grupo_etnico,
	    id_operacion_predio,
	    municipio,
	    nombre,
	    nombre_comunidad,
	    nombre_pueblo,
	    participacion,
	    porcentaje_propiedad,
	    primer_apellido,
	    primer_nombre,
	    razon_social,
	    segundo_apellido,
	    segundo_nombre,
	    sexo,
	    telefono,
	    tipo,
	    tipo_documento
	)
	SELECT
	    sde.next_rowid('colsmart_preprod_migra', 'ilc_interesado') as objectid,
	    sde.next_globalid() as globalid,
	    'No' AS autoriza_notificacion_correo,
	    'No' AS autorreco_campesino,
	    NULL AS correo_electronico,
	    j.departamento,
	    d.globalid AS derecho_guid,
	    direccion AS direccion_residencia,
	    COALESCE(numerodocumentointerviniente,'0') AS documento_identidad,
	    NULL AS domicilio_notificacion,
	    NULL AS grupo_etnico,
	    pr.id_operacion AS id_operacion_predio,
	    j.municipio,
	    interviniente AS nombre,
	    NULL AS nombre_comunidad,
	    NULL AS nombre_pueblo,
	    NULL AS participacion,
	    NULL AS porcentaje_propiedad,
	    NULL AS primer_apellido,
	    NULL AS primer_nombre,
	    NULL AS razon_social,
	    NULL AS segundo_apellido,
	    NULL AS segundo_nombre,
	    NULL AS sexo,
	    NULL AS telefono,
	    CASE 
	        WHEN tipodocumentointerviniente IN ('CC','TI','CE','NU','PA','RC') 
	            THEN 'Persona_Natural'
	        WHEN tipodocumentointerviniente IN ('NIT','SE') 
	            THEN 'Persona_Juridica'
	        ELSE null
	     END AS tipo,
	     CASE 
	        WHEN tipodocumentointerviniente = 'CC'  THEN 'Cedula_Ciudadania'
	        WHEN tipodocumentointerviniente = 'CE'  THEN 'Cedula_Extranjeria'
	        WHEN tipodocumentointerviniente = 'TI'  THEN 'Tarjeta_Identidad'
	        WHEN tipodocumentointerviniente = 'RC'  THEN 'Registro_Civil'
	        WHEN tipodocumentointerviniente = 'PA'  THEN 'Pasaporte'
	        WHEN tipodocumentointerviniente = 'NIT' THEN 'NIT'
	        WHEN tipodocumentointerviniente = 'SE'  THEN 'Secuencial'
	        WHEN tipodocumentointerviniente = 'NU'  THEN 'Secuencial'
	        ELSE null
	    END  AS tipo_documento
	FROM colsmart_prod_insumos.sicre_rep_justificacion_folio j,
	colsmart_preprod_migra.ilc_predio pr
	left join colsmart_preprod_migra.ilc_derecho d
	on d.id_operacion_predio = pr.id_operacion
	where  exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion=n.id_operacion) 
			and j.foliomatricula=pr.codigo_orip||'-'||pr.matricula_inmobiliaria
	--pr.id_operacion like '%-%' 
	
	
	
	
	select *
	from colsmart_preprod_migra.ilc_interesado pr
	where  exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion_predio=n.id_operacion) 
			
	delete
	from colsmart_preprod_migra.ilc_interesado pr
	where exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion_predio=n.id_operacion);

/***
 * se llena extdireccion
 */

	INSERT INTO colsmart_preprod_migra.extdireccion (
	  objectid,
	  globalid,
	  clase_via_principal,
	  codigo_postal,
	  complemento,
	  es_direccion_principal,
	  id_operacion_predio,
	  letra_via_generadora,
	  letra_via_principal,
	  localizacion,
	  nombre_predio,
	  numero_predio,
	  predio_guid,
	  sector_ciudad,
	  sector_predio,
	  tipo_direccion,
	  valor_via_generadora,
	  valor_via_principal
	)
	WITH direccion AS (
	  SELECT DISTINCT
	    NULL::varchar(255)                               AS clase_via_principal,
	    NULL::varchar(20)                                AS codigo_postal,
	    NULL::varchar(255)                               AS complemento,
	    'SI'::varchar(2)                                 AS es_direccion_principal,
	    pr.id_operacion                                  AS id_operacion_predio,
	    NULL::varchar(20)                                AS letra_via_generadora,
	    NULL::varchar(20)                                AS letra_via_principal,
	    NULL::varchar(255)                               AS localizacion,
	    j.direccion                                      AS nombre_predio,
	    NULL::int4                                       AS numero_predio,
	    pr.globalid                                      AS predio_guid,
	    NULL::varchar(255)                               AS sector_ciudad,
	    NULL::varchar(50)                                AS sector_predio,
	    'No_Estructurada'::varchar(255)                  AS tipo_direccion,
	    NULL::int4                                       AS valor_via_generadora,
	    NULL::int4                                       AS valor_via_principal
	  FROM colsmart_prod_insumos.sicre_rep_justificacion_folio AS j
	  JOIN colsmart_preprod_migra.ilc_predio AS pr
	    ON j.foliomatricula = pr.codigo_orip || '-' || pr.matricula_inmobiliaria
	  WHERE  exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion=n.id_operacion) 			
	)
	SELECT
	  sde.next_rowid('colsmart_preprod_migra', 'extdireccion') AS objectid,
	  sde.next_globalid()                                      AS globalid,
	  clase_via_principal,
	  codigo_postal,
	  complemento,
	  es_direccion_principal,
	  id_operacion_predio,
	  letra_via_generadora,
	  letra_via_principal,
	  localizacion,
	  nombre_predio,
	  numero_predio,
	  predio_guid,
	  sector_ciudad,
	  sector_predio,
	  tipo_direccion,
	  valor_via_generadora,
	  valor_via_principal
	FROM direccion;
	
	
	select  *
	from colsmart_preprod_migra.extdireccion
	where  id_operacion_predio like '%-%' 
	
	delete
	from colsmart_preprod_migra.extdireccion pr
	where exists (	select 1 
			from colsmart_prod_insumos.z_f_predionuevo n	
			where pr.id_operacion_predio=n.id_operacion);



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
	WITH src AS (
	  select
	 	pr.id_operacion                         AS id_operacion_predio_src,
	    pr.globalid                             AS predio_guid_src,
	    'No'::text as autoriza_notif,
	    'No'::text as benef_indigena,
	    'No'::text as comodato,
	    '0'::text as celular,
	    ''::text as correo_electronico,    
	    ''::text as domicilio_notif,
		null    fecha_visita,
		''::text as nombre_quien_atendio,
		''::text as num_doc_quien_atendio,
		'L6_'||pn.id::text as observaciones,
		''::text as tipo_doc_quien_atendio_raw,	
		'Sin_Visita'::text as resultado_visita_raw,	
		pn.novedad_numero_predial,
		---Tabla ILC_NovedadFMI
	    pr.codigo_orip  AS codigo_orip_src,
		pr.matricula_inmobiliaria as novedadfmi_numero,
		pn.novedadfmi_tipo as novedadfmi_tipo_raw,
		---Tabla ILC_EstructuraNovedadNumeroPredial
	    pn.novedad_numero_predial as novedad_numero_tipo_raw,
	    pn.npnmatriz              AS npn_src-- Numero predial origen
	    ----Fin tabla
	  FROM  colsmart_preprod_migra.ilc_predio pr
	  JOIN colsmart_prod_insumos.z_f_foliosmatricula_derivados pn
	    ON pn.folio_derivados=pr.codigo_orip||'-'||pr.matricula_inmobiliaria	 
	),
	-- Catálogos canónicos (los que nos diste)
	dom_nov_num AS (
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
	),
	dom_res AS (
	  SELECT unnest(ARRAY[
	    'Exitoso','Incompleto','Menor_Edad','No_Hay_Nadie','No_Permitieron_Acceso',
	    'Sin_Visita','Situacion_Orden_Publico','Zona_Dificil_Acceso'
	  ]) AS v
	),
	dom_nov_fmi AS (
	  SELECT unnest(ARRAY[
	    'FMI_Con_Error_En_La_Identificacion_De_Naturaleza_Juridica_Del_Acto',
	    'FMI_Debe_Estar_Abierto','FMI_Debe_Estar_Cerrado',
	    'FMI_Duplicado_Sobre_El_Mismo_Bien_Inmueble',
	    'FMI_No_Es_Segregado_Del_Que_Se_Enuncia',
	    'FMI_Sin_Correspondencia_Catastral',
	    'Titulo_Mal_Inscrito_No_Corresponde_Al_Predio'
	  ]) AS v
	),
	norm AS (
	  SELECT
	    -- Si/No normalizado
	    CASE WHEN upper(btrim(COALESCE(src.autoriza_notif::text,''))) IN ('SI','S','YES','Y','1','TRUE')
	         THEN 'Si' ELSE 'No' END                           AS autoriza_notificaciones,
	    CASE WHEN upper(btrim(COALESCE(src.benef_indigena::text,''))) IN ('SI','S','YES','Y','1','TRUE')
	         THEN 'Si' ELSE 'No' END                           AS beneficio_comunidades_indigenas,
	    CASE WHEN upper(btrim(COALESCE(src.comodato::text,''))) IN ('SI','S','YES','Y','1','TRUE')
	         THEN 'Si' ELSE 'No' END                           AS comodato,
	    -- Celular seguro (evitar overflow de int4; si > 9 dígitos -> NULL)
	    CASE
	      WHEN src.celular IS NULL THEN NULL::int4
	      ELSE (
	        CASE
	          WHEN length(regexp_replace(src.celular::text,'\D','','g')) BETWEEN 1 AND 9
	            THEN regexp_replace(src.celular::text,'\D','','g')::int
	          ELSE NULL::int
	        END
	      )
	    END                                                   AS celular,
	    lower(btrim(src.correo_electronico::text))            AS correo_electronico,
	    COALESCE(btrim(src.domicilio_notif::text),'')                  AS domicilio_notificaciones, -- 🔁 usa j.domicilio_notif si existe; si no, la dirección
	    -- Fecha de visita
	    (src.fecha_visita)::timestamp                         AS fecha_visita_predial,     -- 🔁 ajusta nombre si difiere
	    src.id_operacion_predio_src                           AS id_operacion_predio,
	    COALESCE(NULLIF(btrim(src.nombre_quien_atendio::text),''),'No_Reportado') AS nombres_apellidos_quien_atendio, -- 🔁
	    NULLIF(btrim(src.novedadfmi_numero::text),'')         AS novedadfmi_numero,        -- 🔁 puede ser el FMI en cuestión
	    -- N° predial nuevo/actual (obligatorio). Si no lo reportan, usa el NPN del predio.
	    COALESCE(NULLIF(btrim(src.novedad_numero_predial::text),''), src.npn_src, 'NO_APLICA') AS novedad_numero_predial, -- 🔁
	    NULLIF(btrim(src.num_doc_quien_atendio::text),'')     AS num_doc_quien_atendio,    -- 🔁
	    NULLIF(btrim(src.observaciones::text), '')            AS observaciones,            -- 🔁
	    src.predio_guid_src                                   AS predio_guid,
	    src.codigo_orip_src                                   AS novedadfmi_codigo_orip,
	    -- Tipo de documento de quien atendió → a tus dominios
	    CASE
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('CC')                               THEN 'Cedula_Ciudadania'
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('CE')                               THEN 'Cedula_Extranjeria'
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('TI')                               THEN 'Tarjeta_Identidad'
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('RC')                               THEN 'Registro_Civil'
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('PA')                               THEN 'Pasaporte'
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('NIT')                              THEN 'NIT'
	      WHEN upper(src.tipo_doc_quien_atendio_raw) IN ('SE','NU')                          THEN 'Secuencial'
	      WHEN upper(replace(src.tipo_doc_quien_atendio_raw,' ','_')) LIKE 'CEDULA%CIUDAD%'  THEN 'Cedula_Ciudadania'
	      WHEN upper(replace(src.tipo_doc_quien_atendio_raw,' ','_')) LIKE 'CEDULA%EXTRANJ%' THEN 'Cedula_Extranjeria'
	      WHEN upper(replace(src.tipo_doc_quien_atendio_raw,' ','_')) LIKE 'TARJETA%IDENT%'  THEN 'Tarjeta_Identidad'
	      WHEN upper(replace(src.tipo_doc_quien_atendio_raw,' ','_')) LIKE 'REGISTRO%CIVIL'  THEN 'Registro_Civil'
	      WHEN upper(replace(src.tipo_doc_quien_atendio_raw,' ','_')) LIKE 'PASAP%'          THEN 'Pasaporte'
	      ELSE NULL
	    END                                               AS tipo_doc_quien_atendio,
	    -- Resultado de la visita → dominio
	    COALESCE(res.v,
	      CASE
	        WHEN src.resultado_visita_raw ILIKE '%exito%'                     THEN 'Exitoso'
	        WHEN src.resultado_visita_raw ILIKE '%incomplet%'                 THEN 'Incompleto'
	        WHEN src.resultado_visita_raw ILIKE '%menor%'                     THEN 'Menor_Edad'
	        WHEN src.resultado_visita_raw ILIKE '%no hay%'                    THEN 'No_Hay_Nadie'
	        WHEN src.resultado_visita_raw ILIKE '%no permit%'                 THEN 'No_Permitieron_Acceso'
	        WHEN src.resultado_visita_raw ILIKE '%orden%' AND src.resultado_visita_raw ILIKE '%public%' THEN 'Situacion_Orden_Publico'
	        WHEN src.resultado_visita_raw ILIKE '%dificil%' OR src.resultado_visita_raw ILIKE '%difícil%' THEN 'Zona_Dificil_Acceso'
	        ELSE 'Sin_Visita'
	      END)                                           AS resultado_visita,
	    -- Novedad número tipo → dominio (join por normalización)
	    nn.v                                            AS novedad_numero_tipo,
	    -- Novedad FMI tipo → dominio (join por normalización + fallback NULL)
	    nf.v                                            AS novedadfmi_tipo
	  FROM src
	  LEFT JOIN LATERAL (
	     -- normaliza texto crudo a form canonical con guiones bajos
	     SELECT v
	     FROM dom_nov_num d
	     WHERE upper(d.v) = upper(
	       regexp_replace(
	         replace(coalesce(src.novedad_numero_tipo_raw,''),' ','_'),
	         '[^A-Za-z0-9_]+','_','g'
	       )
	     )
	  ) AS nn ON true
	  LEFT JOIN dom_res res
	    ON upper(res.v) = upper(
	         regexp_replace(
	           replace(coalesce(src.resultado_visita_raw,''),' ','_'),
	           '[^A-Za-z0-9_]+','_','g'
	         )
	       )
	  LEFT JOIN LATERAL (
	     SELECT v
	     FROM dom_nov_fmi d
	     WHERE upper(d.v) = upper(
	       regexp_replace(
	         replace(coalesce(src.novedadfmi_tipo_raw,''),' ','_'),
	         '[^A-Za-z0-9_]+','_','g'
	       )
	     )
	  ) AS nf ON true
	),
	prep AS (
	  SELECT
	   distinct  n.*
	  FROM norm n
	)SELECT
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
	FROM prep;
	
	

	
	select count(*)
	from 	colsmart_preprod_migra.ilc_datosadicionaleslevantamientocatastral d
	where observaciones like ('L6_%')

	
	