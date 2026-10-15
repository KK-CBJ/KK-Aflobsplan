''' IMPORT PLAN BULK '''
''' Genindlæs planer (Alle aktive planer) '''
import psycopg2
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




''' START OF SCRIPT '''

dbConnection = psycopg2.connect(
    host=layerUriHost
    ,port=layerUriPort
    ,database=layerUriDatabase
    ,user=layerUriUser
    ,password=layerUriPw
)

dbCursor = dbConnection.cursor()


try:
    # Import
    dbSql = f'''
        DO $BODY$

        DECLARE

            i record;

        BEGIN

            FOR i IN
                SELECT
                    guid
                FROM aflob_plan.v_planer p
                WHERE p.selected_ = 1
            LOOP

                PERFORM aflob_plan.import_clear(i.guid);
                PERFORM aflob_plan.import(i.guid);

            END LOOP;

        END $BODY$;
            '''


    dbCursor.execute(dbSql)
    dbConnection.commit()



    iface.messageBar().pushMessage("Planer genindlæst", None, level=Qgis.Info, duration=5)

    QgsProject.instance().mapLayer('plan_v_indhold_plan_label_p_077883b3_e42a_418a_a78a_c0561185d65e').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_plan_p_d0ba31a3_d4c1_42ad_b1e4_a14a3d62cda1').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_plan_l_1b02850b_0a3e_4a67_ae18_e6b0ecc5ef8c').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_plan_a_1e141cee_f051_48c8_bf70_d40a3bb2b373').reload()


except psycopg2.Error as e:
    print(e.pgerror)
    iface.messageBar().pushMessage("Fejl", e.pgerror, level=Qgis.Warning)


finally:
    dbCursor.close()
    dbConnection.close()
