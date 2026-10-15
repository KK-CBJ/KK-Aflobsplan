''' PLAN ROTATE CANVAS '''
''' Rotér kort '''
from qgis.utils import (
    iface
)


''' PARAMETER SETTINGS '''

canvasRotation = -[%layout_rotation%]




''' START OF SCRIPT '''

iface.mapCanvas().setRotation(canvasRotation)
iface.mapCanvas().refreshAllLayers()