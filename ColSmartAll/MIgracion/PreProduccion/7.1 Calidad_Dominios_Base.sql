 /***+
  * De vuelve los valores unicos que existe en los dominios de la base de datos
  */
      
   
drop FUNCTION colsmart_preprod_migra.distinct_por_columna();



CREATE OR REPLACE FUNCTION colsmart_preprod_migra.distinct_por_columna()
RETURNS TABLE (
  schema_name  text,
  table_name   text,
  column_name  text,
  valor        text      -- ←­ devuelvo todo como texto; ajusta si prefieres JSON o array
)
LANGUAGE plpgsql AS
$$
DECLARE
    rec     record;
    dyn_sql text;
BEGIN
    FOR rec IN
        select
		    lower(split_part(t.table_name, '.', 2)) AS schema_name,
		    lower(split_part(t.table_name, '.', 3)) AS table_name,
		    t.column_name
		from ( 
		  select
		    	dataset_name as table_name  ,
		        (xpath('//Name/text()', cv_node))[1]::text AS column_name,
		        (xpath('//DomainName/text()', cv_node))[1]::text AS dominio
		    FROM (    
					select  i.name AS dataset_name,
						unnest(
					     xpath('//GPFieldInfoExs/GPFieldInfoEx', i.definition::xml)
					   ) AS cv_node	
					  FROM   sde.gdb_items i
					  JOIN   sde.gdb_itemtypes it ON it.uuid = i.type
					  WHERE  it.name IN ('Table','Feature Class')
					and i.name like 'egdb_colsmart_prod.colsmart_preprod_migra.%'
		     ) AS coded_values_nodes
		  ) t
		where dominio is not null
    LOOP
        -- dynamic SQL seguro: %I para identificadores, %L para literales
        dyn_sql := format(
            'SELECT %L, %L, %L, %I::text
             FROM   %I.%I
             GROUP  BY %I',
            rec.schema_name,          -- %L literal
            rec.table_name,
            rec.column_name,
            rec.column_name,          -- %I identificador (seleccionado)
            rec.schema_name,
            rec.table_name,
            rec.column_name           -- GROUP BY
        );

        RETURN QUERY EXECUTE dyn_sql;    -- añade el resultado a la salida
    END LOOP;
END;
$$;


select distinct  c.schema_name,c.table_name,c.column_name,c.valor as name_value
FROM colsmart_preprod_migra.distinct_por_columna() c;

/*******
 * Lista la estrctura de dominios base del diseño de la gdb en arcgis
 */

CREATE MATERIALIZED VIEW colsmart_preprod_migra.estructura as
with dominios as (
	select
    	domainname,
        (xpath('//Code/text()', cv_node))[1]::text AS name_value
    FROM (
        SELECT (xpath('//DomainName/text()', definition))[1]::text as domainname,
        		unnest(
                 xpath('//CodedValues/CodedValue', definition::xml)
               ) AS cv_node
        FROM   sde.gdb_items
        WHERE  (xpath('//Owner/text()', definition))[1]::text = 'colsmart_preprod_migra'
    ) AS coded_values_nodes
), conecta as (
	select
    	lower(split_part(dataset_name, '.', 2)) AS schema_name,
		lower(split_part(dataset_name, '.', 3)) AS table_name,
        (xpath('//Name/text()', cv_node))[1]::text AS column_name,
        (xpath('//DomainName/text()', cv_node))[1]::text AS domainname
    FROM (    
			select  i.name AS dataset_name,
				unnest(
			     xpath('//GPFieldInfoExs/GPFieldInfoEx', i.definition::xml)
			   ) AS cv_node	
			  FROM   sde.gdb_items i
			  JOIN   sde.gdb_itemtypes it ON it.uuid = i.type
			  WHERE  it.name IN ('Table','Feature Class')
			and i.name like 'egdb_colsmart_prod.colsmart_preprod_migra.%'
     ) AS coded_values_nodes
     where (xpath('//DomainName/text()', cv_node))[1]::text  is not null
)
select c.schema_name,c.table_name,c.column_name,d.name_value
from conecta c 
inner join dominios d
on c.domainname=d.domainname;

/*******
 * Lista la datos insertado en los campos dominio base 
 */


CREATE MATERIALIZED VIEW colsmart_preprod_migra.estructura_data AS
select distinct  c.schema_name,c.table_name,c.column_name,c.valor as name_value
FROM colsmart_preprod_migra.distinct_por_columna() c;


