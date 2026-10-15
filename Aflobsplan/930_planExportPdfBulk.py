''' PLAN EXPORT PDF BULK '''
''' Eksportér til PDF (Alle aktive planer) '''
import psycopg2
import os
import processing
from qgis.utils import (
    iface
)
from qgis.core import (
    QgsProject
)


''' PARAMETER SETTINGS '''

layerId = '[%@layer_id%]'


layer = QgsProject.instance().mapLayer(layerId)
layerUri = layer.dataProvider().uri()
layerUriHost = layerUri.host()
layerUriPort = layerUri.port()
layerUriDatabase = layerUri.database()
layerUriUser = (os.environ['USERNAME']).lower()
layerUriPw = ''


themeName = '03. Layout'

themeLayers = []

planLayerId = 'plan_v_planer_98ef2aaa_6475_4343_8e09_0c46c1981431'
atlasLayout = 'Atlas'




''' START OF SCRIPT '''

themeCollection = QgsProject.instance().mapThemeCollection()
themeState = themeCollection.mapThemeState(themeName)

# Visible layers in theme
visibleThemes = [theme for theme in themeState.layerRecords() if theme.isVisible is True]

# Convert visible themes to actual layer list
for theme in visibleThemes:
    themeLayers.append(theme.layer())




    # Prepare filter for Plan-layer
    planLayer = QgsProject.instance().mapLayer(planLayerId)
    if planLayer.isEditable():
        planLayerEditable = 1
        iface.vectorLayerTools().stopEditing(planLayer, False)
    else:
        planLayerEditable = 0








dbConnection = psycopg2.connect(
    host=layerUriHost
    ,port=layerUriPort
    ,database=layerUriDatabase
    ,user=layerUriUser
    ,password=layerUriPw
)

dbCursor = dbConnection.cursor()


try:
    # Selected plans
    dbSql = f'''
        SELECT
            guid
            ,export_dxf_path_calc
        FROM aflob_plan.v_planer
        WHERE selected_ = 1
            '''


    dbCursor.execute(dbSql)
    dbConnection.commit()


    dbResult = dbCursor.fetchall()



    if dbResult == []:
        iface.messageBar().pushMessage("Ingen aktive planer fundet", None, level=Qgis.Warning)

    # Plans found, continue
    else:

        for i in dbResult:

            planOutput = None

            planGuid = i[0]
            planOutputDir = i[1]


            planLayer.setSubsetString(f'guid = \'{planGuid}\'')




            # Use layer theme
            for layer in themeLayers:

                # Set subset
                layer.setSubsetString(f'plan_guid = \'{planGuid}\'')


            if planOutputDir == '' or not(os.path.exists(os.path.normpath(planOutputDir))):
                planOutputDir = r'C:\tmp'
                if not(os.path.exists(os.path.normpath(planOutputDir))):
                    os.mkdir(os.path.normpath(planOutputDir))

            if not(os.path.exists(os.path.normpath(planOutputDir))):
                iface.messageBar().pushMessage("Mappe kan ikke findes", planOutputDir, level=Qgis.Warning)
            else:
                planOutput = f'{planOutputDir}'


                processing.run(
                    "native:atlaslayouttomultiplepdf"
                    ,{
                        'LAYOUT':atlasLayout
                        ,'COVERAGE_LAYER':None
                        ,'FILTER_EXPRESSION':''
                        ,'SORTBY_EXPRESSION':''
                        ,'SORTBY_REVERSE':False
                        ,'LAYERS':None
                        ,'DPI':None
                        ,'FORCE_VECTOR':False
                        ,'FORCE_RASTER':False
                        ,'GEOREFERENCE':True
                        ,'INCLUDE_METADATA':True
                        ,'DISABLE_TILED':False
                        ,'SIMPLIFY':True
                        ,'TEXT_FORMAT':0
                        ,'IMAGE_COMPRESSION':0
                        ,'OUTPUT_FILENAME':''
                        ,'OUTPUT_FOLDER':os.path.normpath(planOutput)
                    }
                )


        for layer in themeLayers:
            layer.setSubsetString(None)


        # Filter Plan-layer
        planLayer.setSubsetString(None)
        if planLayerEditable == 1:
            planLayer.startEditing()


        iface.messageBar().pushMessage("Planer eksporteret til PDF", None, level=Qgis.Success, duration=5)


except psycopg2.Error as e:
    print(e.pgerror)
    iface.messageBar().pushMessage("Fejl", e.pgerror, level=Qgis.Warning)


finally:
    dbCursor.close()
    dbConnection.close()