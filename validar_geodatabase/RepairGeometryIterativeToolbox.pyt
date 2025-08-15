import arcpy
import os, traceback
import datetime
import logging

class Toolbox(object):
    def __init__(self):
        """Define las propiedades de la toolbox."""
        self.label = "Geometry Repair Toolbox"
        self.alias = "GeometryRepair"
        self.tools = [RepairGeometryIterative]

class RepairGeometryIterative(object):
    def __init__(self):
        """Define las propiedades de la herramienta."""
        self.label = "Repair Geometry Iterative"
        self.description = "Repara geometrías de una clase de entidad de forma iterativa hasta que no se detecten errores o se alcance el número máximo de iteraciones."
        self.canRunInBackground = True

    def getParameterInfo(self):
        """Define los parámetros de la herramienta."""
        # Parámetro 1: Clase de entidad de entrada
        param0 = arcpy.Parameter(
                displayName="Ruta de la Geodatabase",
                name="gdb_path",
                datatype="DEWorkspace",
                parameterType="Required",
                direction="Input"
            )

        # Parámetro 2: Espacio de trabajo de salida
        param1 = arcpy.Parameter(
                displayName="Ruta de salida",
                name="output_path",
                datatype="DEFolder",
                parameterType="Required",
                direction="Input"
            )

        # Parámetro 3: Número máximo de iteraciones
        param2 = arcpy.Parameter(
            displayName="Maximum Iterations",
            name="max_iterations",
            datatype="GPLong",
            parameterType="Required",
            direction="Input"
        )
        param2.value = 5  # Valor por defecto

        # Parámetro 4: Features a ignorar
        param3 = arcpy.Parameter(
            displayName="Features a ignorar",
            name="ignore_features", 
            datatype="GPString",
            parameterType="Optional",
            direction="Input"
        )
        param3.value = " "  # Valor por defecto, cadena vacía significa que no se ignora ninguna feature

        # Parámetro 5: Eliminar geometrias nulas
        param4 = arcpy.Parameter(
            displayName="Eliminar geometrias nulas",
            name="delete_null",
            datatype="GPBoolean", 
            parameterType="Required",
            direction="Input"
        )
        param4.value = True  # Valor por defecto

        return [param0, param1, param2, param3, param4]

    def isLicensed(self):
        """Verifica si la licencia permite ejecutar la herramienta."""
        return True

    def updateParameters(self, parameters):
        """Modifica los parámetros antes de la ejecución."""
        return

    def updateMessages(self, parameters):
        """Agrega mensajes de validación para los parámetros."""
        if parameters[2].value is not None and parameters[2].value < 1:
            parameters[2].setErrorMessage("El número máximo de iteraciones debe ser mayor que 0.")
        return
    
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

    def execute(self, parameters, messages):
        """Ejecuta la lógica de la herramienta."""
        fgdb_path = parameters[0].valueAsText
        output_path = parameters[1].valueAsText
        max_iterations = int(parameters[2].value)
        ignore_features = parameters[3].valueAsText
        delete_null = parameters[4].value
        
        self.configLogging(output_path)
        self.log_message("****************************************************************")
        self.log_message("  Inicio ")
        self.log_message("****************************************************************")
        self.log_message(f"fgdb_path: {fgdb_path}")
        self.log_message(f"output_path: {output_path}")
        self.log_message(f"max_iterations: {max_iterations}")
        self.log_message(f"ignore_features: {ignore_features}")
        self.log_message(f"delete_null: {delete_null}")
        ignore_features_list = ignore_features.split(",")
        self.log_message(f"ignore_features_list: {ignore_features_list}")

        null_policy = "DELETE_NULL" if delete_null else "KEEP_NULL"
        self.log_message(f"null_policy: {null_policy}")
        
        try:
            # Configurar el entorno
            arcpy.env.workspace = fgdb_path
            arcpy.env.overwriteOutput = True
            arcpy.env.parallelProcessingFactor = "80%"

            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            self.log_message(f"Timestamp: {timestamp}")
            
            self.log_message("Obteniendo listado de los features contenidos en la plantilla...")
            datasets_list = []
            fcs = []
            try:
                datasets = arcpy.ListDatasets("*", "Feature")
                for dataset in datasets:
                    self.log_message("***********************************************************************************************")
                    self.log_message("Dataset:  {} ".format(dataset))
                    datasets_list.append(dataset)
                    for fc in arcpy.ListFeatureClasses(feature_dataset=dataset):
                        self.log_message("fc:  {} ".format(fc))
                        fcs.append(  {"dataset": dataset, "feature": fc }   )

                for fc in arcpy.ListFeatureClasses(feature_dataset="" ):
                    self.log_message("***********************************************************************************************")
                    self.log_message("fc:  {} ".format(fc))
                    fcs.append(  {"dataset": "", "feature": fc }   )
            except Exception as e:
                self.log_error(e)

            self.log_message("****************************************************************")


            self.log_message(f"Cantidad total de  features: {len(fcs)}")

            for row in fcs:
                try:
                    self.log_message("****************************************************************")
                    self.log_message(f"Reparando geometría de: {row} ")
                    
                    target_ds = row["dataset"]
                    fc = row["feature"]

                    feature_path = ""

                    if target_ds == "":
                        feature_path = fgdb_path + '/'  + fc 
                    else:
                        feature_path = fgdb_path  + '/' + target_ds   + '/'  + fc 

                    self.log_message(f"feature_path:  {feature_path} ")

                    if fc in ignore_features_list:
                        self.log_message(f"Feature {fc} en la lista de features a ignorar. Se omite.")
                        continue
                    errors_found = True
                    check_output = ""
                    for iteration in range(max_iterations):
                        self.log_message(f"Reparando geometría de: {fc} - Iteración: {iteration}")

                        targetCountFeatures = int(arcpy.GetCount_management(feature_path).getOutput(0))
                        self.log_message("Cantidad de datos antes de repair:  {} ".format( targetCountFeatures))

                        # Nombre para la tabla de salida de Check Geometry
                        check_output = os.path.join(fgdb_path, f"CheckGeometry_{fc}_{timestamp}_{iteration}")
                        self.log_message(f"check_output: {check_output}")
                        # Verificar si hay errores geométricos con Check Geometry
                        arcpy.CheckGeometry_management(feature_path, check_output)

                        targetCountFeatures = int(arcpy.GetCount_management(feature_path).getOutput(0))
                        self.log_message("Cantidad de datos después de repair:  {} ".format( targetCountFeatures))

                        # Contar el número de registros en la tabla de resultados
                        error_count = int(arcpy.GetCount_management(check_output)[0])
                        if error_count == 0:
                            self.log_message("No se detectaron más errores geométricos. Proceso finalizado.")
                            errors_found = False
                            break
                        else:
                            self.log_message(f"Se encontraron {error_count} errores geométricos. ")
                            # Ejecutar Repair Geometry
                            self.log_message(f"Reparando geometría de: {fc} - Iteración: {iteration}... ")
                            arcpy.RepairGeometry_management(feature_path, null_policy, "ESRI")
                            self.log_message(f"Fin reparación  geometría. ")


                    if  errors_found:
                        self.log_error(f"Se alcanzó el máximo de iteraciones ({max_iterations}). Algunos errores pueden persistir.")
                        self.log_error(f"Revisa la tabla de resultados en: {check_output}")
                    
                    self.log_message("****************************************************************")
                except Exception as e:
                    self.log_error(f"Error : {e}")

        except arcpy.ExecuteError as e:
            self.log_error(f"Error en la ejecución: {e}")
        except Exception as e:
            self.log_error(f"Error inesperado: {e}")

        self.log_message("****************************************************************")
        self.log_message("  Fin ")
        self.log_message("****************************************************************")