-- DROP VIEW IF EXISTS aflob_plan.v_layout_tegningshoved_label_p CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_tegningshoved_label_p AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Translate(
		ST_Scale(
			ST_Rotate(
				rotation.geom
				,-radians(layout_rotation)
				,t_ref.geom
			)
			,ST_MakePoint(p.layout_map_scale_denom_calc, p.layout_map_scale_denom_calc)
			,t_ref.geom
		)
		,ST_X(p.layout_reference_point) - ST_X(t_ref.geom)
		,ST_Y(p.layout_reference_point) - ST_Y(t_ref.geom)
	)::geometry('POINT', 25832) AS geom

	,p.guid AS plan_guid

	,CASE i.label
		WHEN '[TEGNINGSNAVN]'
		THEN p.plan_navn_calc
		WHEN '[SKALA]'
		THEN '1:' || p.layout_map_scale_denom_calc
		WHEN '[USER_PROJ]'
		THEN p.projekteret
		WHEN '[USER_DRAW]'
		THEN p.tegnet
		WHEN '[USER_CONTROL]'
		THEN p.kontrol
		WHEN '[USER_APPROVE]'
		THEN p.godkendt
		WHEN '[REVISION]'
		THEN p.revision
		WHEN '[DATO]'
		THEN to_char(COALESCE(p.plan_dato, current_date), 'DD.MM.YYYY')
		WHEN '[TEGNINGSFORMAT]'
		THEN (p.layout_page_width_calc * p.layout_pages_left_right * 1000)::numeric(10,0)::text || ' x ' || (p.layout_page_height_calc * p.layout_pages_top_bottom * 1000)::numeric(10,0)::text || ' mm'
		WHEN '[TEGNINGSNR]'
		THEN p.plan_nr
		WHEN '[TYPE]'
		THEN p.plan_type
		ELSE i.label
	END AS label_calc
	,i.label_color AS label_color_calc
	,i.label_rotation + layout_rotation + rotation_grd AS label_rotation_calc
	,i.label_size
		* p.layout_map_scale_denom_calc::double precision * COALESCE(i_scale.reference_value::double precision / p.layout_map_scale_denom_calc::double precision, 1) AS label_size_calc

	,i.label_adjustment AS label_adjustment_calc

	,i.font
	,i.font_style
FROM aflob_plan.v_tegningshoved_label_p i
INNER JOIN aflob_plan.v_planer p ON p.tegningshoved_guid_calc = i.tegningshoved_guid
	AND p.selected_ = 1

INNER JOIN COALESCE(i.label_geom) t(geom) ON TRUE

INNER JOIN aflob_plan.f_tegningshoved_p t_ref ON t_ref.guid = p.tegningshoved_reference_guid


LEFT JOIN aflob_plan.f_tegningshoved_p i_scale ON i_scale.guid = i.scale_reference
	AND i_scale.tegningshoved_guid = i.tegningshoved_guid
	AND i_scale.aktiv = 1
	AND i_scale.reference_punkt = -1
LEFT JOIN aflob_plan.f_tegningshoved_p i_rotation ON i_rotation.guid = i.rotation_reference
	AND i_rotation.tegningshoved_guid = i.tegningshoved_guid
	AND i_rotation.aktiv = 1
	AND i_rotation.reference_punkt = -2

INNER JOIN COALESCE(
	CASE
		WHEN i_scale.guid IS NOT NULL
		THEN ST_Scale(
				t.geom
				,ST_MakePoint(
					i_scale.reference_value::double precision / p.layout_map_scale_denom_calc::double precision
					,i_scale.reference_value::double precision / p.layout_map_scale_denom_calc::double precision
				)
				,i_scale.geom
			)
		ELSE t.geom
	END
) scale(geom) ON TRUE
INNER JOIN COALESCE(
	CASE
		WHEN i_rotation.guid IS NOT NULL
		THEN ST_Rotate(
				scale.geom
				,-radians(-layout_rotation - i_rotation.reference_value)
				,i_rotation.geom
			)
		ELSE scale.geom
	END
) rotation(geom) ON TRUE

INNER JOIN COALESCE(
	CASE
		WHEN i_rotation.guid IS NOT NULL
		THEN -layout_rotation - i_rotation.reference_value
		ELSE 0
	END
) rotation_grd ON TRUE

WHERE i.aktiv = 1
	AND NULLIF(TRIM(i.label), '') IS NOT NULL;














-- DROP VIEW IF EXISTS aflob_plan.v_layout_plan_label_p CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_plan_label_p AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_GeometryN(
		i.label_points
		,g
	)::geometry('POINT', 25832) AS geom

	,i.plan_guid

	,i.label_array[g] AS label_calc
	,i.label_color_calc
	,i.label_rotation_calc
	,i.label_size_calc

	,i.label_adjustment_calc

	,i.font
	,i.font_style
FROM aflob_plan.v_indhold_plan_label_p i
	,generate_series(1, array_length(i.label_array, 1)) g
WHERE i.layout_within = 1;


-- DROP VIEW IF EXISTS aflob_plan.v_layout_plan_label_l CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_plan_label_l AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Multi(i.label_geom)::geometry('MULTILINESTRING', 25832) AS geom

	,i.plan_guid

	,i.label_color_calc AS symbol_outline_color_calc
	,100 AS symbol_outline_color_opacity_calc
	,i.label_frame_width_calc AS symbol_outline_width_calc
FROM aflob_plan.v_indhold_plan_label_p i
WHERE i.label_frame_calc = 1
	AND i.layout_within = 1;







-- DROP VIEW IF EXISTS aflob_plan.v_layout_baggrundskort_label_p CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_baggrundskort_label_p AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_GeometryN(
		i.label_points
		,g
	)::geometry('POINT', 25832) AS geom

	,i.plan_guid

	,i.label_array[g] AS label_calc
	,i.label_color_calc
	,i.label_rotation_calc
	,i.label_size_calc

	,i.label_adjustment_calc

	,i.font
	,i.font_style
FROM aflob_plan.v_indhold_baggrundskort_label_p i
	,generate_series(1, array_length(i.label_array, 1)) g
WHERE i.layout_within = 1;


-- DROP VIEW IF EXISTS aflob_plan.v_layout_baggrundskort_label_l CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_baggrundskort_label_l AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Multi(i.label_geom)::geometry('MULTILINESTRING', 25832) AS geom

	,i.plan_guid

	,i.label_color_calc AS symbol_outline_color_calc
	,100 AS symbol_outline_color_opacity_calc
	,i.label_frame_width_calc AS symbol_outline_width_calc
FROM aflob_plan.v_indhold_baggrundskort_label_p i
WHERE i.label_frame_calc = 1
	AND i.layout_within = 1;