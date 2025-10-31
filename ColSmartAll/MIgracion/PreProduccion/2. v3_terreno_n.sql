
/*******************************************************
 * crea tabla con terreno unicos
 */

	drop table colsmart_prod_insumos.z_u_r_terreno;

	create table colsmart_prod_insumos.z_u_r_terreno as
	with terreno as (
		select *,st_area(shape) area_,objectid as t_id
		from colsmart_prod_insumos.z_d_r_terreno
		union all
		select *,st_area(shape) area_,objectid+1000000 as t_id
		from colsmart_prod_insumos.z_d_u_terreno
	), terreno_uni as(
		select  codigo npn,st_area(shape) area_,max(t_id) t_id
		from terreno
		group by codigo ,st_area(shape)
	)
	select u.*
	from terreno u
	inner join terreno_uni  t 
	on codigo=t.npn 
	and t.area_=u.area_
	and t.t_id=u.t_id;


	select count(*)
	from colsmart_prod_insumos.z_u_r_terreno;
	
--412425/409.002
--114.227/114.041
	
/*******************************************************
 * Terreno no migrados por duplicados
 */	
	drop table colsmart_prod_insumos.z_u_r_terreno_caso4;

	create table colsmart_prod_insumos.z_u_r_terreno_caso4 as
	with terreno as (
		select *,st_area(shape) area_,objectid as t_id
		from colsmart_prod_insumos.z_d_r_terreno
		union all
		select *,st_area(shape) area_,objectid+1000000 as t_id
		from colsmart_prod_insumos.z_d_u_terreno
	),terreno_miss as (
		select *
		from terreno
		where t_id in (
			select t_id
			from terreno
			except 
			select t_id
			from colsmart_prod_insumos.z_u_r_terreno
		)
	)
	select 	 
	''::text etiqueta,
	''::text id_operacion,
	''::text predio_guid,
	tm.shape,
	t.codigo as codigo,
	t.t_id as identificador,
	'Caso 4:Terreno no migrados por duplicados' as observacion
	from terreno t,terreno_miss tm
	where t.t_id=tm.t_id;

	select count(*)
	from z_u_r_terreno_caso4;
	
---3.423
--186

/*******************************************************
 * Caso 1:Migracion Terreno de datos Caso 1 Cruza directo por npm y codigo
 */
	drop table colsmart_prod_insumos.z_u_r_terreno_caso1;

	create table colsmart_prod_insumos.z_u_r_terreno_caso1 as
	select 
	''::text etiqueta,
	p.id_operacion,
	p.globalid predio_guid,
	m.shape,
	m.codigo,
	m.t_id as identificador,
	'Caso 1' as observacion
	from colsmart_prod_insumos.z_u_r_terreno m
	inner join colsmart_preprod_migra.ilc_predio p  
	on m.codigo=p.numero_predial_nacional;
	
	
	
	select count(*)
	from colsmart_prod_insumos.z_u_r_terreno_caso1;
--403.590}
--108879
	


/*******************************************************
 * Caso 2: Predios sin predio matriz, se asigna al primer predio
 */

	drop table colsmart_prod_insumos.z_u_r_terreno_caso2;

	create table colsmart_prod_insumos.z_u_r_terreno_caso2 as
	with terreno as (
		select *
		from colsmart_prod_insumos.z_u_r_terreno t
		where not exists (
			select 1
			from colsmart_prod_insumos.z_u_r_terreno_caso1 c
			where c.identificador=t.t_id
		) and right(codigo,8)='00000000'
	),predio as (
		select *
		from colsmart_preprod_migra.ilc_predio p
		where not exists (
			select 1
			from colsmart_prod_insumos.z_u_r_terreno_caso1 c
			where c.predio_guid=p.globalid
		)
	), uni_predio as (
		select m.codigo,
		min(p.numero_predial_nacional) npm
		from terreno m
		inner join predio p  
		on left(m.codigo,22)=left(p.numero_predial_nacional,22)
		group by m.codigo
	) 	
	select ''::text etiqueta,
	p.id_operacion,
	null predio_guid,
	t.shape,
	t.codigo,
	t.t_id as identificador,
	'Caso 2: Sin predio matriz' as observacion
	from uni_predio u 
	inner join terreno t
	on u.codigo=t.codigo
	inner join predio p  
	on  u.npm=p.numero_predial_nacional;

	
	select count(*)
	from colsmart_prod_insumos.z_u_r_terreno_caso2;
	
--2250
--109


/*******************************************************
 * Migracion Terreno de datos Caso 3: Sin predio relacionado
 */
	drop table colsmart_prod_insumos.z_u_r_terreno_caso3;
	
	create table colsmart_prod_insumos.z_u_r_terreno_caso3 as
	with iden as (
		select identificador
		from colsmart_prod_insumos.z_u_r_terreno_caso1
		union
		select identificador
		from colsmart_prod_insumos.z_u_r_terreno_caso2
	)
	select ''::text etiqueta,
	m.shape,
	m.codigo,
	m.t_id as identificador,
	'Caso 3: Sin predio relacionado' as observacion
	from colsmart_prod_insumos.z_u_r_terreno m
	where not exists (
		select 1
		from iden i
		where i.identificador=m.t_id
	);

	
	select count(*)
	from colsmart_prod_insumos.z_u_r_terreno_caso3;
	
--3162
--5053

/*******************************
 * 	MIGRACION
 *  */	
	
/*******************************************************
 * Migracion a tabla de terreno original caso 1 y 2
 */	
	--create table colsmart_prod_insumos.z_u_r_terreno_22gdb as
	--select	*
	
	
	create table colsmart_prod_insumos.z_d_cr_terreno as
	select *
	from colsmart_preprod_migra.cr_terreno;
	
	
	delete
	from colsmart_preprod_migra.cr_terreno
	where left(codigo,5) in (
	select left(codigo,5)
	from colsmart_prod_insumos.z_u_r_terreno 
	where left(codigo,5) not in (' ','')
	group by left(codigo,5)
	);

	
	with caso1y2 as (
		select *
		from colsmart_prod_insumos.z_u_r_terreno_caso1
		union all
		select *
		from colsmart_prod_insumos.z_u_r_terreno_caso2
	)
	INSERT INTO colsmart_preprod_migra.cr_terreno
	(objectid, globalid,etiqueta, id_operacion_predio,  predio_guid, shape, 
	codigo,identificador,observaciones)
	select sde.next_rowid('colsmart_preprod_migra', 'cr_terreno') objectid,
	sde.next_globalid() globalid,etiqueta, id_operacion,  predio_guid, shape, 
	codigo,identificador,observacion
	from caso1y2;
--	where left(codigo,5) not in (' ','','15599','23350');

	----406.030
	select count(*)
	from colsmart_preprod_migra.cr_terreno;
	
	select count(*)
	from colsmart_preprod_migra.cr_terreno
	where observaciones='Caso 2: Sin predio matriz';
	

/*******************************************************
 * Migracion a tabla de terreno original caso 3
 */	
	
	INSERT INTO colsmart_preprod_migra.cr_terreno
	(objectid, globalid,etiqueta, shape, 
	codigo,identificador,observaciones)
	select 
	sde.next_rowid('colsmart_preprod_migra', 'cr_terreno') objectid,
	sde.next_globalid() globalid,
	etiqueta, shape, codigo,identificador,observacion
	from colsmart_prod_insumos.z_u_r_terreno_caso3;
--	where left(codigo,5) not in (' ','','15599','23350');

	select count(*)
	from  colsmart_preprod_migra.cr_terreno
	where observaciones='Caso 3: Sin predio relacionado';
	
	
--3255 -- reporte de marcas no localizables


	select observaciones,count(*)
	from colsmart_preprod_migra.cr_terreno
	group by observaciones
		
	with codigo as (
		select *
		from colsmart_preprod_migra.cr_terreno
		where codigo in (
		select codigo--,count(*)
		from colsmart_preprod_migra.cr_terreno
		where left(codigo,5) in (
			select left(codigo,5)
			from colsmart_prod_insumos.z_u_r_terreno 
			where left(codigo,5) not in (' ','')
			group by left(codigo,5)
		)
		group by codigo	
		having count(*)=1)
	), globalid_old as (
		select c.*,t.globalid as globalidold
		from codigo c,colsmart_prod_insumos.z_d_cr_terreno t
		where c.codigo=t.codigo
	)
	update  colsmart_preprod_migra.cr_terreno 
	set globalid=g.globalidold
	from globalid_old g
	where g.codigo=cr_terreno.codigo;
	
	

	
	
--Caso 1	403771
--Caso 2: Sin predio matriz	2259
--Caso 3: Sin predio relacionado	3255

	
	

