''' PLAN EXPORT PDF '''
''' Eksportér til PDF '''
import processing
import os
from qgis.utils import (
    iface
)
from qgis.core import (
    QgsProject
    ,QgsExpressionContextUtils
)


''' PARAMETER SETTINGS '''

themeName = '03. Layout'
planSelected_ = [%selected_%]
planGuid = '[%guid%]'
planOutputDir = r'[%export_dxf_path_calc%]'
planOutputName = '[%filnavn_calc%]'

themeLayers = []

planLayerId = 'plan_v_planer_98ef2aaa_6475_4343_8e09_0c46c1981431'
atlasLayout = 'Atlas'




''' START OF SCRIPT '''

if not planSelected_ == 1:
    iface.messageBar().pushMessage("Planen er ikke aktiveret", None, level=Qgis.Warning)

else:
    themeCollection = QgsProject.instance().mapThemeCollection()
    themeState = themeCollection.mapThemeState(themeName)

    # Visible layers in theme
    visibleThemes = [theme for theme in themeState.layerRecords() if theme.isVisible is True]

    # Convert visible themes to actual layer list
    for theme in visibleThemes:
        themeLayers.append(theme.layer())




    # Filter Plan-layer
    planLayer = QgsProject.instance().mapLayer(planLayerId)
    if planLayer.isEditable():
        planLayerEditable = 1
        iface.vectorLayerTools().stopEditing(planLayer, False)
    else:
        planLayerEditable = 0
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


        # iface.messageBar().pushMessage("Plan eksporteret til PDF", planOutput, level=Qgis.Info, duration=5)
        planOutput = f'{planOutput}\{planOutputName}.pdf'
        iface.messageBar().pushMessage("Plan eksporteret til PDF", f'<a href="file:///{planOutput}" target="_blank">{planOutput}</a>', level=Qgis.Success)



    for layer in themeLayers:
        layer.setSubsetString(None)


    # Filter Plan-layer
    planLayer.setSubsetString(None)
    if planLayerEditable == 1:
        planLayer.startEditing()