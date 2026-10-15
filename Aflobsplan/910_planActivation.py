''' PLAN ACTIVATION '''
''' Aktivering af plan '''
import psycopg2
from qgis.utils import (
    iface
)
from qgis.core import (
    QgsProject
)


''' PARAMETER SETTINGS '''

layerId = '[%@layer_id%]'
planGuid = '[%guid%]'
planAktivering = 1
# 1: Aktivér kun denne plan
# 2: Tilføj til aktive planer
# 3: Deaktivér plan

lstPlanAktivering = [
        ["planAktivering", "Tekst"]
        ,["1", "Plan aktiveret"]
        ,["2", "Plan tilføjet til aktive planer"]
        ,["3", "Plan deaktiveret"]
    ]

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
			UPDATE aflob_plan.v_lst_settings_user
				SET
					plan_guids = (
						SELECT
							array_agg(a.guid)::text
						FROM (
							SELECT
								'{planGuid}'::uuid AS guid
							WHERE {planAktivering} BETWEEN 1 AND 2

							UNION

							SELECT
								u.guid
							FROM aflob_plan.v_lst_settings_user s
								,UNNEST(s.plan_guids::uuid[]) u(guid)
							WHERE {planAktivering} = 2
								OR (
									{planAktivering} = 3
									AND u.guid != '{planGuid}'::uuid
								)
						) a
					);
    '''


    dbCursor.execute(dbSql)
    dbConnection.commit()



    # iface.messageBar().pushMessage(lstPlanAktivering[planAktivering][1], None, level=Qgis.Info, duration=5)

    QgsProject.instance().mapLayer('plan_v_planer_98ef2aaa_6475_4343_8e09_0c46c1981431').reload()

    QgsProject.instance().mapLayer('plan_v_indhold_plan_label_p_077883b3_e42a_418a_a78a_c0561185d65e').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_plan_p_d0ba31a3_d4c1_42ad_b1e4_a14a3d62cda1').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_plan_l_1b02850b_0a3e_4a67_ae18_e6b0ecc5ef8c').reload()
    QgsProject.instance().mapLayer('plan_v_indhold_plan_a_1e141cee_f051_48c8_bf70_d40a3bb2b373').reload()

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
