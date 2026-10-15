''' PLAN EXPORT DXF BULK '''
''' Eksportér til DXF (Alle aktive planer) '''
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
themeLayersOrdered = []




''' START OF SCRIPT '''

QgsExpressionContextUtils.setProjectVariable(QgsProject.instance(), 'dxf_export', '1')

themeCollection = QgsProject.instance().mapThemeCollection()
themeState = themeCollection.mapThemeState(themeName)

# Visible layers in theme
visibleThemes = [theme for theme in themeState.layerRecords() if theme.isVisible is True]

# Convert visible themes to actual layer list
for theme in visibleThemes:
    themeLayers.append(theme.layer())

# Use master layer order
for layer in themeCollection.masterLayerOrder():
    # If layer is present in theme, add to list
    if layer in themeLayers:
        themeLayersOrdered.append(layer)








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
            ,layout_map_scale_denom_calc
            ,export_dxf_path_calc
            ,filnavn_calc
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

            processingLayers = []
            planOutput = None

            planGuid = i[0]
            planScale = i[1]
            planOutputDir = i[2]
            planOutputName = i[3]




            # Use layer order
            for layer in themeLayersOrdered:

                # Set subset
                layer.setSubsetString(f'plan_guid = \'{planGuid}\'')

                # Insert position 0 for correct order in output
                processingLayers.insert(
                    0
                    ,{
                        'layer': layer.dataProvider().uri().uri()
                        ,'attributeIndex': -1
                        ,'overriddenLayerName': ''
                        ,'buildDataDefinedBlocks': True
                        ,'dataDefinedBlocksMaximumNumberOfClasses': -1
                    }
                )


            if planOutputDir == '' or not(os.path.exists(os.path.normpath(planOutputDir))):
                planOutputDir = r'C:\tmp'
                if not(os.path.exists(os.path.normpath(planOutputDir))):
                    os.mkdir(os.path.normpath(planOutputDir))

            if not(os.path.exists(os.path.normpath(planOutputDir))):
                iface.messageBar().pushMessage("Mappe kan ikke findes", planOutputDir, level=Qgis.Warning)
            else:
                planOutput = f'{planOutputDir}\{planOutputName}.dxf'


                processing.run(
                    "native:dxfexport"
                    ,{
                        'LAYERS':processingLayers
                        ,'SYMBOLOGY_MODE':2
                        ,'SYMBOLOGY_SCALE':planScale
                        ,'MAP_THEME':themeName
                        ,'ENCODING':'ISO-8859-1'
                        ,'CRS':QgsCoordinateReferenceSystem('EPSG:25832')
                        ,'EXTENT':None
                        ,'SELECTED_FEATURES_ONLY':False
                        ,'USE_LAYER_TITLE':False
                        ,'FORCE_2D':False
                        ,'MTEXT':True
                        ,'EXPORT_LINES_WITH_ZERO_WIDTH':False
                        ,'OUTPUT':os.path.normpath(planOutput)
                    }
                )


        for layer in themeLayers:
            layer.setSubsetString(None)


        QgsExpressionContextUtils.setProjectVariable(QgsProject.instance(), 'dxf_export', '0')

        iface.messageBar().pushMessage("Planer eksporteret til DXF", None, level=Qgis.Success, duration=5)


except psycopg2.Error as e:
    print(e.pgerror)
    iface.messageBar().pushMessage("Fejl", e.pgerror, level=Qgis.Warning)


finally:
    dbCursor.close()
    dbConnection.close()