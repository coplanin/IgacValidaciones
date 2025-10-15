/***
 * Crear materializa la  tabla predio 
 */
    drop table if exists preprod.t_ilc_predio;
	
	create table preprod.t_ilc_predio as
	select *
	from preprod.ilc_predio;
	
	ALTER TABLE preprod.t_ilc_predio ADD CONSTRAINT t_ilc_predio_unique UNIQUE (objectid);

	CREATE INDEX t_ilc_predio_geom_idx   ON preprod.t_ilc_predio  USING GIST (shape);
	
	
	/***
 * Crear materializa la  tabla predio 
 */
    drop table if exists preprod.t_cr_terreno;
	
	create table preprod.t_cr_terreno as
	select *
	from preprod.cr_terreno;
	
	ALTER TABLE preprod.t_cr_terreno ADD CONSTRAINT t_cr_terreno_unique UNIQUE (objectid);

	CREATE INDEX t_cr_terreno_geom_idx   ON preprod.t_cr_terreno  USING GIST (shape);
	