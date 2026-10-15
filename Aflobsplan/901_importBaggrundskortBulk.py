''' IMPORT BAGGRUNDSKORT BULK '''
''' Genindlæs baggrundskort (Alle aktive planer) '''
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

                PERFORM aflob_plan.import_clear(i.guid, 1);
                PERFORM aflob_plan.import(i.guid, 1);

            END LOOP;

        END $BODY$;
            '''


    dbCursor.execute(dbSql)
    dbConnection.commit()



    iface.messageBar().pushMessage("Baggrundskort genindlæst", None, level=Qgis.Info, duration=5)

    QgsProject.instance().mapLayer('plan_v_indhold_baggrundskort_label_p_e8a0dbd4_6dea_435c_900c_cafc7649481a').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_baggrundskort_p_dabb84da_274c_4c97_9ff1_e636630e5f13').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_baggrundskort_l_e5df8fb3_9087_46b1_8b50_fac9244496ba').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_baggrundskort_a_9c1e6f6d_e4a0_4e2c_a6c1_df13e8c172c0').reload()

except psycopg2.Error as e:
    print(e.pgerror)
    iface.messageBar().pushMessage("Fejl", e.pgerror, level=Qgis.Warning)


finally:
    dbCursor.close()
    dbConnection.close()
