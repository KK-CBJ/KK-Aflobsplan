-- DROP FUNCTION IF EXISTS aflob_plan.f_tegningshoved_l_a_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.f_tegningshoved_l_a_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF (TG_OP = 'DELETE') THEN

		IF OLD.layout = 1 THEN

			WITH

				cte1 AS(
					SELECT DISTINCT
						p.guid
					FROM aflob_plan.lst_settings s
					LEFT JOIN aflob_plan.lst_settings sys ON sys.initialer  = '__system__'
					INNER JOIN aflob_plan.f_planer p ON p.guid = ANY(s.plan_guids)
						AND p.aktiv = 1
						AND COALESCE(p.tegningshoved_guid, s.tegningshoved_guid, sys.tegningshoved_guid) = OLD.tegningshoved_guid
				)

			UPDATE aflob_plan.f_planer p
				SET
					guid = p.guid
			FROM cte1 c
			WHERE p.guid = c.guid;

		END IF;

		RETURN OLD;

	END IF;

	IF (TG_OP = 'UPDATE') THEN

		IF (
			(
				NEW.layout = 1
				OR OLD.layout = 1
			) AND NEW.layout IS DISTINCT FROM OLD.layout
			) OR (
				NEW.layout = 1
				AND (
					NOT(ST_Equals(NEW.geom, OLD.geom))
					OR NEW.tegningshoved_guid IS DISTINCT FROM OLD.tegningshoved_guid
				)
			)
		THEN

			WITH

				cte1 AS(
					SELECT DISTINCT
						p.guid
					FROM aflob_plan.lst_settings s
					LEFT JOIN aflob_plan.lst_settings sys ON sys.initialer  = '__system__'
					INNER JOIN aflob_plan.f_planer p ON p.guid = ANY(s.plan_guids)
						AND p.aktiv = 1
						AND COALESCE(p.tegningshoved_guid, s.tegningshoved_guid, sys.tegningshoved_guid) = ANY(ARRAY[OLD.tegningshoved_guid, NEW.tegningshoved_guid])
				)

			UPDATE aflob_plan.f_planer p
				SET
					guid = p.guid
			FROM cte1 c
			WHERE p.guid = c.guid;

		END IF;

	ELSIF (TG_OP = 'INSERT') THEN

		IF NEW.layout = 1 THEN

			WITH

				cte1 AS(
					SELECT DISTINCT
						p.guid
					FROM aflob_plan.lst_settings s
					LEFT JOIN aflob_plan.lst_settings sys ON sys.initialer  = '__system__'
					INNER JOIN aflob_plan.f_planer p ON p.guid = ANY(s.plan_guids)
						AND p.aktiv = 1
						AND COALESCE(p.tegningshoved_guid, s.tegningshoved_guid, sys.tegningshoved_guid) = NEW.tegningshoved_guid
				)

			UPDATE aflob_plan.f_planer p
				SET
					guid = p.guid
			FROM cte1 c
			WHERE p.guid = c.guid;

		END IF;

	END IF;


	RETURN NEW;

END $BODY$;




-- DROP FUNCTION IF EXISTS aflob_plan.v_tegningshoved_l_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_tegningshoved_l_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF TG_OP = 'DELETE' THEN

		DELETE FROM aflob_plan.f_tegningshoved_l
			WHERE guid = OLD.guid;

		RETURN OLD;

	ELSIF TG_OP = 'UPDATE' THEN

		UPDATE aflob_plan.f_tegningshoved_l
			SET
				geom = NEW.geom
				,aktiv = NEW.aktiv

				,tegningshoved_guid = NEW.tegningshoved_guid

				,type = NEW.type

				,scale_reference = NEW.scale_reference
				,rotation_reference = NEW.rotation_reference

				,layout = NEW.layout
		WHERE guid = OLD.guid;

		RETURN NEW;

	ELSIF TG_OP = 'INSERT' THEN

		INSERT INTO aflob_plan.f_tegningshoved_l(
			guid
			,geom
			,aktiv

			,tegningshoved_guid

			,type

			,scale_reference
			,rotation_reference

			,layout
		) VALUES (
			COALESCE(NEW.guid, uuid_generate_v4())
			,NEW.geom
			,NEW.aktiv

			,NEW.tegningshoved_guid

			,NEW.type

			,NEW.scale_reference
			,NEW.rotation_reference

			,NEW.layout
		);

		RETURN NEW;

	END IF;

END $BODY$;




-- DROP TABLE IF EXISTS aflob_plan.f_tegningshoved_l CASCADE;

CREATE TABLE aflob_plan.f_tegningshoved_l(
	guid uuid PRIMARY KEY DEFAULT uuid_generate_v4()
	,geom geometry('LINESTRING', 25832) NOT NULL
	,aktiv integer NOT NULL DEFAULT 1

	,tegningshoved_guid uuid NOT NULL

	,type character varying NOT NULL

	,scale_reference uuid
	,rotation_reference uuid

	,layout integer
);


-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_geom_gist;
CREATE INDEX plan_f_tegningshoved_l_geom_gist ON aflob_plan.f_tegningshoved_l USING gist(geom);

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_tegningshoved_guid;
CREATE INDEX plan_f_tegningshoved_l_tegningshoved_guid ON aflob_plan.f_tegningshoved_l(tegningshoved_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_tegningshoved_guid_text;
CREATE INDEX plan_f_tegningshoved_l_tegningshoved_guid_text ON aflob_plan.f_tegningshoved_l((tegningshoved_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_type;
CREATE INDEX plan_f_tegningshoved_l_type ON aflob_plan.f_tegningshoved_l(type);

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_scale_reference;
CREATE INDEX plan_f_tegningshoved_l_scale_reference ON aflob_plan.f_tegningshoved_l(scale_reference);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_scale_reference_text;
CREATE INDEX plan_f_tegningshoved_l_scale_reference_text ON aflob_plan.f_tegningshoved_l((scale_reference::text));

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_rotation_reference;
CREATE INDEX plan_f_tegningshoved_l_rotation_reference ON aflob_plan.f_tegningshoved_l(rotation_reference);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_l_rotation_reference_text;
CREATE INDEX plan_f_tegningshoved_l_rotation_reference_text ON aflob_plan.f_tegningshoved_l((rotation_reference::text));


CREATE TRIGGER plan_f_tegningshoved_l_a_trg_iud
	AFTER INSERT OR UPDATE OR DELETE
		ON aflob_plan.f_tegningshoved_l
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.f_tegningshoved_l_a_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_tegningshoved_l CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_tegningshoved_l AS

SELECT
	i.*




	-- Symbol
	,t.symbol_fill_color AS symbol_fill_color_calc
	,t.symbol_fill_color_opacity AS symbol_fill_color_opacity_calc

	,t.symbol_outline_color AS symbol_outline_color_calc
	,t.symbol_outline_color_opacity AS symbol_outline_color_opacity_calc
	,t.symbol_outline_width_mm AS symbol_outline_width_mm_calc
	,t.symbol_outline_width_mm
							* 1 / 1000 AS symbol_outline_width_calc

	,t.symbol_outline_dash_mm AS symbol_outline_dash_mm_calc
	,style._outline_dash AS symbol_outline_dash_calc

	,i.geom AS style_geom
	,NULL::geometry('MULTIPOLYGON', 25832) AS style_geom_fill
	,style._geom_outline AS style_geom_outline

FROM aflob_plan.f_tegningshoved_l i
LEFT JOIN aflob_plan.lst_tegningshoved_l_type t ON t.beskrivelse = i.type
	AND t.aktiv = 1
	AND i.aktiv = 1


LEFT JOIN aflob_plan.style(
	_geom := i.geom

	,_style_rotation := NULL
	,_style_reference_point := NULL::geometry

	,_scale_map_scale_denom := NULL
	,_scale_reference_point := NULL::geometry

	,_fill := 0

	,_outline := t.symbol_outline
	,_outline_opacity := t.symbol_outline_color_opacity
	,_outline_dash_mm := t.symbol_outline_dash_mm
	,_outline_map_scale_denom := 1
) style ON t.kode IS NOT NULL;


CREATE TRIGGER plan_v_tegningshoved_l_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_tegningshoved_l
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_tegningshoved_l_trg();


