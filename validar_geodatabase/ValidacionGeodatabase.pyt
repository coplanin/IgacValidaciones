# -*- coding: utf-8 -*-
import arcpy
import datetime, traceback
import platform
import os, logging
import pandas as pd
from sqlalchemy import create_engine

class Toolbox(object):
    def __init__(self):
        self.label = "Validación Geodatabase"
        self.alias = "validaciongdb"
        self.tools = [ValidarGeodatabase]

class ValidarGeodatabase(object):
    def __init__(self):
        self.label = "Validar Geodatabase"
        self.description = "Ejecuta múltiples validaciones sobre una geodatabase: integridad referencial, dominios, geometría y topología."

    def getParameterInfo(self):
        params = [
            arcpy.Parameter(
                displayName="Ruta de la Geodatabase",
                name="gdb_path",
                datatype="DEWorkspace",
                parameterType="Required",
                direction="Input"
            ),
            arcpy.Parameter(
                displayName="Ruta de salida",
                name="output_path",
                datatype="DEFolder",
                parameterType="Required",
                direction="Input"
            ),
            arcpy.Parameter(
                displayName="Conexión a base de datos de resultados",
                name="db_connection",
                datatype="GPString",
                parameterType="Required",
                direction="Input")
            ,
            arcpy.Parameter(
                displayName="DB Schema resultados",
                name="db_schema",
                datatype="GPString",
                parameterType="Required",
                direction="Input")
            ,
            arcpy.Parameter(
                displayName="DB Schema Filtro",
                name="filter_schema_name",
                datatype="GPString",
                parameterType="Required",
                direction="Input")
        ]
        return params
    
    def configLogging(self, logsFolder):
        try:
            print("configLogging")
            #os.system('CLS')
            today = datetime.date.today()
            logfile = os.path.join(logsFolder, "VALIDAR_GEODATABASE_LOG_"+str(today)+".log")
            print(logfile)
            logFormat = '%(asctime)s (%(name)s) %(levelname)s (%(module)s) -  %(message)s'
            logging.basicConfig(level=logging.DEBUG, format=logFormat, filename=logfile, filemode='a')
            #console = logging.StreamHandler()
            #formatter = logging.Formatter(logFormat)
            #console.setFormatter(formatter)
            #logging.getLogger().addHandler(console)
            logging.getLogger("requests").setLevel(logging.WARNING)
            logging.getLogger("urllib3").setLevel(logging.WARNING)
        except Exception as e:
            print(e)

    def execute(self, parameters, messages):
        sde_conn = parameters[0].valueAsText
        output_path = parameters[1].valueAsText
        db_connection = parameters[2].valueAsText
        schema_name = parameters[3].valueAsText
        filter_schema_name  = parameters[4].valueAsText

        arcpy.env.workspace = sde_conn
        arcpy.env.overwriteOutput = True

        self.configLogging(output_path)
        self.log_message("****************************************************************")
        self.log_message("  Inicio ")
        self.log_message("****************************************************************")
        msg = f'''  sde_conn: {sde_conn} 
                    output_path: {output_path}
                    db_connection: {db_connection} 
                    schema_name: {schema_name} 
                    filter_schema_name: {filter_schema_name} 
        '''
        self.log_message(msg )

        
        try:
            self.validar_geodatabase(sde_conn, output_path, db_connection, schema_name, filter_schema_name)
        except Exception as e:
            self.log_error(f"Error al validar: {e}")


        self.log_message("****************************************************************")
        self.log_message(" Fin ")
        self.log_message("****************************************************************")

     

    
    def log_message(self, message):
        logging.debug(message)
        #arcpy.AddMessage(message)
        print(message)
    
    def log_error(self, e):
        message = "Error : {0} ".format(e)
        logging.error(e, exc_info=True)
        logging.error(traceback.print_exc())
        print(traceback.print_exc())
        #arcpy.AddError(message)
        print(message)


    def validar_geodatabase(self, sde_conn, output_path, db_connection, schema_name, filter_schema_name):
        self.log_message("****************************************************************")
        self.log_message(f"validar_geodatabase - sde_conn: {sde_conn} - output_path: {output_path} - db_connection: {db_connection} - schema_name: {schema_name} - filter_schema_name: {filter_schema_name}")
        try:
            id_sesion = datetime.datetime.now().strftime("%Y_%m_%d_%H_%M")
            fecha = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            entorno = {
                "id_sesion": id_sesion,
                "fecha": fecha,
                "usuario": os.getlogin(),
                "sistema": platform.system(),
                "version_so": platform.version(),
                "python": platform.python_version(), 
                "sde_conn" : sde_conn,
                "filter_schema_name" : filter_schema_name,
                "output_path": output_path        }
            self.log_message(f"Entorno: {entorno}")
            engine = create_engine(db_connection)
            # Create a pandas DataFrame from the entorno dictionary
            df_entorno = pd.DataFrame([entorno])
            #df_entorno.to_csv(os.path.join(output_path, f"entorno_{id_sesion}.csv"), index=False)
            df_entorno.to_sql("validacion_sesiones", engine, schema=schema_name, if_exists="append", index=False)
            self.log_message(f"Se guardó registro de sesión en la base de datos: {entorno}")
            self.validar_conteo_registros(id_sesion, sde_conn, engine, schema_name, filter_schema_name)
            self.validar_integridad_sql(id_sesion, sde_conn, engine, schema_name, filter_schema_name)
            self.validar_dominios_rangos(id_sesion, sde_conn, engine, schema_name, filter_schema_name)
            self.validar_dominios(id_sesion, sde_conn, engine, schema_name, filter_schema_name)
            self.validar_geometrias(id_sesion, sde_conn, engine, schema_name, output_path, filter_schema_name)
            self.log_message("****************************************************************")
        except Exception as e:
            self.log_error(f"Error al validar: {e}")

        self.log_message(f"Validación completada ")
        self.log_message("****************************************************************")


    '''
    Validar geometrías 
    '''
    def validar_geometrias(self, id_sesion, sde_conn, engine, schema_name, output_path, filter_schema_name):
        self.log_message("****************************************************************")
        self.log_message(f"Validando Geometrías: {sde_conn}")
        arcpy.env.workspace = sde_conn

        # Obtener todas las tablas y feature classes
        schema_filter = f"*{filter_schema_name}*"
        fcs =  arcpy.ListFeatureClasses(schema_filter) 
        self.log_message(f"Cantidad total de tablas y features: {len(fcs)}")
        tipo = "GEOMETRÍA"

        # Crear una nueva File Geodatabase en el output_path
        gdb_name = f"ValidacionGeometria_{id_sesion}.gdb"
        gdb_path = os.path.join(output_path, gdb_name)
        if not arcpy.Exists(gdb_path):
            arcpy.management.CreateFileGDB(output_path, gdb_name)
            self.log_message(f"Se creó la File Geodatabase: {gdb_path}")
        else:
            self.log_message(f"La File Geodatabase ya existe: {gdb_path}")

        for fc in fcs:
            self.log_message(f"Validando geometría de: {fc}")
            try:
                resultados = []
                feature_name =  fc.split(".")[-1]
                # --- 1. Validar errores con CheckGeometry
                #local_xml  = os.path.join(output_path, f"export_{id_sesion}_{feature_name}.xml")
                local_feature =  gdb_path   + '/'   + feature_name 
                validate_feature =  gdb_path   + '/'   + feature_name +"_check"
                #self.log_message(f"local_xml: {local_xml}")
                self.log_message(f"local_feature: {local_feature}")
                self.log_message(f"validate_feature: {validate_feature}")

                # No funciona la importación desde xml por problema con el editor tracking 
                #source_feature = sde_conn+'/'+fc
                # self.log_message(f"Exportando a   {source_feature } a XML {local_xml} ")
                # arcpy.management.ExportXMLWorkspaceDocument( source_feature,   local_xml,   'DATA', 'BINARY', 'METADATA')
                # self.log_message(f"importando  XML {local_xml}  a  {gdb_path} ")
                # arcpy.management.ImportXMLWorkspaceDocument(gdb_path,  local_xml,  "DATA", "DEFAULTS")
                
                # Copiar la feature class a la geodatabase local
                self.log_message(f"Copiando {fc} a {local_feature}")
                arcpy.management.CopyFeatures(fc, local_feature)
                total_copiados = int(arcpy.GetCount_management(local_feature).getOutput(0))
                self.log_message(f"Se copiaron {total_copiados} registros a {local_feature}.")
                self.log_message(f"Ejecutando CheckGeometry en {local_feature}")
                arcpy.CheckGeometry_management(local_feature, validate_feature)
                errores_geom = int(arcpy.GetCount_management(validate_feature).getOutput(0))
                # Agregar errores encontrados por CheckGeometry
                if errores_geom > 0:
                    self.log_message(f"Se encontraron {errores_geom} errores de geometría en {fc}.")
                    descripcion = f"Table: {fc}"
                    with arcpy.da.SearchCursor(validate_feature, ["FEATURE_ID", "CLASS", "Problem"]) as cursor:
                        for row in cursor:
                            valor = f"Feature_ID : {row[0]} - Error: {row[2]} - CLASS: {row[1]}"
                            resultados.append([id_sesion, tipo, fc, descripcion, valor, feature_name, row[0] ])
                

                # # --- 2. Validar geometrías nulas (ya lo hace el CheckGeometry)
                # with arcpy.da.SearchCursor(fc, ["OID@", "SHAPE@"]) as cursor:
                #     for row in cursor:
                #         if row[1] is None:
                #             valor = f"Error: Geometría nula"
                #             resultados.append([id_sesion, tipo, fc, descripcion, valor, feature_name, row[0] ])

                
                # guardar datos
                if(len(resultados) > 0):
                    self.log_message(f"Se encontraron {len(resultados)} resultados de validación.")
                    df_resultados = pd.DataFrame(resultados, columns=["id_sesion", "tipo", "objeto", "descripcion", "valor", "tabla", "tabla_objectid"])
                    df_resultados.to_sql("validacion_resultados", engine, schema=schema_name, if_exists="append", index=False)
                self.log_message("***************************")
            except Exception as e:
                self.log_error(f"Error validando geometrías: {e}")
        self.log_message("***************************")
    

    '''
    Conteo de registros
    '''
    def validar_conteo_registros(self, id_sesion, sde_conn, engine, schema_name, filter_schema_name):
        self.log_message("****************************************************************")
        self.log_message(f"Validando Cantidad de registros cargados: {sde_conn} - filter_schema_name: {filter_schema_name}")
        arcpy.env.workspace = sde_conn

        # Obtener todas las tablas y feature classes
        schema_filter = f"*{filter_schema_name}*"
        self.log_message(f"schema_filter : {schema_filter}")
        elementos =  arcpy.ListTables(schema_filter) + arcpy.ListFeatureClasses(schema_filter) 
        self.log_message(f"Cantidad total de tablas y features: {len(elementos)}")

        tipo = "CONTEO REGISTROS"
        resultados = []
        for fc in elementos:
            self.log_message("***************************")
            self.log_message(f"Validando: {fc}")
            total_insertados = int(arcpy.GetCount_management(fc).getOutput(0))
            valor = f"Value: {total_insertados}"
            self.log_message(f"total_insertados: {total_insertados}")
            descripcion = f"Table: {fc}"
            #self.log_message(f"descripcion: {descripcion}")
            resultados.append([id_sesion, tipo, fc, descripcion, valor, fc, total_insertados ])
        
        # guardar datos
        if(len(resultados) > 0):
            self.log_message(f"Se encontraron {len(resultados)} resultados de validación.")
            df_resultados = pd.DataFrame(resultados, columns=["id_sesion", "tipo", "objeto", "descripcion", "valor", "tabla", "tabla_objectid"])
            df_resultados.to_sql("validacion_resultados", engine, schema=schema_name, if_exists="append", index=False)
        self.log_message("***************************")

    '''
    Validar dominiosrangos 
    '''
    def validar_dominios_rangos(self, id_sesion, sde_conn, engine, schema_name, filter_schema_name):
        self.log_message("****************************************************************")
        self.log_message(f"Validando Dominios tipo Rango: {sde_conn},  filter_schema_name: {filter_schema_name} ")
        arcpy.env.workspace = sde_conn

        try:
            # Obtener todos los dominios en la geodatabase
            schema_filter = f"*{filter_schema_name}*"
            dominios = arcpy.da.ListDomains()
            dominios_dict = {dom.name: dom for dom in dominios if dom.domainType == 'Range'}
            self.log_message(f"Cantidad total de Dominios tipo Range: {len(dominios_dict)}")

            # Obtener todas las tablas y feature classes
            elementos =  arcpy.ListTables(schema_filter) + arcpy.ListFeatureClasses(schema_filter) 
            self.log_message(f"Cantidad total de tablas y features: {len(elementos)}")
            
            tipo = "DOMINIOS_RANGOS"
            for fc in elementos:
                self.log_message("***************************")
                self.log_message(f"Validando: {fc}")
                fields = arcpy.ListFields(fc)
                resultados = []
                for f in fields:
                    if f.domain and f.domain in dominios_dict:
                        #print(f)
                        dominio = dominios_dict[f.domain]
                        #self.log_message(dominio.name)
                        valor_minimo = dominio.range[0]
                        valor_maximo = dominio.range[1]
                        
                        #self.log_message((valores_validos)
                        descripcion = f"Column: {f.name}"
                        self.log_message(f"descripcion: {descripcion}")
                        with arcpy.da.SearchCursor(fc, [f.name, "objectid"]) as cursor:
                            for row in cursor:
                                #print(row)
                                if row[0] is not None:
                                    value = int(row[0])
                                    if ( value < valor_minimo or value > valor_maximo):
                                        valor = f"Value: {value}  (min: {valor_minimo}  ,  max: {valor_maximo} )"
                                        resultados.append([id_sesion, tipo, dominio.name, descripcion, valor, fc, row[1] ])
                                
                # guardar datos
                if(len(resultados) > 0):
                    self.log_message(f"Se encontraron {len(resultados)} resultados de validación.")
                    df_resultados = pd.DataFrame(resultados, columns=["id_sesion", "tipo", "objeto", "descripcion", "valor", "tabla", "tabla_objectid"])
                    df_resultados.to_sql("validacion_resultados", engine, schema=schema_name, if_exists="append", index=False)
                self.log_message("***************************")
        except Exception as e:
            self.log_error(f"Error : {e}")
        self.log_message("****************************************************************")


    '''
    Validar dominios
    '''
    def validar_dominios(self, id_sesion, sde_conn, engine, schema_name, filter_schema_name):
        self.log_message("****************************************************************")
        self.log_message(f"Validando Dominios: {sde_conn},  filter_schema_name: {filter_schema_name} ")
        arcpy.env.workspace = sde_conn

        try:
            # Obtener todos los dominios en la geodatabase
            schema_filter = f"*{filter_schema_name}*"
            dominios = arcpy.da.ListDomains()
            dominios_dict = {dom.name: dom for dom in dominios if dom.domainType == 'CodedValue'}
            self.log_message(f"Cantidad total de Dominios: {len(dominios_dict)}")

            # Obtener todas las tablas y feature classes
            elementos =  arcpy.ListTables(schema_filter) + arcpy.ListFeatureClasses(schema_filter) 
            self.log_message(f"Cantidad total de tablas y features: {len(elementos)}")
            
            tipo = "DOMINIOS"
            for fc in elementos:
                self.log_message("***************************")
                self.log_message(f"Validando: {fc}")
                fields = arcpy.ListFields(fc)
                resultados = []
                for f in fields:
                    if f.domain and f.domain in dominios_dict:
                        #print(f)
                        dominio = dominios_dict[f.domain]
                        #self.log_message(dominio.name)
                        valores_validos = list(dominio.codedValues.keys())
                        #self.log_message((valores_validos)
                        descripcion = f"Column: {f.name}"
                        self.log_message(f"descripcion: {descripcion}")
                        with arcpy.da.SearchCursor(fc, [f.name, "objectid"]) as cursor:
                            for row in cursor:
                                #print(row)
                                if row[0] is not None and row[0] not in valores_validos:
                                    #registrar("Valor fuera de dominio", "Dominio", fc, f.name, row[0], row[1])
                                    valor = f"Value: {row[0]}"
                                    resultados.append([id_sesion, tipo, dominio.name, descripcion, valor, fc, row[1] ])
                                
                # guardar datos
                if(len(resultados) > 0):
                    self.log_message(f"Se encontraron {len(resultados)} resultados de validación.")
                    df_resultados = pd.DataFrame(resultados, columns=["id_sesion", "tipo", "objeto", "descripcion", "valor", "tabla", "tabla_objectid"])
                    df_resultados.to_sql("validacion_resultados", engine, schema=schema_name, if_exists="append", index=False)
                self.log_message("***************************")
        except Exception as e:
            self.log_error(f"Error : {e}")
        self.log_message("****************************************************************")



    '''
    Validar integridad referencial con SQL
    '''
    def validar_integridad_sql(self, id_sesion, sde_conn, engine, schema_name, filter_schema_name):
        self.log_message("****************************************************************")
        self.log_message("****************************************************************")
        self.log_message(f"Validando integridad referencial con SQL en: {sde_conn}")
        arcpy.env.workspace = sde_conn
        sql_exec = arcpy.ArcSDESQLExecute(sde_conn)

        #desc = arcpy.da.Describe(sde_conn)
        #self.log_message(f"Objeto DESC: \n  {desc   }")

        schema_filter = f"*{filter_schema_name}*"
        self.log_message(f"schema_filter:  {schema_filter} ")

        relaciones = self.listar_relationship_classes(filter_schema_name, sde_conn, schema_filter)
        self.log_message(f"Se encontraron {len(relaciones)} relaciones en la geodatabase.")
        self.log_message(f"relaciones:  {relaciones} ")
        
        if not relaciones:
            self.log_message("No se encontraron relaciones en la base de datos.")
            return

        # https://pro.arcgis.com/en/pro-app/latest/arcpy/functions/relationshipclass-properties.htm
        resultados = []
        tipo = "INTEGRIDAD REFERENCIAL"
        for rel_name in relaciones:
            try:
                self.log_message("****************************************************************")
                self.log_message(f"Validando relación:  {rel_name}.")
                desc = arcpy.Describe(rel_name)
                #self.log_message(f"desc:  {desc}.")

                origen = desc.originClassNames[0]
                destino = desc.destinationClassNames[0]
                cardinality = desc.cardinality
                #self.log_message(f"origen:  {origen}")
                #self.log_message(f"destino:  {destino}")
                #self.log_message(f"cardinality:  {cardinality}")
                #self.log_message(f"desc.originClassKeys:  {desc.originClassKeys}")
                #self.log_message(f"desc.destinationClassKeys:  {desc.destinationClassKeys}")
                #self.log_message("Destination Subtype Code: {}".format(desc.destinationSubtypeCode))

                pk = None
                fk = None
                for i in desc.originClassKeys:
                    key = i[1]
                    value = i[0]
                    if key == "OriginPrimary":
                        pk = value
                    if key == "OriginForeign":
                        fk = value

                descripcion = f"Src: {origen}, Dst: {destino}, FK: {fk} -> PK: {pk}, Card: {cardinality}."
                self.log_message(f"descripcion: {descripcion}")

                # Consulta SQL para encontrar registros huérfanos en la relación
                query = f"""
                    with a as (
                        SELECT  o.objectid,  o.{pk} as pk, d.objectid as foreign_objectid,  d.{fk} as foreign_fk 
                        FROM {origen} o  
                        RIGHT JOIN {destino} d      
                        ON o.{pk} = d.{fk}     ) 
                    select a.foreign_objectid, a.foreign_fk 
                    from a   WHERE a.foreign_fk is null or ( a.foreign_fk is not null  and  a.pk IS NULL  ) 
                """
                self.log_message(f"Ejecutando consulta SQL: {query}")
                
                resultados_query = sql_exec.execute(query)
                if resultados_query and isinstance(resultados_query, list):
                    for row in resultados_query:
                        valor = f"foreign_fk: {row[1]}"
                        resultados.append([id_sesion, tipo, rel_name, descripcion, valor, destino, row[0] ])
                else:
                    self.log_message(f"Relación: {rel_name} - OK. No se encontraron claves huérfanas.")
                    #resultados.append([id_sesion, tipo, subtipo, descripcion, "Ninguna" ])
            except Exception as e:
                self.log_error(f"Error en la relación {rel_name}: {e}")
                resultados.append([id_sesion, tipo, rel_name, "ERROR", str(e), None, None])

        try:
            # Convertir los resultados en un DataFrame de pandas
            if len(resultados) > 0:
                self.log_message(f"Se encontraron {len(resultados)} resultados de validación.")
                df_resultados = pd.DataFrame(resultados, columns=["id_sesion", "tipo", "objeto", "descripcion", "valor", "tabla", "tabla_objectid"])
                df_resultados['tabla_objectid'] = df_resultados['tabla_objectid'].fillna(-1).astype(int)
                df_resultados.to_sql("validacion_resultados", engine, schema=schema_name, if_exists="append", index=False)
        except Exception as e:
            self.log_error(f"Error : {e}")
        self.log_message("****************************************************************")
        self.log_message("****************************************************************")

    '''
    
    '''
    def listar_relationship_classes(self,user_schema, workspace, schema_filter):
        self.log_message("****************************************************************")
        self.log_message(f"listar_relationship_classes : {workspace}")
        self.log_message(f"user_schema: {user_schema}")
        arcpy.env.workspace = workspace
        rels = []
        elementos = arcpy.ListDatasets(schema_filter) or []  # incluye feature datasets
        elementos += arcpy.ListTables(schema_filter)
        elementos += arcpy.ListFeatureClasses(schema_filter)
        elementos += arcpy.ListFiles(schema_filter)

        for elem in elementos:
            self.log_message(f"elem: {elem}")

            ## TODO: filtrar por propietariod el schema
            if user_schema  not in elem:
                continue 

            full_path = os.path.join(workspace, elem)
            desc = arcpy.Describe(full_path)
            #self.log_message(f"elem desc : {desc}")
            #self.log_message(f"desc.relationshipClassNames: {desc.relationshipClassNames}")
            rel_class_names = desc.relationshipClassNames
            for r in rel_class_names:
                #self.log_message(f"relationshipClassNames: {r}")
                rels.append(r)
        
        self.log_message(f"total relationships: {len(rels)}")
        rels = list(set(rels))
        self.log_message(f"total relationships deduplicated: {len(rels)}")
        return rels

        
    

