
DROP TABLE colsmart_prod_indicadores.consistencia_reglas;

CREATE TABLE colsmart_prod_indicadores.consistencia_reglas (
	id serial NOT NULL,
	tipo text NULL,
	item text NULL,
	descripcion text NULL,
	clases_asociadas text NULL,
	variable_asociada text NULL,
	regla_lenguaje_tecnico_ilc text NULL,
	created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT consistencia_reglas_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX consistencia_reglas_item_uidx ON colsmart_prod_indicadores.consistencia_reglas(item);

DROP TABLE colsmart_prod_indicadores.consistencia_reportes;
CREATE TABLE colsmart_prod_indicadores.consistencia_reportes (
	id int8 not NULL,
	descripcion text NULL,
	reglas_de_validacion_afectadas text null,
	created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT consistencia_reportes_pkey PRIMARY KEY (id)
);

DROP TABLE colsmart_prod_indicadores.consistencia_reportes_reglas;
CREATE TABLE colsmart_prod_indicadores.consistencia_reportes_reglas (
	id serial NOT NULL,
	id_reporte int8 NULL,
	regla text NULL,
	created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT consistencia_reportes_reglas_pkey PRIMARY KEY (id),
	constraint fk_reportes FOREIGN KEY (id_reporte) REFERENCES colsmart_prod_indicadores.consistencia_reportes(id),
	constraint fk_reglas   FOREIGN KEY (regla) 	 REFERENCES colsmart_prod_indicadores.consistencia_reglas(item)
);

--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

drop table colsmart_prod_indicadores.consistencia_validacion_sesiones;

CREATE TABLE colsmart_prod_indicadores.consistencia_validacion_sesiones (
    id serial NOT NULL PRIMARY KEY,
	tag text not NULL,
	usuario text not NULL,
	tipo TEXT NOT NULL CHECK (tipo IN ('INTERMEDIO', 'FINAL')),
    created_at timestamp DEFAULT now(),
    updated_at timestamp DEFAULT now()
);
CREATE UNIQUE INDEX consistencia_validacion_sesiones_tag_uidx ON colsmart_prod_indicadores.consistencia_validacion_sesiones(tag);

DROP TABLE colsmart_prod_indicadores.consistencia_validacion_resultados;

CREATE TABLE colsmart_prod_indicadores.consistencia_validacion_resultados (
	id serial NOT NULL PRIMARY KEY,
	id_sesion int8 NULL,
	regla text NULL,
	objeto text NULL,
	tabla text NULL,
	objectid int4 NOT NULL,
	globalid text NULL,
	predio_id int4 NOT NULL,
	numero_predial text NULL,
	descripcion text NULL,
	valor text NULL,
	cumple TEXT NOT NULL CHECK (cumple IN ('SI', 'NO', 'EXCEPCION')),
    created_at timestamp DEFAULT now(),
    updated_at timestamp DEFAULT now(),
    constraint fk_reglas   FOREIGN KEY (regla) 	 REFERENCES colsmart_prod_indicadores.consistencia_reglas(item),
    constraint fk_sesion   FOREIGN KEY (id_sesion) 	 REFERENCES colsmart_prod_indicadores.consistencia_validacion_sesiones(id) 
);


--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- truncate colsmart_prod_indicadores.consistencia_reglas;
-- truncate colsmart_prod_indicadores.consistencia_reportes_reglas

delete from  colsmart_prod_indicadores.consistencia_reportes_reglas;
delete from  colsmart_prod_indicadores.consistencia_reportes;
delete from  colsmart_prod_indicadores.consistencia_reglas;



--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


select * 
from colsmart_prod_indicadores.consistencia_reglas
order by id desc

select count(*) 
from colsmart_prod_indicadores.consistencia_reglas
-- 224

select tipo, count(*) as total_reglas 
from colsmart_prod_indicadores.consistencia_reglas
group by tipo
order by tipo asc

/*
--
1. Administrativo	57
2. Jurídico	33
3. Fisico	22
4. Economico	13
5. Topologica	56
6. Geográfico	16
7. Novedades	27

*/

select count(*)
from colsmart_prod_indicadores.consistencia_reportes
-- 79

select *
from colsmart_prod_indicadores.consistencia_reportes

select * 
from colsmart_prod_indicadores.consistencia_reportes_reglas
--153

--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--/////////////////////////////////////////////////////////////////////////////////////////////////////////////// 


select *
from  colsmart_prod_indicadores.consistencia_validacion_resultados

--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--/////////////////////////////////////////////////////////////////////////////////////////////////////////////// 


Comentarios: 

genérica toda la bd:
		Estructura
Reportes

volcado automático

para que el usuario llegue al error poner en la tabla de evidencia:
	tabla, predio id, globalid, numero predial
	
vistas:
	**powerbi**
	*** mirar como se ve en arcgis pro ****** zoom al error 
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////////////////////////////////////////////////////////////



	
	