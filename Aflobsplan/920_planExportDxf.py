''' PLAN EXPORT DXF '''
''' Eksportér til DXF '''
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
planScale = [%layout_map_scale_denom_calc%]
planOutputDir = r'[%export_dxf_path_calc%]'
planOutputName = '[%filnavn_calc%]'

themeLayers = []
themeLayersOrdered = []

processingLayers = []




''' START OF SCRIPT '''

if not planSelected_ == 1:
    iface.messageBar().pushMessage("Planen er ikke aktiveret", None, level=Qgis.Warning)

else:
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


        # iface.messageBar().pushMessage("Plan eksporteret til DXF", planOutput, level=Qgis.Info, duration=5)
        iface.messageBar().pushMessage("Plan eksporteret til DXF", f'<a href="file:///{planOutput}" target="_blank">{planOutput}</a>', level=Qgis.Success)



    for layer in themeLayers:
        layer.setSubsetString(None)

    QgsExpressionContextUtils.setProjectVariable(QgsProject.instance(), 'dxf_export', '0')
