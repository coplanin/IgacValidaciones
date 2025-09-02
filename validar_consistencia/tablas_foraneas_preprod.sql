--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
INSERT INTO colsmart_prod_indicadores.consistencia_validacion_sesiones
(id, tag, usuario, tipo, created_at, updated_at)
VALUES(nextval('consistencia_validacion_sesiones_id_seq'::regclass), '2025-06-03', 'USUARIO PRUEBAS', 'INTERMEDIO', now(), now());

--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////


INSERT INTO colsmart_prod_indicadores.consistencia_validacion_resultados
( id_sesion, regla, objeto, tabla, objectid, globalid, predio_id, numero_predial, descripcion, valor)
VALUES(currval('consistencia_validacion_sesiones_id_seq'),  '1.1', '', '', 0, '', 0, '', '', '', 'NO');


SELECT objectid, id_operacion, codigo_orip, matricula_inmobiliaria, area_catastral_terreno, numero_predial_nacional,
tipo, condicion_predio, destinacion_economica, area_registral_m2, tipo_referencia_fmi_antiguo, coeficiente, 
area_coeficiente, globalid, predioinformal_guid, municipio, created_user, created_date, last_edited_user, 
last_edited_date, validationstatus, referencia_registral, gdb_geomattr_data, shape
FROM colsmart_preprod_migra.ilc_predio;

--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////