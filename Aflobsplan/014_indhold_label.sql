-- DROP FUNCTION IF EXISTS aflob_plan.v_indhold_label_p_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_indhold_label_p_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF TG_OP = 'DELETE' THEN

		EXECUTE FORMAT(
			$$
				UPDATE %1$I.%2$I
					SET
						label_show = 0
				WHERE guid = %3$L
			$$
			,TG_TABLE_SCHEMA
			,OLD.tbl_
			,OLD.guid
		);

	ELSIF TG_OP = 'UPDATE' THEN

		IF NOT(ST_Equals(NEW.geom, OLD.geom)) THEN

			NEW.label_position_x := OLD.label_position_x_calc + ST_X(NEW.geom) - ST_X(OLD.geom);
			NEW.label_position_y := OLD.label_position_y_calc + ST_Y(NEW.geom) - ST_Y(OLD.geom);

			IF OLD.label_position_x IS NULL
				OR OLD.label_position_y IS NULL
			THEN

				NEW.label_adjustment := COALESCE(NEW.label_adjustment, NEW.label_adjustment_calc);

			END IF;

		ELSE

			NEW.label_position_x := OLD.label_position_x;
			NEW.label_position_y := OLD.label_position_y;

		END IF;

		EXECUTE FORMAT(
			$$
				UPDATE %1$I.%2$I
					SET
						label = $1.label
						,label_show = $1.label_show

						,label_move_with_point = $1.label_move_with_point
						,label_position_x = $1.label_position_x
						,label_position_y = $1.label_position_y

						,label_color = $1.label_color
						,label_font = $1.label_font
						,label_rotation = $1.label_rotation
						,label_size = $1.label_size
						,label_spacing = $1.label_spacing

						,label_adjustment = $1.label_adjustment
						,label_offset_x = $1.label_offset_x
						,label_offset_y = $1.label_offset_y

						,label_frame = $1.label_frame
						,label_frame_width_mm = $1.label_frame_width_mm
						,label_frame_adjustment = $1.label_frame_adjustment
						,label_frame_margin_left = $1.label_frame_margin_left
						,label_frame_margin_right = $1.label_frame_margin_right
						,label_frame_margin_top = $1.label_frame_margin_top
						,label_frame_margin_bottom = $1.label_frame_margin_bottom

						,label_callout = $1.label_callout

						,font_size_factor_x = $1.font_size_factor_x
						,font_size_factor_y = $1.font_size_factor_y
				WHERE guid = %3$L
			$$
			,TG_TABLE_SCHEMA
			,OLD.tbl_
			,OLD.guid
		)
		USING NEW;

	END IF;

	RETURN NULL;

END $BODY$;




-- DROP VIEW IF EXISTS aflob_plan.v_indhold_plan_label_p CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_indhold_plan_label_p AS

WITH

	cte1 AS(
		SELECT
			i.guid
			,i.geom
			,i.geom AS geom_reference

			,i.plan_guid

			,i.label
			,i.label_show

			,i.label_move_with_point
			,i.label_position_x
			,i.label_position_y

			-- Label
			,i.label_color
			,i.label_font
			,i.label_rotation
			,i.label_size
			,i.label_spacing

			,i.label_adjustment
			,i.label_offset_x
			,i.label_offset_y

			,i.label_frame
			,i.label_frame_width_mm
			,i.label_frame_adjustment
			,i.label_frame_margin_left
			,i.label_frame_margin_right
			,i.label_frame_margin_top
			,i.label_frame_margin_bottom

			,i.label_callout

			-- Font
			,i.font_size_factor_x
			,i.font_size_factor_y

			-- Calc
			-- Label
			,COALESCE(i.label_position_x, ST_X(i.geom)) AS label_position_x_calc
			,COALESCE(i.label_position_y, ST_Y(i.geom)) AS label_position_y_calc

			,i.label_color_calc
			,i.label_font_calc
			,i.label_rotation_calc
			,i.label_size_calc
			,i.label_spacing_calc

			,i.label_adjustment_calc
			,i.label_offset_x_calc
			,i.label_offset_y_calc

			,i.label_frame_calc
			,i.label_frame_width_mm_calc
			,i.label_frame_width_calc
			,i.label_frame_adjustment_calc
			,i.label_frame_margin_left_calc
			,i.label_frame_margin_right_calc
			,i.label_frame_margin_top_calc
			,i.label_frame_margin_bottom_calc

			,i.label_callout_calc

			-- Font
			,i.font_size_factor_x_calc
			,i.font_size_factor_y_calc


			,i.layout_rotation

			,'f_indhold_p' AS tbl_
		FROM aflob_plan.v_indhold_plan_p i
		WHERE i.aktiv = 1
			AND i.label IS NOT NULL
			AND i.label_show = 1

		UNION ALL


		SELECT
			i.guid
			,i.geom
			,i.geom AS geom_reference

			,i.plan_guid

			,i.label
			,i.label_show

			,i.label_move_with_point
			,i.label_position_x
			,i.label_position_y

			-- Label
			,i.label_color
			,i.label_font
			,i.label_rotation
			,i.label_size
			,i.label_spacing

			,i.label_adjustment
			,i.label_offset_x
			,i.label_offset_y

			,i.label_frame
			,i.label_frame_width_mm
			,i.label_frame_adjustment
			,i.label_frame_margin_left
			,i.label_frame_margin_right
			,i.label_frame_margin_top
			,i.label_frame_margin_bottom

			,i.label_callout

			-- Font
			,i.font_size_factor_x
			,i.font_size_factor_y

			-- Calc
			-- Label
			,COALESCE(i.label_position_x, ST_X(label_position_point)) AS label_position_x_calc
			,COALESCE(i.label_position_y, ST_Y(label_position_point)) AS label_position_y_calc

			,i.label_color_calc
			,i.label_font_calc
			,i.label_rotation_calc
			,i.label_size_calc
			,i.label_spacing_calc

			,i.label_adjustment_calc
			,COALESCE(label_rotation._label_offset_x, i.label_offset_x_calc) AS label_offset_x_calc
			,COALESCE(label_rotation._label_offset_y, i.label_offset_y_calc) AS label_offset_y_calc

			,i.label_frame_calc
			,i.label_frame_width_mm_calc
			,i.label_frame_width_calc
			,COALESCE(label_flip._label_frame_adjustment, i.label_frame_adjustment_calc) AS label_frame_adjustment_calc
			,i.label_frame_margin_left_calc
			,i.label_frame_margin_right_calc
			,COALESCE(label_flip._label_frame_margin_top, i.label_frame_margin_top_calc) AS label_frame_margin_top_calc
			,COALESCE(label_flip._label_frame_margin_bottom, i.label_frame_margin_bottom_calc) AS label_frame_margin_bottom_calc

			,i.label_callout_calc

			-- Font
			,i.font_size_factor_x_calc
			,i.font_size_factor_y_calc


			-- ,COALESCE(label_rotation._linestring_rotation, i.layout_rotation) AS layout_rotation
			,CASE
				WHEN i.label_frame_calc = 1
				THEN i.layout_rotation
				ELSE COALESCE(label_rotation._linestring_rotation, i.layout_rotation)
			END AS layout_rotation

			,'f_indhold_l' AS tbl_
		FROM aflob_plan.v_indhold_plan_l i
		-- INNER JOIN COALESCE(i.label_position_pct / 100, 0.5) label_position ON TRUE
		INNER JOIN COALESCE(
						CASE
							WHEN i.label_position_x IS NULL
								OR i.label_position_y IS NULL
							THEN COALESCE(i.label_position_pct / 100, 0.5)
							ELSE ST_LineLocatePoint(i.geom, ST_SetSRID(ST_MakePoint(i.label_position_x, i.label_position_y), 25832))
						END
					) label_position ON TRUE
		INNER JOIN ST_LineInterpolatePoint(i.geom, label_position) label_position_point ON TRUE
		LEFT JOIN aflob_plan.label_flip_l(
			_label_flip := i.label_flip
			,_label_flip_side := i.label_flip_side

			,_label_frame_adjustment := i.label_frame_adjustment_calc

			,_label_frame_margin_top := i.label_frame_margin_top_calc
			,_label_frame_margin_bottom := i.label_frame_margin_bottom_calc
		) label_flip ON TRUE
		LEFT JOIN aflob_plan.label_rotation_l(
			_layout_rotation := i.layout_rotation
			,_linestring_rotation := DEGREES(
									ST_Azimuth(
										ST_LineInterpolatePoint(i.geom, GREATEST(label_position - 0.00001, 0))
										,ST_LineInterpolatePoint(i.geom, LEAST(label_position + 0.00001, 1))
									)
								)

			,_label_flip := label_flip._label_flip
		) label_rotation ON TRUE
		-- ) label_rotation ON i.label_position_x IS NULL
								-- OR i.label_position_y IS NULL
		WHERE i.aktiv = 1
			AND i.label IS NOT NULL
			AND i.label_show = 1

		UNION ALL

		SELECT
			i.guid
			,i.geom
			,i.geom AS geom_reference

			,i.plan_guid

			,i.label
			,i.label_show

			,i.label_move_with_point
			,i.label_position_x
			,i.label_position_y

			-- Label
			,i.label_color
			,i.label_font
			,i.label_rotation
			,i.label_size
			,i.label_spacing

			,i.label_adjustment
			,i.label_offset_x
			,i.label_offset_y

			,i.label_frame
			,i.label_frame_width_mm
			,i.label_frame_adjustment
			,i.label_frame_margin_left
			,i.label_frame_margin_right
			,i.label_frame_margin_top
			,i.label_frame_margin_bottom

			,i.label_callout

			-- Font
			,i.font_size_factor_x
			,i.font_size_factor_y

			-- Calc
			-- Label
			,COALESCE(i.label_position_x, ST_X(ST_PointOnSurface(i.geom))) AS label_position_x_calc
			,COALESCE(i.label_position_y, ST_Y(ST_PointOnSurface(i.geom))) AS label_position_y_calc

			,i.label_color_calc
			,i.label_font_calc
			,i.label_rotation_calc
			,i.label_size_calc
			,i.label_spacing_calc

			,i.label_adjustment_calc
			,i.label_offset_x_calc
			,i.label_offset_y_calc

			,i.label_frame_calc
			,i.label_frame_width_mm_calc
			,i.label_frame_width_calc
			,i.label_frame_adjustment_calc
			,i.label_frame_margin_left_calc
			,i.label_frame_margin_right_calc
			,i.label_frame_margin_top_calc
			,i.label_frame_margin_bottom_calc

			,i.label_callout_calc

			-- Font
			,i.font_size_factor_x_calc
			,i.font_size_factor_y_calc


			,i.layout_rotation

			,'f_indhold_a' AS tbl_
		FROM aflob_plan.v_indhold_plan_a i
		WHERE i.aktiv = 1
			AND i.label IS NOT NULL
			AND i.label_show = 1
	)

SELECT
	c.guid
	,l._label_points_centroid::geometry('POINT', 25832) AS geom

	,c.plan_guid

	,c.label
	,c.label_show

	,c.label_move_with_point
	,c.label_position_x
	,c.label_position_y

	-- Label
	,c.label_color
	,c.label_font
	,c.label_rotation
	,c.label_size
	,c.label_spacing

	,c.label_adjustment
	,c.label_offset_x
	,c.label_offset_y

	,c.label_frame
	,c.label_frame_width_mm
	,c.label_frame_adjustment
	,c.label_frame_margin_left
	,c.label_frame_margin_right
	,c.label_frame_margin_top
	,c.label_frame_margin_bottom

	,c.label_callout

	-- Font
	,c.font_size_factor_x
	,c.font_size_factor_y

	-- Calc
	-- Label
	,c.label_position_x_calc
	,c.label_position_y_calc

	,c.label AS label_calc
	,calc2.label_color AS label_color_calc
	,c.label_font_calc
	,c.label_rotation_calc + c.layout_rotation AS label_rotation_calc
	,c.label_size_calc
	,c.label_spacing_calc

	,calc.label_adjustment AS label_adjustment_calc
	,c.label_offset_x_calc
	,c.label_offset_y_calc

	,c.label_frame_calc
	,c.label_frame_width_mm_calc
	,calc2.label_frame_width AS label_frame_width_calc
	,c.label_frame_adjustment_calc
	,c.label_frame_margin_left_calc
	,c.label_frame_margin_right_calc
	,c.label_frame_margin_top_calc
	,c.label_frame_margin_bottom_calc

	,calc.label_callout AS label_callout_calc

	-- Font
	,c.font_size_factor_x_calc
	,c.font_size_factor_y_calc

	,l._font AS font
	,l._font_style AS font_style


	,c.layout_rotation

	,c.tbl_


	-- Label layout
	,layout_within
	,l._label_array AS label_array
	,l._label_geom AS label_geom
	,l._label_points AS label_points


	-- QGIS
	,l._label_points_centroid AS label_points_centroid
	,c.geom AS label_geom_callout_reference
FROM cte1 c
INNER JOIN aflob_plan.f_planer p ON p.guid = c.plan_guid


-- Justér værdier, således at der kan vises en boks for labeludbredelse
INNER JOIN LATERAL(
	SELECT
		CASE
			WHEN c.label_frame_calc = 1
			THEN c.label_adjustment_calc
			ELSE 4
		END AS label_adjustment

		,CASE
			WHEN c.label_frame_calc = 1
			THEN c.label_callout_calc
			ELSE 0
		END AS label_callout
) calc ON TRUE



INNER JOIN aflob_plan.label(
		_label := c.label

		,_label_reference_point := ST_ClosestPoint(
										c.geom_reference
										,ST_SetSRID(
											ST_MakePoint(
												c.label_position_x_calc
												,c.label_position_y_calc
											)
											,25832
										)
									)
		,_label_point := ST_SetSRID(
								ST_MakePoint(
									c.label_position_x_calc
									,c.label_position_y_calc
								)
								,25832
							)

		,_label_rotation := c.label_rotation_calc + c.layout_rotation
		,_label_size := c.label_size_calc
		,_label_spacing := c.label_spacing_calc

		,_label_adjustment := calc.label_adjustment
		,_label_offset_x := c.label_offset_x_calc
		,_label_offset_y := c.label_offset_y_calc

		,_label_frame := 1
		,_label_frame_adjustment := c.label_frame_adjustment_calc
		,_label_frame_margin_left := c.label_frame_margin_left_calc
		,_label_frame_margin_right := c.label_frame_margin_right_calc
		,_label_frame_margin_top := c.label_frame_margin_top_calc
		,_label_frame_margin_bottom := c.label_frame_margin_bottom_calc

		,_label_callout := calc.label_callout

		,_font_size_factor_x := c.font_size_factor_x_calc
		,_font_size_factor_y := c.font_size_factor_y_calc
	) l ON TRUE


-- Justér værdier, således at manglende overlap med planen bliver tydelig
INNER JOIN LATERAL(
	SELECT
		layout_within::integer
		,CASE
			WHEN NOT(layout_within)
			THEN '#FF0000'
			WHEN c.label_frame_calc = 1
			THEN c.label_color_calc
		END AS label_color
		,CASE
			WHEN NOT(layout_within)
			THEN 0.1
			WHEN c.label_frame_calc = 1
			THEN c.label_frame_width_calc
			ELSE 0.025
		END AS label_frame_width
	FROM ST_Within(l._label_geom, p.layout_frame) layout_within
) calc2 ON TRUE;


CREATE TRIGGER plan_v_indhold_plan_label_p_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_indhold_plan_label_p
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_indhold_label_p_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_indhold_baggrundskort_label_p CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_indhold_baggrundskort_label_p AS

WITH

	cte1 AS(
		SELECT
			i.guid
			,i.geom
			,i.geom AS geom_reference

			,i.plan_guid

			,i.label
			,i.label_show

			,i.label_move_with_point
			,i.label_position_x
			,i.label_position_y

			-- Label
			,i.label_color
			,i.label_font
			,i.label_rotation
			,i.label_size
			,i.label_spacing

			,i.label_adjustment
			,i.label_offset_x
			,i.label_offset_y

			,i.label_frame
			,i.label_frame_width_mm
			,i.label_frame_adjustment
			,i.label_frame_margin_left
			,i.label_frame_margin_right
			,i.label_frame_margin_top
			,i.label_frame_margin_bottom

			,i.label_callout

			-- Font
			,i.font_size_factor_x
			,i.font_size_factor_y

			-- Calc
			-- Label
			,COALESCE(i.label_position_x, ST_X(i.geom)) AS label_position_x_calc
			,COALESCE(i.label_position_y, ST_Y(i.geom)) AS label_position_y_calc

			,i.label_color_calc
			,i.label_font_calc
			,i.label_rotation_calc
			,i.label_size_calc
			,i.label_spacing_calc

			,i.label_adjustment_calc
			,i.label_offset_x_calc
			,i.label_offset_y_calc

			,i.label_frame_calc
			,i.label_frame_width_mm_calc
			,i.label_frame_width_calc
			,i.label_frame_adjustment_calc
			,i.label_frame_margin_left_calc
			,i.label_frame_margin_right_calc
			,i.label_frame_margin_top_calc
			,i.label_frame_margin_bottom_calc

			,i.label_callout_calc

			-- Font
			,i.font_size_factor_x_calc
			,i.font_size_factor_y_calc


			,i.layout_rotation

			,'f_indhold_p' AS tbl_
		FROM aflob_plan.v_indhold_baggrundskort_p i
		WHERE i.aktiv = 1
			AND i.label IS NOT NULL
			AND i.label_show = 1

		UNION ALL


		SELECT
			i.guid
			,i.geom
			,i.geom AS geom_reference

			,i.plan_guid

			,i.label
			,i.label_show

			,i.label_move_with_point
			,i.label_position_x
			,i.label_position_y

			-- Label
			,i.label_color
			,i.label_font
			,i.label_rotation
			,i.label_size
			,i.label_spacing

			,i.label_adjustment
			,i.label_offset_x
			,i.label_offset_y

			,i.label_frame
			,i.label_frame_width_mm
			,i.label_frame_adjustment
			,i.label_frame_margin_left
			,i.label_frame_margin_right
			,i.label_frame_margin_top
			,i.label_frame_margin_bottom

			,i.label_callout

			-- Font
			,i.font_size_factor_x
			,i.font_size_factor_y

			-- Calc
			-- Label
			,COALESCE(i.label_position_x, ST_X(label_position_point)) AS label_position_x_calc
			,COALESCE(i.label_position_y, ST_Y(label_position_point)) AS label_position_y_calc

			,i.label_color_calc
			,i.label_font_calc
			,i.label_rotation_calc
			,i.label_size_calc
			,i.label_spacing_calc

			,i.label_adjustment_calc
			,COALESCE(label_rotation._label_offset_x, i.label_offset_x_calc) AS label_offset_x_calc
			,COALESCE(label_rotation._label_offset_y, i.label_offset_y_calc) AS label_offset_y_calc

			,i.label_frame_calc
			,i.label_frame_width_mm_calc
			,i.label_frame_width_calc
			,COALESCE(label_flip._label_frame_adjustment, i.label_frame_adjustment_calc) AS label_frame_adjustment_calc
			,i.label_frame_margin_left_calc
			,i.label_frame_margin_right_calc
			,COALESCE(label_flip._label_frame_margin_top, i.label_frame_margin_top_calc) AS label_frame_margin_top_calc
			,COALESCE(label_flip._label_frame_margin_bottom, i.label_frame_margin_bottom_calc) AS label_frame_margin_bottom_calc

			,i.label_callout_calc

			-- Font
			,i.font_size_factor_x_calc
			,i.font_size_factor_y_calc


			-- ,COALESCE(label_rotation._linestring_rotation, i.layout_rotation) AS layout_rotation
			,CASE
				WHEN i.label_frame_calc = 1
				THEN i.layout_rotation
				ELSE COALESCE(label_rotation._linestring_rotation, i.layout_rotation)
			END AS layout_rotation

			,'f_indhold_l' AS tbl_
		FROM aflob_plan.v_indhold_baggrundskort_l i
		INNER JOIN COALESCE(
						CASE
							WHEN i.label_position_x IS NULL
								OR i.label_position_y IS NULL
							THEN COALESCE(i.label_position_pct / 100, 0.5)
							ELSE ST_LineLocatePoint(i.geom, ST_SetSRID(ST_MakePoint(i.label_position_x, i.label_position_y), 25832))
						END
					) label_position ON TRUE
		INNER JOIN ST_LineInterpolatePoint(i.geom, label_position) label_position_point ON TRUE
		LEFT JOIN aflob_plan.label_flip_l(
			_label_flip := i.label_flip
			,_label_flip_side := i.label_flip_side

			,_label_frame_adjustment := i.label_frame_adjustment_calc

			,_label_frame_margin_top := i.label_frame_margin_top_calc
			,_label_frame_margin_bottom := i.label_frame_margin_bottom_calc
		) label_flip ON TRUE
		LEFT JOIN aflob_plan.label_rotation_l(
			_layout_rotation := i.layout_rotation
			,_linestring_rotation := DEGREES(
									ST_Azimuth(
										ST_LineInterpolatePoint(i.geom, GREATEST(label_position - 0.00001, 0))
										,ST_LineInterpolatePoint(i.geom, LEAST(label_position + 0.00001, 1))
									)
								)

			,_label_flip := label_flip._label_flip
		) label_rotation ON TRUE
		WHERE i.aktiv = 1
			AND i.label IS NOT NULL
			AND i.label_show = 1

		UNION ALL

		SELECT
			i.guid
			,i.geom
			,i.geom AS geom_reference

			,i.plan_guid

			,i.label
			,i.label_show

			,i.label_move_with_point
			,i.label_position_x
			,i.label_position_y

			-- Label
			,i.label_color
			,i.label_font
			,i.label_rotation
			,i.label_size
			,i.label_spacing

			,i.label_adjustment
			,i.label_offset_x
			,i.label_offset_y

			,i.label_frame
			,i.label_frame_width_mm
			,i.label_frame_adjustment
			,i.label_frame_margin_left
			,i.label_frame_margin_right
			,i.label_frame_margin_top
			,i.label_frame_margin_bottom

			,i.label_callout

			-- Font
			,i.font_size_factor_x
			,i.font_size_factor_y

			-- Calc
			-- Label
			,COALESCE(i.label_position_x, ST_X(ST_PointOnSurface(i.geom))) AS label_position_x_calc
			,COALESCE(i.label_position_y, ST_Y(ST_PointOnSurface(i.geom))) AS label_position_y_calc

			,i.label_color_calc
			,i.label_font_calc
			,i.label_rotation_calc
			,i.label_size_calc
			,i.label_spacing_calc

			,i.label_adjustment_calc
			,i.label_offset_x_calc
			,i.label_offset_y_calc

			,i.label_frame_calc
			,i.label_frame_width_mm_calc
			,i.label_frame_width_calc
			,i.label_frame_adjustment_calc
			,i.label_frame_margin_left_calc
			,i.label_frame_margin_right_calc
			,i.label_frame_margin_top_calc
			,i.label_frame_margin_bottom_calc

			,i.label_callout_calc

			-- Font
			,i.font_size_factor_x_calc
			,i.font_size_factor_y_calc


			,i.layout_rotation

			,'f_indhold_a' AS tbl_
		FROM aflob_plan.v_indhold_baggrundskort_a i
		WHERE i.aktiv = 1
			AND i.label IS NOT NULL
			AND i.label_show = 1
	)

SELECT
	c.guid
	,l._label_points_centroid::geometry('POINT', 25832) AS geom

	,c.plan_guid

	,c.label
	,c.label_show

	,c.label_move_with_point
	,c.label_position_x
	,c.label_position_y

	-- Label
	,c.label_color
	,c.label_font
	,c.label_rotation
	,c.label_size
	,c.label_spacing

	,c.label_adjustment
	,c.label_offset_x
	,c.label_offset_y

	,c.label_frame
	,c.label_frame_width_mm
	,c.label_frame_adjustment
	,c.label_frame_margin_left
	,c.label_frame_margin_right
	,c.label_frame_margin_top
	,c.label_frame_margin_bottom

	,c.label_callout

	-- Font
	,c.font_size_factor_x
	,c.font_size_factor_y

	-- Calc
	-- Label
	,c.label_position_x_calc
	,c.label_position_y_calc

	,c.label AS label_calc
	,calc2.label_color AS label_color_calc
	,c.label_font_calc
	,c.label_rotation_calc + c.layout_rotation AS label_rotation_calc
	,c.label_size_calc
	,c.label_spacing_calc

	,calc.label_adjustment AS label_adjustment_calc
	,c.label_offset_x_calc
	,c.label_offset_y_calc

	,c.label_frame_calc
	,c.label_frame_width_mm_calc
	,calc2.label_frame_width AS label_frame_width_calc
	,c.label_frame_adjustment_calc
	,c.label_frame_margin_left_calc
	,c.label_frame_margin_right_calc
	,c.label_frame_margin_top_calc
	,c.label_frame_margin_bottom_calc

	,calc.label_callout AS label_callout_calc

	-- Font
	,c.font_size_factor_x_calc
	,c.font_size_factor_y_calc

	,l._font AS font
	,l._font_style AS font_style


	,c.layout_rotation

	,c.tbl_


	-- Label layout
	,layout_within
	,l._label_array AS label_array
	,l._label_geom AS label_geom
	,l._label_points AS label_points


	-- QGIS
	,l._label_points_centroid AS label_points_centroid
	,c.geom AS label_geom_callout_reference
FROM cte1 c
INNER JOIN aflob_plan.f_planer p ON p.guid = c.plan_guid


-- Justér værdier, således at der kan vises en boks for labeludbredelse
INNER JOIN LATERAL(
	SELECT
		CASE
			WHEN c.label_frame_calc = 1
			THEN c.label_adjustment_calc
			ELSE 4
		END AS label_adjustment

		,CASE
			WHEN c.label_frame_calc = 1
			THEN c.label_callout_calc
			ELSE 0
		END AS label_callout
) calc ON TRUE



INNER JOIN aflob_plan.label(
		_label := c.label

		,_label_reference_point := ST_ClosestPoint(
										c.geom_reference
										,ST_SetSRID(
											ST_MakePoint(
												c.label_position_x_calc
												,c.label_position_y_calc
											)
											,25832
										)
									)
		,_label_point := ST_SetSRID(
								ST_MakePoint(
									c.label_position_x_calc
									,c.label_position_y_calc
								)
								,25832
							)

		,_label_rotation := c.label_rotation_calc + c.layout_rotation
		,_label_size := c.label_size_calc
		,_label_spacing := c.label_spacing_calc

		,_label_adjustment := calc.label_adjustment
		,_label_offset_x := c.label_offset_x_calc
		,_label_offset_y := c.label_offset_y_calc

		,_label_frame := 1
		,_label_frame_adjustment := c.label_frame_adjustment_calc
		,_label_frame_margin_left := c.label_frame_margin_left_calc
		,_label_frame_margin_right := c.label_frame_margin_right_calc
		,_label_frame_margin_top := c.label_frame_margin_top_calc
		,_label_frame_margin_bottom := c.label_frame_margin_bottom_calc

		,_label_callout := calc.label_callout

		,_font_size_factor_x := c.font_size_factor_x_calc
		,_font_size_factor_y := c.font_size_factor_y_calc
	) l ON TRUE


-- Justér værdier, således at manglende overlap med planen bliver tydelig
INNER JOIN LATERAL(
	SELECT
		layout_within::integer
		,CASE
			WHEN NOT(layout_within)
			THEN '#FF0000'
			ELSE c.label_color_calc
		END AS label_color
		,CASE
			WHEN NOT(layout_within)
			THEN 0.1
			WHEN c.label_frame_calc = 1
			THEN c.label_frame_width_calc
			ELSE 0.025
		END AS label_frame_width
	FROM ST_Within(l._label_geom, p.layout_frame) layout_within
) calc2 ON TRUE;



CREATE TRIGGER plan_v_indhold_baggrundskort_label_p_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_indhold_baggrundskort_label_p
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_indhold_label_p_trg();





