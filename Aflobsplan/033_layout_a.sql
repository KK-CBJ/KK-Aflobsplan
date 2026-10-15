-- DROP VIEW IF EXISTS aflob_plan.v_layout_tegningshoved_a_fill CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_tegningshoved_a_fill AS

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
	)::geometry('MULTIPOLYGON', 25832) AS geom

	,p.guid AS plan_guid

	,i.symbol_fill_color_calc
	,i.symbol_fill_color_opacity_calc
FROM aflob_plan.v_tegningshoved_a i
INNER JOIN aflob_plan.v_planer p ON p.tegningshoved_guid_calc = i.tegningshoved_guid
	AND p.selected_ = 1

INNER JOIN COALESCE(i.style_geom_fill) t(geom) ON TRUE

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

WHERE i.aktiv = 1
	AND NOT(i.type ~* '^_.*_$')
	AND t.geom IS NOT NULL;




-- DROP VIEW IF EXISTS aflob_plan.v_layout_tegningshoved_a_outline CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_tegningshoved_a_outline AS

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
	)::geometry('MULTILINESTRING', 25832) AS geom

	,p.guid AS plan_guid

	,i.symbol_outline_color_calc
	,i.symbol_outline_color_opacity_calc
	,i.symbol_outline_width_calc
		* p.layout_map_scale_denom_calc::double precision * COALESCE(i_scale.reference_value::double precision / p.layout_map_scale_denom_calc::double precision, 1) AS symbol_outline_width_calc
FROM aflob_plan.v_tegningshoved_a i
INNER JOIN aflob_plan.v_planer p ON p.tegningshoved_guid_calc = i.tegningshoved_guid
	AND p.selected_ = 1

INNER JOIN COALESCE(i.style_geom_outline) t(geom) ON TRUE

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

WHERE i.aktiv = 1
	AND NOT(i.type ~* '^_.*_$')
	AND t.geom IS NOT NULL;


























-- DROP VIEW IF EXISTS aflob_plan.v_layout_plan_a_fill CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_plan_a_fill AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Multi(i.style_geom_fill)::geometry('MULTIPOLYGON', 25832) AS geom

	,i.plan_guid

	,i.symbol_fill_color_calc
	,i.symbol_fill_color_opacity_calc
FROM aflob_plan.v_indhold_plan_a i
WHERE i.aktiv = 1
	AND i.style_geom_fill IS NOT NULL;




-- DROP VIEW IF EXISTS aflob_plan.v_layout_plan_a_outline CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_plan_a_outline AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Multi(i.style_geom_outline)::geometry('MULTILINESTRING', 25832) AS geom

	,i.plan_guid

	,i.symbol_outline_color_calc
	,i.symbol_outline_color_opacity_calc
	,i.symbol_outline_width_calc
FROM aflob_plan.v_indhold_plan_a i
WHERE i.aktiv = 1
	AND i.style_geom_outline IS NOT NULL;








-- DROP VIEW IF EXISTS aflob_plan.v_layout_baggrundskort_a_fill CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_baggrundskort_a_fill AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Multi(i.style_geom_fill)::geometry('MULTIPOLYGON', 25832) AS geom

	,i.plan_guid

	,i.symbol_fill_color_calc
	,i.symbol_fill_color_opacity_calc
FROM aflob_plan.v_indhold_baggrundskort_a i
WHERE i.aktiv = 1
	AND i.style_geom_fill IS NOT NULL;




-- DROP VIEW IF EXISTS aflob_plan.v_layout_baggrundskort_a_outline CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_layout_baggrundskort_a_outline AS

SELECT
	ROW_NUMBER() OVER()::integer AS fid
	,ST_Multi(i.style_geom_outline)::geometry('MULTILINESTRING', 25832) AS geom

	,i.plan_guid

	,i.symbol_outline_color_calc
	,i.symbol_outline_color_opacity_calc
	,i.symbol_outline_width_calc
FROM aflob_plan.v_indhold_baggrundskort_a i
WHERE i.aktiv = 1
	AND i.style_geom_outline IS NOT NULL;