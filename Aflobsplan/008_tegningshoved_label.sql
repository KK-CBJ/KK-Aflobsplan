-- DROP FUNCTION IF EXISTS aflob_plan.v_tegningshoved_label_p_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_tegningshoved_label_p_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF TG_OP = 'DELETE' THEN

		DELETE FROM aflob_plan.f_tegningshoved_label_p
			WHERE guid = OLD.guid;

		RETURN OLD;

	ELSIF TG_OP = 'UPDATE' THEN

		UPDATE aflob_plan.f_tegningshoved_label_p
			SET
				geom = NEW.geom
				,aktiv = NEW.aktiv

				,tegningshoved_guid = NEW.tegningshoved_guid

				,label = NEW.label

				,scale_reference = NEW.scale_reference
				,rotation_reference = NEW.rotation_reference

				,label_color = NEW.label_color
				,label_font = NEW.label_font
				,label_rotation = NEW.label_rotation
				,label_size = NEW.label_size

				,label_adjustment = NEW.label_adjustment
				,label_offset_x = NEW.label_offset_x
				,label_offset_y = NEW.label_offset_y
		WHERE guid = OLD.guid;

		RETURN NEW;

	ELSIF TG_OP = 'INSERT' THEN

		INSERT INTO aflob_plan.f_tegningshoved_label_p(
			guid
			,geom
			,aktiv

			,tegningshoved_guid

			,label

			,scale_reference
			,rotation_reference

			,label_color
			,label_font
			,label_rotation
			,label_size

			,label_adjustment
			,label_offset_x
			,label_offset_y
		) VALUES (
			COALESCE(NEW.guid, uuid_generate_v4())
			,NEW.geom
			,NEW.aktiv

			,NEW.tegningshoved_guid

			,NEW.label

			,NEW.scale_reference
			,NEW.rotation_reference

			,NEW.label_color
			,NEW.label_font
			,NEW.label_rotation
			,NEW.label_size

			,NEW.label_adjustment
			,NEW.label_offset_x
			,NEW.label_offset_y
		);

		RETURN NEW;

	END IF;

	RETURN NULL;

END $BODY$;




-- DROP TABLE IF EXISTS aflob_plan.f_tegningshoved_label_p CASCADE;

CREATE TABLE aflob_plan.f_tegningshoved_label_p(
	guid uuid PRIMARY KEY DEFAULT uuid_generate_v4()
	,geom geometry('POINT', 25832) NOT NULL
	,aktiv integer NOT NULL DEFAULT 1

	,tegningshoved_guid uuid NOT NULL

	,label character varying NOT NULL

	,scale_reference uuid
	,rotation_reference uuid

	,label_color character varying
	,label_font character varying
	,label_rotation double precision
	,label_size double precision

	,label_adjustment integer
	,label_offset_x double precision
	,label_offset_y double precision
);


-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_geom_gist;
CREATE INDEX plan_f_tegningshoved_label_p_geom_gist ON aflob_plan.f_tegningshoved_label_p USING gist(geom);

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_tegningshoved_guid;
CREATE INDEX plan_f_tegningshoved_label_p_tegningshoved_guid ON aflob_plan.f_tegningshoved_label_p(tegningshoved_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_tegningshoved_guid_text;
CREATE INDEX plan_f_tegningshoved_label_p_tegningshoved_guid_text ON aflob_plan.f_tegningshoved_label_p((tegningshoved_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_scale_reference;
CREATE INDEX plan_f_tegningshoved_label_p_scale_reference ON aflob_plan.f_tegningshoved_label_p(scale_reference);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_scale_reference_text;
CREATE INDEX plan_f_tegningshoved_label_p_scale_reference_text ON aflob_plan.f_tegningshoved_label_p((scale_reference::text));

-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_rotation_reference;
CREATE INDEX plan_f_tegningshoved_label_p_rotation_reference ON aflob_plan.f_tegningshoved_label_p(rotation_reference);
-- DROP INDEX IF EXISTS aflob_plan.f_tegningshoved_label_p_rotation_reference_text;
CREATE INDEX plan_f_tegningshoved_label_p_rotation_reference_text ON aflob_plan.f_tegningshoved_label_p((rotation_reference::text));




-- DROP VIEW IF EXISTS aflob_plan.v_tegningshoved_label_p CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_tegningshoved_label_p AS

SELECT
	i.*

	-- Font
	,fo.font
	,fo.font_style

	,ST_SetSRID(
		ST_MakePoint(
			ST_X(i.geom) + COALESCE(i.label_offset_x, 0)
			,ST_Y(i.geom) + COALESCE(i.label_offset_y, 0)
		)
		,25832
	) AS label_geom

FROM aflob_plan.f_tegningshoved_label_p i
INNER JOIN aflob_plan.lst_font fo ON fo.beskrivelse = i.label_font
	AND fo.aktiv = 1;


CREATE TRIGGER plan_v_tegningshoved_label_p_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_tegningshoved_label_p
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_tegningshoved_label_p_trg();



