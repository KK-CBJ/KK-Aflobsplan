''' RENAME NODES '''
''' Omdøb knuder '''
import psycopg2
import os
from qgis.utils import (
    iface
)
from qgis.core import (
    QgsProject
)


''' PARAMETER SETTINGS '''

layerId = '[%@layer_id%]'


planSelected_ = [%selected_%]
planGuid = '[%guid%]'


layer = QgsProject.instance().mapLayer(layerId)
layerUri = layer.dataProvider().uri()
layerUriHost = layerUri.host()
layerUriPort = layerUri.port()
layerUriDatabase = layerUri.database()
layerUriUser = (os.environ['USERNAME']).lower()
layerUriPw = ''




''' START OF SCRIPT '''

if not planSelected_ == 1:
    iface.messageBar().pushMessage("Planen er ikke aktiveret", None, level=Qgis.Warning)

else:

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
        dbSql = rf'''
            WITH

                cte1 AS(
                    SELECT DISTINCT
                        i.aflob_guid
                        ,k.guid
                    FROM aflob_plan.f_indhold_p i
                    INNER JOIN aflob_plan.v_planer p ON p.guid = i.plan_guid
                        AND p.selected_ = 1
                    LEFT JOIN aflob.f_knuder_p k ON k.guid = i.aflob_guid
                    WHERE i.aflob_tbl = 'f_knuder_p'
                        AND COALESCE(k.navn, i.aflob_navn) !~* '^KK\d+$|^\d+$'
                        AND (
                            k.guid IS NOT NULL
                            OR i.label_show IS DISTINCT FROM 0
                        )
                        AND i.plan_guid = $${planGuid}$$
                )

                ,upt_kn AS(
                    UPDATE aflob.f_knuder_p k
                        SET
                            navn = NULL
                    FROM cte1 c
                    WHERE k.guid = c.guid
                    RETURNING k.guid, k.navn

            --        SELECT
            --            k.guid
            --            ,'KK851' || ROW_NUMBER() OVER() AS navn
            --        FROM cte1 c
            --            ,aflob.f_knuder_p k
            --        WHERE k.guid = c.guid
                )

                ,upt_lbl_1 AS(
                    UPDATE aflob_plan.f_indhold_p i
                        SET
                            label = regexp_replace(label, '(^|\s|\n)' || i.aflob_navn || '($|\s|\n)', '\1' || k.navn ||'\2', 'g')
                            ,aflob_navn = k.navn
                    FROM upt_kn k
                    WHERE i.aflob_guid = k.guid
                    RETURNING aflob_guid
                )

                ,upt_lbl_2 AS(
                    UPDATE aflob_plan.f_indhold_p i
                        SET
                            label_show = 0
                    FROM cte1 c
                    WHERE i.aflob_guid = c.aflob_guid
                        AND c.guid IS NULL
                        AND i.label_show IS DISTINCT FROM 0
                    RETURNING i.aflob_guid
                )


            SELECT
                SUM(ct_)
            FROM (
					SELECT
						COUNT(*) AS ct_
					FROM upt_lbl_1
					UNION ALL
					SELECT
						COUNT(*) AS ct_
					FROM upt_lbl_2
				) a;
                '''


        dbCursor.execute(dbSql)
        dbConnection.commit()


        dbResult = dbCursor.fetchone()
        dbResultCount = dbResult[0]


        iface.messageBar().pushMessage("Knuder omdøbt", str(dbResultCount), level=Qgis.Info, duration=5)
        iface.mapCanvas().refreshAllLayers()


    except psycopg2.Error as e:
        print(e.pgerror)
        iface.messageBar().pushMessage("Fejl", e.pgerror, level=Qgis.Warning)


    finally:
        dbCursor.close()
        dbConnection.close()