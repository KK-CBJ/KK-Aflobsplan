/* DROP FUNCTION IF EXISTS aflob_plan.style_dash(
	_dash_mm text
	,_map_scale_denom double precision
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.style_dash(
	_dash_mm text
	,_map_scale_denom double precision

	,OUT _dash text
	,OUT _dash_sum double precision
	,OUT _dash_array double precision[]
	,OUT _dash_array_sum double precision[]
)
	RETURNS RECORD
	IMMUTABLE
	STRICT
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	SELECT
		string_agg(
			c.dash::text
			,';'
			ORDER BY u.ordinality
		)
		,SUM(c.dash)
		,array_agg(
			c.dash
			ORDER BY u.ordinality
		)
	FROM UNNEST(
			string_to_array(_dash_mm, ';')
		) WITH ORDINALITY u(dash)
		,COALESCE(u.dash::double precision * _map_scale_denom / 1000) c(dash)
	INTO _dash
		,_dash_sum
		,_dash_array;

	WITH
	
		cte1 AS(
			SELECT
				u.ordinality
				,SUM(dash) OVER(ORDER BY u.ordinality) AS dash
			FROM UNNEST(
				_dash_array
			) WITH ORDINALITY u(dash)
		)

	SELECT
		array_agg(
			c.dash
			ORDER BY c.ordinality
		)
	FROM cte1 c
	INTO _dash_array_sum;

END $BODY$;




/* DROP FUNCTION IF EXISTS aflob_plan.style_geom(
	_geom geometry('GEOMETRY', 25832)

	,_scale_map_scale_denom double precision
	,_scale_reference_point geometry('POINT', 25832)

	,_fill integer
	,_fill_opacity integer

	,_outline integer
	,_outline_opacity integer
	,_outline_dash_mm text
	,_outline_map_scale_denom double precision
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.style_geom(
	_geom geometry('GEOMETRY', 25832)

	,_scale_map_scale_denom double precision DEFAULT NULL
	,_scale_reference_point geometry('POINT', 25832) DEFAULT NULL

	,_fill integer DEFAULT NULL
	,_fill_opacity integer DEFAULT NULL

	,_outline integer DEFAULT NULL
	,_outline_opacity integer DEFAULT NULL
	,_outline_dash_mm text DEFAULT NULL
	,_outline_map_scale_denom double precision DEFAULT NULL

	,OUT _geom_fill geometry('MULTIPOLYGON', 25832)
	,OUT _geom_outline geometry('MULTILINESTRING', 25832)
	,OUT _outline_dash text
)
	RETURNS RECORD
	IMMUTABLE
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	-- Scale
	IF COALESCE(_scale_map_scale_denom, 1) != 1 THEN

		_geom := ST_Scale(
					_geom
					,ST_MakePoint(
						_scale_map_scale_denom
						,_scale_map_scale_denom
					)
					,COALESCE(_scale_reference_point, ST_Centroid(_geom))
				);

	END IF;


	-- Extract polygon and shell
	SELECT
		ST_Multi(
			ST_Union(
				CASE
					WHEN COALESCE(_fill, 1) = 1
						AND COALESCE(_fill_opacity, 100) > 0
						AND GeometryType(_geom) ~* 'POLYGON$'
					THEN d.geom
				END
			)
		)
		,ST_Multi(
			ST_Union(
				CASE
					WHEN COALESCE(_outline, 1) = 1
						AND COALESCE(_outline_opacity, 100) > 0
						AND GeometryType(_geom) ~* 'LINESTRING$'
					THEN d.geom
					WHEN COALESCE(_outline, 1) = 1
						AND COALESCE(_outline_opacity, 100) > 0
					THEN ST_ExteriorRing(r.geom)
				END
			)
		)
	FROM ST_Dump(_geom) d
	LEFT JOIN ST_DumpRings(
				CASE
					WHEN GeometryType(_geom) ~* 'POLYGON$'
					THEN d.geom
				END
			) r ON TRUE
	INTO _geom_fill
		,_geom_outline;


	-- Patternize outline
	IF _geom_outline IS NOT NULL
		AND _outline_dash_mm IS NOT NULL
		AND _outline_map_scale_denom IS NOT NULL
	THEN

		SELECT
			ST_Union(subst.geom)
			,style._dash
		FROM aflob_plan.style_dash(
				_dash_mm := _outline_dash_mm
				,_map_scale_denom := _outline_map_scale_denom
			) style
			,ST_Dump(_geom_outline) dmp

			-- Point for each "dash-length"
			,ST_LineInterpolatePoints(
				dmp.geom
				,LEAST(style._dash_sum / ST_Length(dmp.geom), 1)
			) i(geom)

			-- Split at each "dash-length"
			,ST_Split(ST_Snap(dmp.geom, i.geom, 0.000001), i.geom) s(geom)

			-- Dump to individual geometries
			,ST_Dump(s.geom) d

			-- Series for each part of dash
			,generate_series(1, array_length(style._dash_array, 1), 2) g

			-- Substring matching relative position of the dash_array
			,ST_LineSubstring(
				d.geom
				-- ,COALESCE(style._dash_array_sum[g - 1], 0) / style._dash_sum
				-- ,style._dash_array_sum[g] / style._dash_sum
				,LEAST(COALESCE(style._dash_array_sum[g - 1], 0) / ST_Length(d.geom), 1)
				,LEAST(style._dash_array_sum[g] / ST_Length(d.geom), 1)
			) subst(geom)
		WHERE GeometryType(subst.geom) = 'LINESTRING'
		GROUP BY style._dash
		INTO _geom_outline
			,_outline_dash;

	END IF;

END $BODY$;




/* DROP FUNCTION IF EXISTS aflob_plan.style(
	_geom geometry('GEOMETRY', 25832)

	,_style_rotation double precision
	,_style_reference_point geometry('POINT', 25832)

	,_scale_map_scale_denom double precision
	,_scale_reference_point geometry('POINT', 25832)

	,_fill integer
	,_fill_opacity integer

	,_outline integer
	,_outline_opacity integer
	,_outline_dash_mm text
	,_outline_map_scale_denom double precision
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.style(
	_geom geometry('GEOMETRY', 25832)

	,_style_rotation double precision DEFAULT NULL
	,_style_reference_point geometry('POINT', 25832) DEFAULT NULL

	,_scale_map_scale_denom double precision DEFAULT NULL
	,_scale_reference_point geometry('POINT', 25832) DEFAULT NULL

	,_fill integer DEFAULT NULL
	,_fill_opacity integer DEFAULT NULL

	,_outline integer DEFAULT NULL
	,_outline_opacity integer DEFAULT NULL
	,_outline_dash_mm text DEFAULT NULL
	,_outline_map_scale_denom double precision DEFAULT NULL

	,OUT _geom_fill geometry('MULTIPOLYGON', 25832)
	,OUT _geom_outline geometry('MULTILINESTRING', 25832)
	,OUT _outline_dash text
)
	RETURNS RECORD
	STABLE
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	SELECT
		ST_Rotate(
			style_geom._geom_fill
			,-radians(COALESCE(_style_rotation, 0))
		)
		,ST_Rotate(
			style_geom._geom_outline
			,-radians(COALESCE(_style_rotation, 0))
		)
		,style_geom._outline_dash
	FROM aflob_plan.style_geom(
		_geom := _geom

		,_scale_map_scale_denom := _scale_map_scale_denom
		,_scale_reference_point := _scale_reference_point

		,_fill := _fill
		,_fill_opacity := _fill_opacity

		,_outline := _outline
		,_outline_opacity := _outline_opacity
		,_outline_dash_mm := _outline_dash_mm
		,_outline_map_scale_denom := _outline_map_scale_denom
	) style_geom
	INTO _geom_fill
		,_geom_outline
		,_outline_dash;

	IF _style_reference_point IS NOT NULL THEN

		_geom_fill := ST_Translate(
						_geom_fill
						,ST_X(_style_reference_point)
						,ST_Y(_style_reference_point)
					);

		_geom_outline := ST_Translate(
							_geom_outline
							,ST_X(_style_reference_point)
							,ST_Y(_style_reference_point)
						);

	END IF;

END $BODY$;