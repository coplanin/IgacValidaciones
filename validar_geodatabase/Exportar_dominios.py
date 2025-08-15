import arcpy
import os
import pandas as pd
import logging
import datetime

sde_conn = r"C:\opt\work\igac\data\egdb_conn\colsmart_prod\egdb_colsmart_prod2_colsmart_preprod.sde"
arcpy.env.workspace = sde_conn
output_folder = "C:/tmp/"  # Ruta del archivo Excel de salida
output_excel  = "C:/opt/work/igac/data/Colsmart_Dominios.xlsx"  # Ruta del archivo Excel de salida
filter_schema_name = "colsmart_preprod_migra"
schema_filter = f"*{filter_schema_name}*"


def exportar_dominios(output_excel):
    logging.debug("******************************************************************************")
    logging.info("Exportando dominios")
    # Lista todos los dominios en la geodatabase
    sheet_name = "Dominios"  # Nombre de la hoja en el archivo Excel
    domains = arcpy.da.ListDomains(arcpy.env.workspace)

    values = []

    for domain in domains:
        logging.debug(f"Domain name: {domain.name}")
        
        if domain.domainType == "CodedValue":
            coded_values = domain.codedValues
            
            for val, desc in coded_values.items():
                logging.debug(f"{val} : {desc}")
                value = { "domain":domain.name, "code": val, "desc": desc, "type": "CodedValue" }
                values.append(value)
        
        elif domain.domainType == "Range":
            logging.debug(f"Min: {domain.range[0]}")
            logging.debug(f"Max: {domain.range[1]}")
            value = { "domain": domain.name, "range_min": domain.range[0], "range_max": domain.range[1],  "type": "Range" }
            values.append(value)

    logging.debug(f"Total de dominios encontrados: {len(values)}")
    #logging.debug(values)

    # Itera sobre
    df = pd.DataFrame(values)
    logging.debug(f"Exportando a {output_excel}")
    logging.debug(f"Sheet name: {sheet_name}")
    with pd.ExcelWriter(output_excel, mode='a', if_sheet_exists='replace') as writer:
        df.to_excel(writer, sheet_name=sheet_name, index=False)
    logging.debug("******************************************************************************")    


def exportar_dominios_tablas(output_excel, schema_filter):
    logging.debug("******************************************************************************")
    logging.info("Exportando dominios de las tablas")
    sheet_name = "Dominios_tablas"  # Nombre de la hoja en el archivo Excel
    dominios = {}
    # Lista todos los dominios en la geodatabase
    domains = arcpy.da.ListDomains(arcpy.env.workspace)
    for domain in domains:
        dominios[domain.name] = { "dom":domain.name, "type" : domain.domainType }
    
    logging.debug(f"Cantidad de dominios encontrados: {len(dominios)}")
    #logging.debug(f"Dominios encontrados: {dominios} " )

    elementos =  arcpy.ListTables(schema_filter) + arcpy.ListFeatureClasses(schema_filter) 
    #logging.debug(f"Cantidad total de tablas y features: {len(elementos)}")

    values = []
    for fc in elementos:
        logging.debug(f"Validando: {fc}")
        fields = arcpy.ListFields(fc)
        resultados = []
        for f in fields:
            if f.domain: # and f.domain in dominios:
                domain = dominios[f.domain]
                value = { "feature": fc,  "field":f.name , "domain": f.domain, "type": domain["type"] }
                values.append(value)

    logging.debug(f"Total de campos relacionados con dominios: {len(values)}")
    logging.debug(values)

    df = pd.DataFrame(values)
    logging.debug(f"Exportando a {output_excel}")
    logging.debug(f"Sheet name: {sheet_name}")
    with pd.ExcelWriter(output_excel, mode='a', if_sheet_exists='replace') as writer:
        df.to_excel(writer, sheet_name=sheet_name, index=False)
    logging.debug("******************************************************************************")


def configLogging(logsFolder):
        try:
            print("configLogging")
            #os.system('CLS')
            today = datetime.date.today()
            logfile = os.path.join(logsFolder, "Vexportar_dominios_"+str(today)+".log")
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

if __name__ == "__main__":
    # Configure logging
    configLogging(output_folder)
    logging.debug("******************************************************************************")
    logging.debug("Iniciando exportacion de dominios")
    exportar_dominios(output_excel)
    exportar_dominios_tablas(output_excel,  schema_filter)
    logging.debug("Finalizando exportacion de dominios")
    logging.debug("******************************************************************************")
