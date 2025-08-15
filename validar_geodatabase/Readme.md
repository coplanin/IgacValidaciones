# Toolbox para Validar geodatabase


## Prerrequisitos

Clonar entorno de Python en Arcgis Pro

Instalar librerías adicionales en el entorno clonado:
- psycopg2

psycopg2-binary


## Ejecución

### A través de prueba unitaria

```bash
cd E:\juan.mendez\unidad_d\juan.mendez\git\validaciones\validar_geodatabase\
"C:\Users\juan.mendez\AppData\Local\ESRI\conda\envs\arcgispro-py3-clone-35\python" UnitTests.py  ValidarTest.test_validar 


cd  C:\opt\work\igac\git\validaciones\validar_geodatabase\
"C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\python"  Exportar_dominios.py

cd  C:\opt\work\igac\git\validaciones\validar_geodatabase\
"C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\python"  UnitTests.py  ValidarTest.test_repair_iterativo 

```
