/* DROP FUNCTION IF EXISTS aflob_plan.import_clear(
	_plan_guid uuid
	,_baggrundskort integer
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.import_clear(
	_plan_guid uuid
	,_baggrundskort integer DEFAULT 0
)
	RETURNS VOID
	VOLATILE
	STRICT
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF _baggrundskort = 1 THEN

		DELETE FROM aflob_plan.f_indhold_p i
			WHERE i.plan_guid = _plan_guid
				AND i.gruppe = 'Baggrundskort';

		DELETE FROM aflob_plan.f_indhold_l i
			WHERE i.plan_guid = _plan_guid
				AND i.gruppe = 'Baggrundskort';

		DELETE FROM aflob_plan.f_indhold_a i
			WHERE i.plan_guid = _plan_guid
				AND i.gruppe = 'Baggrundskort';

	ELSE

		DELETE FROM aflob_plan.f_indhold_p i
			WHERE i.plan_guid = _plan_guid
				AND NOT(i.gruppe = 'Baggrundskort');

		DELETE FROM aflob_plan.f_indhold_l i
			WHERE i.plan_guid = _plan_guid
				AND NOT(i.gruppe = 'Baggrundskort');

		DELETE FROM aflob_plan.f_indhold_a i
			WHERE i.plan_guid = _plan_guid
				AND NOT(i.gruppe = 'Baggrundskort');

	END IF;

END $BODY$;



/* DROP FUNCTION IF EXISTS aflob_plan.import(
	_plan_guid uuid
	,_baggrundskort integer
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.import(
	_plan_guid uuid
	,_baggrundskort integer DEFAULT 0
)
	RETURNS VOID
	VOLATILE
	STRICT
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	i record;

	_layout_frame geometry('MULTIPOLYGON', 25832);
	_layout_frame_buffer geometry('MULTIPOLYGON', 25832);

	_import_guid uuid;

BEGIN

	SELECT
		p.layout_frame
		,ST_Multi(ST_Buffer(p.layout_frame, 5, 'quad_segs=2'))
	FROM aflob_plan.v_planer p
	WHERE p.guid = _plan_guid
	INTO _layout_frame
		,_layout_frame_buffer;

	IF _layout_frame IS NULL THEN

		RAISE EXCEPTION 'Ingen plan fundet';

	END IF;

	IF _baggrundskort = 1 THEN

		SELECT
			im_baggrund.guid
		FROM aflob_plan.v_planer p
		INNER JOIN aflob_plan.lst_import im ON im.guid = p.import_guid_calc
			AND im.aktiv = 1
		INNER JOIN aflob_plan.lst_import im_baggrund ON im_baggrund.guid = im.import_baggrundskort_guid
			AND im_baggrund.aktiv = 1
		WHERE p.guid = _plan_guid
		INTO _import_guid;

	ELSE

		SELECT
			im.guid
		FROM aflob_plan.v_planer p
		INNER JOIN aflob_plan.lst_import im ON im.guid = p.import_guid_calc
			AND im.aktiv = 1
		WHERE p.guid = _plan_guid
		INTO _import_guid;

	END IF;

	FOR i IN
		SELECT
			im.gruppe
			,t.beskrivelse
			,t.dest_schema
			,t.dest_table
			,t.source_insert_columns
			,t.source_select
		FROM aflob_plan.lst_import im
		INNER JOIN aflob_plan.lst_import_type t ON t.guid = ANY(im.import_type_guids)
			AND t.aktiv = 1
		WHERE im.guid = _import_guid
		-- Punkter først, da der ikke laves test for placering på Baggrundskort-punkter
		ORDER BY CASE SUBSTRING(t.dest_table, '^.+_(.+?)$')
					WHEN 'p'
					THEN 1
					WHEN 'l'
					THEN 2
					WHEN 'a'
					THEN 3
				END
				,t.dest_table
	LOOP

		RAISE NOTICE '%', i.beskrivelse;

		EXECUTE FORMAT(
			$$
				INSERT INTO %1$I.%2$I(
					plan_guid
					,gruppe
					,beskrivelse
					,%3$s
				) SELECT
					%4$L::uuid AS plan_guid
					,%5$L AS gruppe
					,%6$L AS beskrivelse
					,*
				FROM (%7$s) a
			$$
			,i.dest_schema
			,i.dest_table
			,i.source_insert_columns
			,_plan_guid
			,i.gruppe
			,i.beskrivelse
			,FORMAT(
				REPLACE(
					REPLACE(
						i.source_select
						,'[FRAME]'
						,'%1$L::geometry(''MultiPolygon'', 25832)'
					)
					,'[BUFFER]'
					,'%2$L::geometry(''MultiPolygon'', 25832)'
				)
				,_layout_frame
				,_layout_frame_buffer
			)
		);

	END LOOP;

END $BODY$;



