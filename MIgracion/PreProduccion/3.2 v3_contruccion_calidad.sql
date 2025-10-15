 
/****************************
 * Cantidad Construcciones rurales 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_construccion;
	

    
--78228

/****************************
 * Cantidad Construcciones rurales  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_construccion
	where length(z_f_r_construccion.codigo)<30;
	
--67829
	
	
/****************************
 * Cantidad Construcciones rurales informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_r_construccion
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');
	
--453
	
/****************************
 * Cantidad Construcciones urbanas 
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_construccion;
    
--131656

/****************************
 * Cantidad Construcciones urbanas  nuevas
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_construccion
	where length(codigo)<30;
	
--2069
	
	
/****************************
 * Cantidad Construcciones urbanas informales
 */

	SELECT count(*)
  	FROM colsmart_prod_insumos.z_f_u_construccion
	where  substring(codigo FROM 22 FOR 1)  in ('2','5');

--4028
	
/****************************
 * Cantidad construcciones 
 */
	select count(*)
	from (
	    SELECT *
	  	FROM colsmart_prod_insumos.z_f_u_construccion
	    union all
	    SELECT *
	  	FROM colsmart_prod_insumos.z_f_u_construccion
	) t;

--263312

 
  /*****************************************************
   * crea tabla terreno para casoes
   */
	drop table colsmart_prod_insumos.z_b_construccion;

 
 	create table colsmart_prod_insumos.z_b_construccion as
 	select *,st_area(shape) area_,
	objectid as t_id
	from colsmart_prod_insumos.z_f_r_construccion
	union all
	select *,st_area(shape) area_,
	objectid+1000000 as t_id
	from colsmart_prod_insumos.z_f_u_construccion;
	

	delete 
	from colsmart_prod_insumos.z_v_construccion;
   
  /*******************************************************
 * Construccion  caso codigo municipio
 */
	INSERT INTO colsmart_prod_insumos.z_v_construccion
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
		WITH construccion AS (
		    SELECT *
		    FROM colsmart_prod_insumos.z_b_construccion
		), cod AS (
		    SELECT LEFT(codigo, 5) AS mpcodigo
		    FROM construccion
		    WHERE LENGTH(codigo) >= 30
		    GROUP BY LEFT(codigo, 5)
		    EXCEPT
		    SELECT mpcodigo
		    FROM colsmart_prod_insumos.igac_municipios_divipola
		    WHERE mpcodigo != '00000'
		)
		SELECT 
		    row_number() OVER () + 1000 AS objectid,  -- genera IDs secuenciales desde 1001
		    gen_random_uuid()::text AS globalid,     -- usa una función estándar de UUID si está disponible
		    codigo,
		    1 AS caso,
		    'Codigo no valido' AS detalle,
		    globalid_snc,
		    shape
		FROM construccion t
		JOIN cod c ON c.mpcodigo = LEFT(t.codigo, 5);

--53
  /*******************************************************
 * Geometria de construccion no valida
 */
INSERT INTO colsmart_prod_insumos.z_v_construccion
(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
WITH construccion AS (
    SELECT *
    FROM colsmart_prod_insumos.z_b_construccion
)
SELECT 
    row_number() OVER () + 2000 AS objectid,  -- puedes ajustar el +2000 si lo deseas
    gen_random_uuid()::text AS globalid,      -- o usa uuid_generate_v4() si prefieres
    codigo,
    2 AS caso,
    'Tipo de geometría no válido: ' || COALESCE(GeometryType(shape), 'No definido') AS detalle,
    globalid_snc,
    shape
FROM construccion t
WHERE GeometryType(shape) NOT IN ('POLYGON');

   	
 --2391
  
/*******************************************************
 * Sin identificador
 */
INSERT INTO colsmart_prod_insumos.z_v_construccion
(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
WITH construccion AS (
    SELECT *
    FROM colsmart_prod_insumos.z_b_construccion
)
SELECT 
    row_number() OVER () + 10000 AS objectid,  -- Asegura que no colisiona con los anteriores
    gen_random_uuid()::text AS globalid,
    codigo,
    3 AS caso,
    'Construcción sin identificador' AS detalle,
    globalid_snc,
    shape
FROM construccion t
WHERE identificador IS NULL OR identificador = '';


 ---1.734
 
 

 	
/*******************************************************
 * Sin piso o piso cero
 */
	INSERT INTO colsmart_prod_insumos.z_v_construccion
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
		WITH construccion AS (
		    SELECT *
		    FROM colsmart_prod_insumos.z_b_construccion
		)
		SELECT 
		    row_number() OVER () + 100000 AS objectid,  -- cambia el desplazamiento si ya lo usaste
		    gen_random_uuid()::text AS globalid,
		    codigo,
		    4 AS caso,
		    'Sin pisos o piso cero' AS detalle,
		    globalid_snc,
		    shape
		FROM construccion t
		WHERE numero_pisos IS NULL OR numero_pisos = 0;


 --	85.029
   	
 /*******************************************************
 * Construcciones sin predio hasta la posicion 22
 */
	INSERT INTO colsmart_prod_insumos.z_v_construccion
	(objectid, globalid, codigo, caso, detalle, globalid_snc, shape)
		WITH construccion AS (
		    SELECT *
		    FROM colsmart_prod_insumos.z_v_construccion
		),
		sin_predio AS (
		    SELECT 
		        m.codigo,
		        m.globalid_snc,
		        m.shape,
		        row_number() OVER () + 12000 AS objectid  -- evita colisiones con otros casos
		    FROM construccion m
		    LEFT JOIN colsmart_preprod_migra.ilc_predio p
		        ON LEFT(m.codigo, 22) = LEFT(p.numero_predial_nacional, 22)
		    WHERE p.id_operacion IS NULL
		      AND m.codigo NOT IN ('', ' ', '0')
		)
		SELECT 
		    objectid,
		    gen_random_uuid()::text AS globalid,
		    codigo,
		    5 AS caso,
		    'Construcciones sin predio hasta la posición 22' AS detalle,
		    globalid_snc,
		    shape
		FROM sin_predio;
--1513
   
   	select caso,detalle,count(*)
 	from colsmart_prod_insumos.z_v_construccion
 	group by caso,detalle
 	order by caso
	
   
	
   	
   	 	
 
 