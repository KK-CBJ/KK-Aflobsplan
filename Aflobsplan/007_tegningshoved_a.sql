-- DROP FUNCTION IF EXISTS aflob_plan.f_tegningshoved_a_a_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.f_tegningshoved_a_a_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF (TG_OP = 'DELETE') THEN

		IF OLD.frame = 1 THEN

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
				NEW.frame = 1
				OR OLD.frame = 1
			) AND NEW.frame IS DISTINCT FROM OLD.frame
			) OR (
				NEW.frame = 1
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

		IF NEW.frame = 1 THEN

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




-- DROP FUNCTION IF EXISTS aflob_plan.v_tegningshoved_a_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_tegningshoved_a_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF TG_OP = 'DELETE' THEN

		DELETE FROM aflob_plan.f_tegningshoved_a
			WHERE guid = OLD.guid;

		RETURN OLD;

	ELSIF TG_OP = 'UPDATE' THEN

		UPDATE aflob_plan.f_tegningshoved_a
			SET
				geom = NEW.geom
				,aktiv = NEW.aktiv

				,tegningshoved_guid = NEW.tegningshoved_guid

				,type = NEW.type

				,scale_reference = NEW.scale_reference
				,rotation_reference = NEW.rotation_reference

				,frame = NEW.frame
		WHERE guid = OLD.guid;

		RETURN NEW;

	ELSIF TG_OP = 'INSERT' THEN

		INSERT INTO aflob_plan.f_tegningshoved_a(
			guid
			,geom
			,aktiv

			,tegningshoved_guid

			,type

			,scale_reference
			,rotation_reference

			,frame
		) VALUES (
			COALESCE(NEW.guid, uuid_generate_v4())
			,NEW.geom
			,NEW.aktiv

			,NEW.tegningshoved_guid

			,NEW.type

			,NEW.scale_reference
			,NEW.rotation_reference

			,NEW.frame
		);

		RETURN NEW;

	END IF;

END $BODY$;




-- DROP TABLE IF EXISTS aflob_plan.f_tegningshoved_a CASCADE;

CREATE TABLE aflob_plan.f_tegningshoved_a(
	guid uuid PRIMARY KEY DEFAULT uuid_generate_v4()
	,geom geometry('POLYGON', 25832) NOT NULL
	,aktiv integer NOT NULL DEFAULT 1

	,tegningshoved_guid uuid NOT NULL

	,type character varying NOT NULL

	,scale_reference uuid
	,rotation_reference uuid

	,frame integer
);


-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_geom_gist;
CREATE INDEX plan_f_tegningshoved_a_geom_gist ON aflob_plan.f_tegningshoved_a USING gist(geom);

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_tegningshoved_guid;
CREATE INDEX plan_f_tegningshoved_a_tegningshoved_guid ON aflob_plan.f_tegningshoved_a(tegningshoved_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_tegningshoved_guid_text;
CREATE INDEX plan_f_tegningshoved_a_tegningshoved_guid_text ON aflob_plan.f_tegningshoved_a((tegningshoved_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_type;
CREATE INDEX plan_f_tegningshoved_a_type ON aflob_plan.f_tegningshoved_a(type);

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_scale_reference;
CREATE INDEX plan_f_tegningshoved_a_scale_reference ON aflob_plan.f_tegningshoved_a(scale_reference);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_scale_reference_text;
CREATE INDEX plan_f_tegningshoved_a_scale_reference_text ON aflob_plan.f_tegningshoved_a((scale_reference::text));

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_rotation_reference;
CREATE INDEX plan_f_tegningshoved_a_rotation_reference ON aflob_plan.f_tegningshoved_a(rotation_reference);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_a_rotation_reference_text;
CREATE INDEX plan_f_tegningshoved_a_rotation_reference_text ON aflob_plan.f_tegningshoved_a((rotation_reference::text));


CREATE TRIGGER plan_f_tegningshoved_a_a_trg_iud
	AFTER INSERT OR UPDATE OR DELETE
		ON aflob_plan.f_tegningshoved_a
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.f_tegningshoved_a_a_trg();



-- DROP VIEW IF EXISTS aflob_plan.v_tegningshoved_a CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_tegningshoved_a AS

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
	,style._geom_fill AS style_geom_fill
	,style._geom_outline AS style_geom_outline

FROM aflob_plan.f_tegningshoved_a i
LEFT JOIN aflob_plan.lst_tegningshoved_a_type t ON t.beskrivelse = i.type
	AND t.aktiv = 1
	AND i.aktiv = 1


LEFT JOIN aflob_plan.style(
	_geom := i.geom

	,_style_rotation := NULL
	,_style_reference_point := NULL::geometry

	,_scale_map_scale_denom := NULL
	,_scale_reference_point := NULL::geometry

	,_fill := t.symbol_fill
	,_fill_opacity := t.symbol_fill_color_opacity

	,_outline := t.symbol_outline
	,_outline_opacity := t.symbol_outline_color_opacity
	,_outline_dash_mm := t.symbol_outline_dash_mm
	,_outline_map_scale_denom := 1
) style ON t.kode IS NOT NULL;


CREATE TRIGGER plan_v_tegningshoved_a_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_tegningshoved_a
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_tegningshoved_a_trg();


