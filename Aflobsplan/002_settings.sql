-- DROP FUNCTION IF EXISTS aflob_plan.lst_settings_a_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.lst_settings_a_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF (TG_OP = 'DELETE') THEN

		IF OLD.layout_page_width IS NOT NULL
			OR OLD.layout_page_height IS NOT NULL
			OR OLD.layout_page_margin_left_right IS NOT NULL
			OR OLD.layout_page_margin_top_bottom IS NOT NULL

			OR OLD.layout_page_flip_top_bottom IS NOT NULL

			OR OLD.layout_max_pages_left_right IS NOT NULL
			OR OLD.layout_max_pages_top_bottom IS NOT NULL

			OR OLD.layout_map_scale_denom IS NOT NULL
			OR OLD.layout_map_margin_left_right IS NOT NULL
			OR OLD.layout_map_margin_top_bottom IS NOT NULL
		THEN

			WITH

				cte1 AS(
					-- Planer for en given bruger, eller alle hvis ændringen er på __system__
					SELECT DISTINCT
						p.guid
					FROM aflob_plan.lst_settings s
					INNER JOIN aflob_plan.f_planer p ON p.guid = ANY(s.plan_guids)
						AND p.aktiv = 1
					WHERE s.initialer = OLD.initialer
						OR OLD.initialer  = '__system__'
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

		IF NEW.layout_page_width IS DISTINCT FROM OLD.layout_page_width
			OR NEW.layout_page_height IS DISTINCT FROM OLD.layout_page_height
			OR NEW.layout_page_margin_left_right IS DISTINCT FROM OLD.layout_page_margin_left_right
			OR NEW.layout_page_margin_top_bottom IS DISTINCT FROM OLD.layout_page_margin_top_bottom

			OR NEW.layout_page_flip_top_bottom IS DISTINCT FROM OLD.layout_page_flip_top_bottom

			OR NEW.layout_max_pages_left_right IS DISTINCT FROM OLD.layout_max_pages_left_right
			OR NEW.layout_max_pages_top_bottom IS DISTINCT FROM OLD.layout_max_pages_top_bottom

			OR NEW.layout_map_scale_denom IS DISTINCT FROM OLD.layout_map_scale_denom
			OR NEW.layout_map_margin_left_right IS DISTINCT FROM OLD.layout_map_margin_left_right
			OR NEW.layout_map_margin_top_bottom IS DISTINCT FROM OLD.layout_map_margin_top_bottom
		THEN

			WITH

				cte1 AS(
					-- Planer for en given bruger, eller alle hvis ændringen er på __system__
					SELECT DISTINCT
						p.guid
					FROM aflob_plan.lst_settings s
					INNER JOIN aflob_plan.f_planer p ON p.guid = ANY(s.plan_guids)
						AND p.aktiv = 1
					WHERE s.initialer = OLD.initialer
						OR OLD.initialer  = '__system__'
				)

			UPDATE aflob_plan.f_planer p
				SET
					guid = p.guid
			FROM cte1 c
			WHERE p.guid = c.guid;

		ELSE

			WITH

				cte1 AS(
					SELECT
						array_agg(a.plan_guids) AS plan_guids
					FROM (
						SELECT
							*
						FROM UNNEST(NEW.plan_guids) u(plan_guids)

						EXCEPT

						SELECT
							*
						FROM UNNEST(OLD.plan_guids) u(plan_guids)
					) a
				)

			UPDATE aflob_plan.f_planer p
				SET
					guid = p.guid
			FROM cte1 c
			WHERE p.aktiv = 1
				AND p.guid = ANY(c.plan_guids);

		END IF;

	ELSIF (TG_OP = 'INSERT') THEN

			WITH

				cte1 AS(
					-- Planer for en given bruger, eller alle hvis ændringen er på __system__
					SELECT DISTINCT
						p.guid
					FROM aflob_plan.lst_settings s
					INNER JOIN aflob_plan.f_planer p ON p.guid = ANY(s.plan_guids)
						AND p.aktiv = 1
					WHERE s.initialer = NEW.initialer
						OR NEW.initialer  = '__system__'
				)

			UPDATE aflob_plan.f_planer p
				SET
					guid = p.guid
			FROM cte1 c
			WHERE p.guid = c.guid;

	END IF;


	RETURN NEW;

END $BODY$;




-- DROP TABLE IF EXISTS aflob_plan.lst_settings CASCADE;

CREATE TABLE aflob_plan.lst_settings(
	guid uuid PRIMARY KEY DEFAULT uuid_generate_v4()
	,initialer character varying(50) NOT NULL DEFAULT session_user

	-- Plan
	,plan_guids uuid[]

	-- Import / Export
	,import_guid uuid
	,export_dxf_path text

	-- Tegningshoved
	,tegningshoved_guid uuid
	,tegningshoved_egen_side integer

	-- Layout
	,layout_page_width double precision
	,layout_page_height double precision
	,layout_page_margin_left_right double precision
	,layout_page_margin_top_bottom double precision

	,layout_page_flip_top_bottom integer

	,layout_max_pages_left_right integer
	,layout_max_pages_top_bottom integer

	,layout_map_scale_denom integer
	,layout_map_margin_left_right integer
	,layout_map_margin_top_bottom integer

	-- Symbol
	,symbol_scale double precision
	,symbol_rotation double precision

	,symbol_fill_color text
	,symbol_fill_color_opacity integer

	,symbol_outline_color text
	,symbol_outline_color_opacity integer
	,symbol_outline_width_mm double precision
	,symbol_outline_dash_mm text

	-- Label
	,label_color character varying
	,label_font character varying
	,label_rotation double precision
	,label_size double precision
	,label_spacing double precision

	,label_adjustment integer
	,label_offset_x double precision
	,label_offset_y double precision

	,label_frame integer
	,label_frame_width_mm double precision
	,label_frame_adjustment integer
	,label_frame_margin_left double precision
	,label_frame_margin_right double precision
	,label_frame_margin_top double precision
	,label_frame_margin_bottom double precision

	,label_callout integer

	-- Font
	,font_size_factor_x double precision
	,font_size_factor_y double precision
);


-- DROP INDEX IF EXISTS aflob_plan.lst_settings_plan_guid_gin;
CREATE INDEX plan_lst_settings_plan_guid_gin ON aflob_plan.lst_settings USING GIN(plan_guids);

-- DROP INDEX IF EXISTS aflob_plan.lst_settings_import_guid;
CREATE INDEX plan_lst_settings_import_guid ON aflob_plan.lst_settings(import_guid);
-- DROP INDEX IF EXISTS aflob_plan.lst_settings_import_guid_text;
CREATE INDEX plan_lst_settings_import_guid_text ON aflob_plan.lst_settings((import_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.lst_settings_tegningshoved_guid;
CREATE INDEX plan_lst_settings_tegningshoved_guid ON aflob_plan.lst_settings(tegningshoved_guid);
-- DROP INDEX IF EXISTS aflob_plan.lst_settings_tegningshoved_guid_text;
CREATE INDEX plan_lst_settings_tegningshoved_guid_text ON aflob_plan.lst_settings((tegningshoved_guid::text));


CREATE TRIGGER plan_lst_settings_a_trg_iud
	AFTER INSERT OR UPDATE OR DELETE
		ON aflob_plan.lst_settings
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.lst_settings_a_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_lst_settings_user CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_lst_settings_user AS

SELECT
	COALESCE(s.guid, sys.guid) AS guid
	,COALESCE(s.initialer, i.initialer) AS initialer

	-- Plan
	,s.plan_guids::character varying

	-- Import / Export
	,s.import_guid
	,s.export_dxf_path

	-- Tegningshoved
	,s.tegningshoved_guid
	,s.tegningshoved_egen_side

	-- Layout
	,s.layout_page_width
	,s.layout_page_height
	,s.layout_page_margin_left_right
	,s.layout_page_margin_top_bottom

	,s.layout_page_flip_top_bottom

	,s.layout_max_pages_left_right
	,s.layout_max_pages_top_bottom

	,s.layout_map_scale_denom
	,s.layout_map_margin_left_right
	,s.layout_map_margin_top_bottom

	-- Symbol
	,s.symbol_scale
	,s.symbol_rotation

	,s.symbol_fill_color
	,s.symbol_fill_color_opacity

	,s.symbol_outline_color
	,s.symbol_outline_color_opacity
	,s.symbol_outline_width_mm
	,s.symbol_outline_dash_mm

	-- Label
	,s.label_color
	,s.label_font
	,s.label_rotation
	,s.label_size
	,s.label_spacing

	,s.label_adjustment
	,s.label_offset_x
	,s.label_offset_y

	,s.label_frame
	,s.label_frame_width_mm
	,s.label_frame_adjustment
	,s.label_frame_margin_left
	,s.label_frame_margin_right
	,s.label_frame_margin_top
	,s.label_frame_margin_bottom

	,s.label_callout

	-- Font
	,s.font_size_factor_x
	,s.font_size_factor_y


	,'' AS plan_guids_soeg

	-- Import / Export
	,sys.import_guid AS sys_import_guid
	,sys.export_dxf_path AS sys_export_dxf_path

	-- Tegningshoved
	,sys.tegningshoved_guid AS sys_tegningshoved_guid
	,sys.tegningshoved_egen_side AS sys_tegningshoved_egen_side

	-- Layout
	,sys.layout_page_width AS sys_layout_page_width
	,sys.layout_page_height AS sys_layout_page_height
	,sys.layout_page_margin_left_right AS sys_layout_page_margin_left_right
	,sys.layout_page_margin_top_bottom AS sys_layout_page_margin_top_bottom

	,sys.layout_page_flip_top_bottom AS sys_layout_page_flip_top_bottom

	,sys.layout_max_pages_left_right AS sys_layout_max_pages_left_right
	,sys.layout_max_pages_top_bottom AS sys_layout_max_pages_top_bottom

	,sys.layout_map_scale_denom AS sys_layout_map_scale_denom
	,sys.layout_map_margin_left_right AS sys_layout_map_margin_left_right
	,sys.layout_map_margin_top_bottom AS sys_layout_map_margin_top_bottom

	-- Symbol
	,sys.symbol_scale AS sys_symbol_scale
	,sys.symbol_rotation AS sys_symbol_rotation

	,sys.symbol_fill_color AS sys_symbol_fill_color
	,sys.symbol_fill_color_opacity AS sys_symbol_fill_color_opacity

	,sys.symbol_outline_color AS sys_symbol_outline_color
	,sys.symbol_outline_color_opacity AS sys_symbol_outline_color_opacity
	,sys.symbol_outline_width_mm AS sys_symbol_outline_width_mm
	,sys.symbol_outline_dash_mm AS sys_symbol_outline_dash_mm

	-- Label
	,sys.label_color AS sys_label_color
	,sys.label_font AS sys_label_font
	,sys.label_rotation AS sys_label_rotation
	,sys.label_size AS sys_label_size
	,sys.label_spacing AS sys_label_spacing

	,sys.label_adjustment AS sys_label_adjustment
	,sys.label_offset_x AS sys_label_offset_x
	,sys.label_offset_y AS sys_label_offset_y

	,sys.label_frame AS sys_label_frame
	,sys.label_frame_width_mm AS sys_label_frame_width_mm
	,sys.label_frame_adjustment AS sys_label_frame_adjustment
	,sys.label_frame_margin_left AS sys_label_frame_margin_left
	,sys.label_frame_margin_right AS sys_label_frame_margin_right
	,sys.label_frame_margin_top AS sys_label_frame_margin_top
	,sys.label_frame_margin_bottom AS sys_label_frame_margin_bottom

	,sys.label_callout AS sys_label_callout

	-- Font
	,sys.font_size_factor_x AS sys_font_size_factor_x
	,sys.font_size_factor_y AS sys_font_size_factor_y
FROM (
	SELECT
		session_user AS initialer
) i
LEFT JOIN aflob_plan.lst_settings s ON s.initialer = i.initialer
LEFT JOIN aflob_plan.lst_settings sys ON sys.initialer = '__system__';




-- DROP FUNCTION IF EXISTS aflob_plan.v_lst_settings_user_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_lst_settings_user_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF TG_OP = 'DELETE' THEN

		DELETE FROM aflob_plan.lst_settings
			WHERE initialer = session_user;

		RETURN OLD;

	ELSIF TG_OP IN('INSERT', 'UPDATE') THEN

		IF EXISTS(
			SELECT
				'1'
			FROM aflob_plan.lst_settings
			WHERE initialer = session_user
		) THEN

			UPDATE aflob_plan.lst_settings
				SET
					-- Plan
					plan_guids = NEW.plan_guids::uuid[]

					-- Import / Export
					,import_guid = NEW.import_guid
					,export_dxf_path = NEW.export_dxf_path

					-- Tegningshoved
					,tegningshoved_guid = NEW.tegningshoved_guid
					,tegningshoved_egen_side = NEW.tegningshoved_egen_side

					-- Layout
					,layout_page_width = NEW.layout_page_width
					,layout_page_height = NEW.layout_page_height
					,layout_page_margin_left_right = NEW.layout_page_margin_left_right
					,layout_page_margin_top_bottom = NEW.layout_page_margin_top_bottom

					,layout_page_flip_top_bottom = NEW.layout_page_flip_top_bottom

					,layout_max_pages_left_right = NEW.layout_max_pages_left_right
					,layout_max_pages_top_bottom = NEW.layout_max_pages_top_bottom

					,layout_map_scale_denom = NEW.layout_map_scale_denom
					,layout_map_margin_left_right = NEW.layout_map_margin_left_right
					,layout_map_margin_top_bottom = NEW.layout_map_margin_top_bottom

					-- Symbol
					,symbol_scale = NEW.symbol_scale
					,symbol_rotation = NEW.symbol_rotation

					,symbol_fill_color = NEW.symbol_fill_color
					,symbol_fill_color_opacity = NEW.symbol_fill_color_opacity

					,symbol_outline_color = NEW.symbol_outline_color
					,symbol_outline_color_opacity = NEW.symbol_outline_color_opacity
					,symbol_outline_width_mm = NEW.symbol_outline_width_mm
					,symbol_outline_dash_mm = NEW.symbol_outline_dash_mm

					-- Label
					,label_color = NEW.label_color
					,label_font = NEW.label_font
					,label_rotation = NEW.label_rotation
					,label_size = NEW.label_size
					,label_spacing = NEW.label_spacing

					,label_adjustment = NEW.label_adjustment
					,label_offset_x = NEW.label_offset_x
					,label_offset_y = NEW.label_offset_y

					,label_frame = NEW.label_frame
					,label_frame_width_mm = NEW.label_frame_width_mm
					,label_frame_adjustment = NEW.label_frame_adjustment
					,label_frame_margin_left = NEW.label_frame_margin_left
					,label_frame_margin_right = NEW.label_frame_margin_right
					,label_frame_margin_top = NEW.label_frame_margin_top
					,label_frame_margin_bottom = NEW.label_frame_margin_bottom

					,label_callout = NEW.label_callout

					-- Font
					,font_size_factor_x = NEW.font_size_factor_x
					,font_size_factor_y = NEW.font_size_factor_y
			WHERE initialer = session_user;

		ELSE

			INSERT INTO aflob_plan.lst_settings(
				-- Plan
				plan_guids

				-- Import / Export
				,import_guid
				,export_dxf_path

				-- Tegningshoved
				,tegningshoved_guid
				,tegningshoved_egen_side

				-- Layout
				,layout_page_width
				,layout_page_height
				,layout_page_margin_left_right
				,layout_page_margin_top_bottom

				,layout_page_flip_top_bottom

				,layout_max_pages_left_right
				,layout_max_pages_top_bottom

				,layout_map_scale_denom
				,layout_map_margin_left_right
				,layout_map_margin_top_bottom

				-- Symbol
				,symbol_scale
				,symbol_rotation

				,symbol_fill_color
				,symbol_fill_color_opacity

				,symbol_outline_color
				,symbol_outline_color_opacity
				,symbol_outline_width_mm
				,symbol_outline_dash_mm

				-- Label
				,label_color
				,label_font
				,label_rotation
				,label_size
				,label_spacing

				,label_adjustment
				,label_offset_x
				,label_offset_y

				,label_frame
				,label_frame_width_mm
				,label_frame_adjustment
				,label_frame_margin_left
				,label_frame_margin_right
				,label_frame_margin_top
				,label_frame_margin_bottom

				,label_callout

				-- Font
				,font_size_factor_x
				,font_size_factor_y
			) VALUES (
				-- Plan
				NEW.plan_guids::uuid[]

				-- Import / Export
				,NEW.import_guid
				,NEW.export_dxf_path

				-- Tegningshoved
				,NEW.tegningshoved_guid
				,NEW.tegningshoved_egen_side

				-- Layout
				,NEW.layout_page_width
				,NEW.layout_page_height
				,NEW.layout_page_margin_left_right
				,NEW.layout_page_margin_top_bottom

				,NEW.layout_page_flip_top_bottom

				,NEW.layout_max_pages_left_right
				,NEW.layout_max_pages_top_bottom

				,NEW.layout_map_scale_denom
				,NEW.layout_map_margin_left_right
				,NEW.layout_map_margin_top_bottom

				-- Symbol
				,NEW.symbol_scale
				,NEW.symbol_rotation

				,NEW.symbol_fill_color
				,NEW.symbol_fill_color_opacity

				,NEW.symbol_outline_color
				,NEW.symbol_outline_color_opacity
				,NEW.symbol_outline_width_mm
				,NEW.symbol_outline_dash_mm

				-- Label
				,NEW.label_color
				,NEW.label_font
				,NEW.label_rotation
				,NEW.label_size
				,NEW.label_spacing

				,NEW.label_adjustment
				,NEW.label_offset_x
				,NEW.label_offset_y

				,NEW.label_frame
				,NEW.label_frame_width_mm
				,NEW.label_frame_adjustment
				,NEW.label_frame_margin_left
				,NEW.label_frame_margin_right
				,NEW.label_frame_margin_top
				,NEW.label_frame_margin_bottom

				,NEW.label_callout

				-- Font
				,NEW.font_size_factor_x
				,NEW.font_size_factor_y
			);

		END IF;

		RETURN NEW;

	END IF;

END $BODY$;


CREATE TRIGGER plan_v_lst_settings_user_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_lst_settings_user
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_lst_settings_user_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_lst_settings;
CREATE OR REPLACE VIEW aflob_plan.v_lst_settings AS

SELECT
	sys.guid
	,session_user::text AS initialer

	-- Plan
	,usr.plan_guids

	-- Import / Export
	,COALESCE(usr.import_guid, sys.import_guid) AS import_guid
	,COALESCE(NULLIF(TRIM(usr.export_dxf_path), ''), TRIM(sys.export_dxf_path), '') AS export_dxf_path

	-- Tegningshoved
	,COALESCE(usr.tegningshoved_guid, sys.tegningshoved_guid) AS tegningshoved_guid
	,COALESCE(usr.tegningshoved_egen_side, sys.tegningshoved_egen_side) AS tegningshoved_egen_side

	-- Layout
	,COALESCE(usr.layout_page_width, sys.layout_page_width) AS layout_page_width
	,COALESCE(usr.layout_page_height, sys.layout_page_height) AS layout_page_height
	,COALESCE(usr.layout_page_margin_left_right, sys.layout_page_margin_left_right) AS layout_page_margin_left_right
	,COALESCE(usr.layout_page_margin_top_bottom, sys.layout_page_margin_top_bottom) AS layout_page_margin_top_bottom

	,COALESCE(usr.layout_page_flip_top_bottom, sys.layout_page_flip_top_bottom) AS layout_page_flip_top_bottom

	,COALESCE(usr.layout_max_pages_left_right, sys.layout_max_pages_left_right) AS layout_max_pages_left_right
	,COALESCE(usr.layout_max_pages_top_bottom, sys.layout_max_pages_top_bottom) AS layout_max_pages_top_bottom

	,COALESCE(usr.layout_map_scale_denom, sys.layout_map_scale_denom) AS layout_map_scale_denom
	,COALESCE(usr.layout_map_margin_left_right, sys.layout_map_margin_left_right) AS layout_map_margin_left_right
	,COALESCE(usr.layout_map_margin_top_bottom, sys.layout_map_margin_top_bottom) AS layout_map_margin_top_bottom

	-- Symbol
	,COALESCE(usr.symbol_scale, sys.symbol_scale) AS symbol_scale
	,COALESCE(usr.symbol_rotation, sys.symbol_rotation) AS symbol_rotation

	,COALESCE(usr.symbol_fill_color, sys.symbol_fill_color) AS symbol_fill_color
	,COALESCE(usr.symbol_fill_color_opacity, sys.symbol_fill_color_opacity) AS symbol_fill_color_opacity

	,COALESCE(usr.symbol_outline_color, sys.symbol_outline_color) AS symbol_outline_color
	,COALESCE(usr.symbol_outline_color_opacity, sys.symbol_outline_color_opacity) AS symbol_outline_color_opacity
	,COALESCE(usr.symbol_outline_width_mm, sys.symbol_outline_width_mm) AS symbol_outline_width_mm
	,COALESCE(usr.symbol_outline_dash_mm, sys.symbol_outline_dash_mm) AS symbol_outline_dash_mm

	-- Label
	,COALESCE(usr.label_color, sys.label_color) AS label_color
	,COALESCE(usr.label_font, sys.label_font) AS label_font
	,COALESCE(usr.label_rotation, sys.label_rotation) AS label_rotation
	,COALESCE(usr.label_size, sys.label_size) AS label_size
	,COALESCE(usr.label_spacing, sys.label_spacing) AS label_spacing

	,COALESCE(usr.label_adjustment, sys.label_adjustment) AS label_adjustment
	,COALESCE(usr.label_offset_x, sys.label_offset_x) AS label_offset_x
	,COALESCE(usr.label_offset_y, sys.label_offset_y) AS label_offset_y

	,COALESCE(usr.label_frame, sys.label_frame) AS label_frame
	,COALESCE(usr.label_frame_width_mm, sys.label_frame_width_mm) AS label_frame_width_mm
	,COALESCE(usr.label_frame_adjustment, sys.label_frame_adjustment) AS label_frame_adjustment
	,COALESCE(usr.label_frame_margin_left, sys.label_frame_margin_left) AS label_frame_margin_left
	,COALESCE(usr.label_frame_margin_right, sys.label_frame_margin_right) AS label_frame_margin_right
	,COALESCE(usr.label_frame_margin_top, sys.label_frame_margin_top) AS label_frame_margin_top
	,COALESCE(usr.label_frame_margin_bottom, sys.label_frame_margin_bottom) AS label_frame_margin_bottom

	,COALESCE(usr.label_callout, sys.label_callout) AS label_callout

	-- Font
	,COALESCE(usr.font_size_factor_x, sys.font_size_factor_x) AS font_size_factor_x
	,COALESCE(usr.font_size_factor_y, sys.font_size_factor_y) AS font_size_factor_y
FROM aflob_plan.lst_settings sys
LEFT JOIN aflob_plan.lst_settings usr ON usr.initialer = session_user
WHERE sys.initialer = '__system__'
LIMIT 1;