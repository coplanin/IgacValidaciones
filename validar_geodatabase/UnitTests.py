#-*- coding: UTF-8 -*-

'''
Pruebas unitarias
http://cgoldberg.github.io/python-unittest-tutorial/
'''

import os
import arcpy
import unittest


AG_TOOLBOXES_PATH =  os.path.abspath(os.curdir) +"\\"


class ValidarTest(unittest.TestCase):

    def setUp(self):
        os.system('CLS')

    # @unittest.skip("testing skipping")
    def test_validar(self ):
        try:
            os.system('cls')
            print ("test_transform_fgdb - begin")
            arcpy.ImportToolbox(AG_TOOLBOXES_PATH+"ValidacionGeodatabase.pyt")
            ## entorno test
            # sde_conn = r"E:\juan.mendez\data\2025\egdb_conn_v2\colsmart_dev\egdb_colsmart_dev_colsmart_test5_owner.sde"
            # Entorno preprod
            #sde_conn = r"E:\juan.mendez\data\2025\egdb_conn_v2\colsmart_prod\egdb_colsmart_prod2_colsmart_preprod_migra.sde"
            sde_conn = r"E:\juan.mendez\data\2025\egdb_conn_v2\colsmart_prod\egdb_colsmart_prod2_colsmart_prod_owner.sde"
            #sde_conn = r"E:\juan.mendez\data\2025\egdb_conn_v2\colsmart_dev2\egdb_colsmart_dev01.sde"
            #filter_schema_name = "colsmart_preprod_migra"
            filter_schema_name = "colsmart_prod_owner"
            #filter_schema_name = "colsmart_dev01"
            output_path = r"E:\temp"
            db_results_conn_str = r"postgresql://colsmart_prod_indicadores:Q84Mr5P4dfc@172.19.1.61:5432/egdb_colsmart_prod"
            output_schema_name = "colsmart_prod_indicadores"  
            print ("test_transfotest_validarrm_fgdb - begin")
            print ("*****************************")
            result = arcpy.ValidarGeodatabase_validaciongdb(sde_conn,  output_path, db_results_conn_str, output_schema_name, filter_schema_name)
            print ("*****************************")
            print ("test_transfotest_validarrm_fgdb - end")
        except Exception as e:
            print (e)
            print (arcpy.GetMessages())

    
    def test_repair_iterativo(self ):
        try:
            os.system('cls')
            print ("test_repair_iterativo - begin")
            arcpy.ImportToolbox(AG_TOOLBOXES_PATH+"RepairGeometryIterativeToolbox.pyt")
            ## entorno test
            # sde_conn = r"E:\juan.mendez\data\2025\egdb_conn_v2\colsmart_dev\egdb_colsmart_dev_colsmart_test5_owner.sde"
            # Entorno preprod
            fgdb_path = r"C:\tmp\ValidacionGeometria_2025_06_17_11_30.gdb"
            output_path = r"c:\tmp"
            max_iterations = 10
            ignore_features = "ILC_Predio"
            delete_null = True
            print ("test_repair_iterativo - begin")
            print ("*****************************")
            result = arcpy.RepairGeometryIterative_GeometryRepair(fgdb_path,  output_path, max_iterations, ignore_features, delete_null )
            print ("*****************************")
            print ("test_repair_iterativo - end")
        except Exception as e:
            print (e)
            print (arcpy.GetMessages())


''' //////////////////////////////////////////////////////////////////////////////////////////// '''
''' //////////////////////////////////////////////////////////////////////////////////////////// '''
if __name__ == '__main__':
    unittest.main()
''' //////////////////////////////////////////////////////////////////////////////////////////// '''
''' //////////////////////////////////////////////////////////////////////////////////////////// '''
