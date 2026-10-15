/* DROP FUNCTION IF EXISTS aflob_plan.layout(
	_geom geometry('GEOMETRY', 25832)

	,_tegningshoved_guid uuid
	,_tegningshoved_egen_side integer

	,_layout_page_width double precision
	,_layout_page_height double precision
	,_layout_page_margin_left_right double precision
	,_layout_page_margin_top_bottom double precision

	,_layout_page_flip_top_bottom integer

	,_layout_max_pages_left_right integer
	,_layout_max_pages_top_bottom integer

	,_layout_map_scale_denom integer
	,_layout_map_margin_left_right integer
	,_layout_map_margin_top_bottom integer
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.layout(
	_geom geometry('GEOMETRY', 25832)

	,_tegningshoved_guid uuid DEFAULT NULL
	,_tegningshoved_egen_side integer DEFAULT NULL

	,_layout_page_width double precision DEFAULT NULL
	,_layout_page_height double precision DEFAULT NULL
	,_layout_page_margin_left_right double precision DEFAULT NULL
	,_layout_page_margin_top_bottom double precision DEFAULT NULL

	,_layout_page_flip_top_bottom integer DEFAULT NULL

	,_layout_max_pages_left_right integer DEFAULT NULL
	,_layout_max_pages_top_bottom integer DEFAULT NULL

	,_layout_map_scale_denom integer DEFAULT NULL
	,_layout_map_margin_left_right integer DEFAULT NULL
	,_layout_map_margin_top_bottom integer DEFAULT NULL

	,OUT _layout_geom geometry('MULTILINESTRING', 25832)
	,OUT _layout_geom_inkl_tegningshoved geometry('MULTILINESTRING', 25832)
	,OUT _layout_frame geometry('MULTIPOLYGON', 25832)
	,OUT _layout_reference_point geometry('POINT', 25832)
	,OUT _layout_extent_points geometry('MULTIPOINT', 25832)

	,OUT _layout_rotation double precision
	,OUT _layout_pages_left_right integer
	,OUT _layout_pages_top_bottom integer
	,OUT _layout_too_wide integer
	,OUT _layout_too_high integer

	,OUT _tegningshoved_reference_guid uuid
)
	RETURNS RECORD
	STABLE
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_tegningshoved_reference_punkt integer;

	_tegningshoved_reference_point geometry('POINT', 25832);
	_tegningshoved_layout geometry('MULTILINESTRING', 25832);
	_tegningshoved_frame geometry('MULTIPOLYGON', 25832);


	_exterior_ring geometry('LINESTRING', 25832);

	_azimuth_p1 geometry('POINT', 25832);
	_azimuth_p2 geometry('POINT', 25832);
	_azimuth double precision;

	_bounds_width double precision;
	_bounds_height double precision;

	_layout_min_width double precision;
	_layout_min_height double precision;

	_layout_frame_width double precision;
	_layout_frame_width_no_header double precision;
	_layout_frame_height double precision;

	_layout_frame_base_point geometry('POINT', 25832);
	_layout_frame_single geometry('POLYGON', 25832);

BEGIN

	IF _geom IS NULL THEN

		RETURN;

	END IF;



	-- Default værdier fra settings
	SELECT
		COALESCE(_tegningshoved_guid, s.tegningshoved_guid)
		,COALESCE(_tegningshoved_egen_side, s.tegningshoved_egen_side)

		,COALESCE(_layout_page_width, s.layout_page_width)
		,COALESCE(_layout_page_height, s.layout_page_height)
		,COALESCE(_layout_page_margin_left_right, s.layout_page_margin_left_right)
		,COALESCE(_layout_page_margin_top_bottom, s.layout_page_margin_top_bottom)

		,COALESCE(_layout_page_flip_top_bottom, 0)

		,COALESCE(_layout_max_pages_left_right, s.layout_max_pages_left_right)
		,COALESCE(_layout_max_pages_top_bottom, s.layout_max_pages_top_bottom)

		,COALESCE(_layout_map_scale_denom, s.layout_map_scale_denom)
		,COALESCE(_layout_map_margin_left_right, s.layout_map_margin_left_right)
		,COALESCE(_layout_map_margin_top_bottom, s.layout_map_margin_top_bottom)
	FROM aflob_plan.v_lst_settings s
	INTO _tegningshoved_guid
		,_tegningshoved_egen_side

		,_layout_page_width
		,_layout_page_height
		,_layout_page_margin_left_right
		,_layout_page_margin_top_bottom

		,_layout_page_flip_top_bottom

		,_layout_max_pages_left_right
		,_layout_max_pages_top_bottom

		,_layout_map_scale_denom
		,_layout_map_margin_left_right
		,_layout_map_margin_top_bottom;




	-- Tegningshoved info
	SELECT
		t.guid
		,t.reference_punkt
		,t.geom
	FROM aflob_plan.f_tegningshoved_p t
	WHERE t.tegningshoved_guid = _tegningshoved_guid
		AND t.aktiv = 1
		AND t.reference_punkt > 0
	ORDER BY t.reference_punkt DESC
	LIMIT 1
	INTO _tegningshoved_reference_guid
		,_tegningshoved_reference_punkt
		,_tegningshoved_reference_point;


	IF _tegningshoved_reference_point IS NULL THEN

		_tegningshoved_reference_punkt := 4;

	END IF;


	SELECT
		ST_Multi(ST_Union(t.geom))
	FROM aflob_plan.f_tegningshoved_l t
	WHERE t.tegningshoved_guid = _tegningshoved_guid
		AND t.aktiv = 1
		AND t.layout = 1
		AND NOT(t.type ~* '^_.*_$')
	INTO _tegningshoved_layout;


	SELECT
		ST_Multi(ST_Union(t.geom))
	FROM aflob_plan.f_tegningshoved_a t
	WHERE t.tegningshoved_guid = _tegningshoved_guid
		AND t.aktiv = 1
		AND t.frame = 1
	INTO _tegningshoved_frame;




	-- Rotation af plan, så beregninger kan laves på planen som "vandret"
	_exterior_ring := ST_ExteriorRing(ST_OrientedEnvelope(ST_Buffer(_geom, 0.5, 'endcap=flat')));
	-- Øverste venstre punkt
	_azimuth_p1 := ST_PointN(_exterior_ring, 1);
	-- Nederse venste punkt
	_azimuth_p2 := ST_PointN(_exterior_ring, 2);
	_azimuth := DEGREES(ST_Azimuth(_azimuth_p1, _azimuth_p2))::numeric(10,1);
	-- _azimuth := DEGREES(ST_Azimuth(ST_Transform(_azimuth_p1, 4326)::geography, ST_Transform(_azimuth_p2, 4326)::geography))::int;


	_layout_rotation := CASE
							WHEN _azimuth < 90
							THEN _azimuth
							WHEN _azimuth < 270
							THEN _azimuth - 180
							ELSE _azimuth - 360
						END +
						CASE
							WHEN _layout_page_flip_top_bottom = 1
							THEN 180
							ELSE 0
						END;




	-- Layout frame
	_exterior_ring := ST_Rotate(
						_exterior_ring
						,radians(_layout_rotation)
						,_azimuth_p1
					);

	_bounds_width := ST_XMax(_exterior_ring) - ST_XMin(_exterior_ring);
	_bounds_height := ST_YMax(_exterior_ring) - ST_YMin(_exterior_ring);



	-- Layoutstørrelse
	-- Hvis tegningshoved har egen side, skal margin i bredden kun med en gang, da margin er på side med tegningshoved
	_layout_min_width := _layout_page_margin_left_right * (2 - _tegningshoved_egen_side)
							+ (_bounds_width + _layout_map_margin_left_right * 2) / _layout_map_scale_denom;

	_layout_min_height := _layout_page_margin_top_bottom * 2
							+ (_bounds_height + _layout_map_margin_top_bottom * 2) / _layout_map_scale_denom;


	-- Tilføj evt. side med tegningshoved til antal
	_layout_pages_left_right := LEAST(CEILING(_layout_min_width / _layout_page_width), _layout_max_pages_left_right) + _tegningshoved_egen_side;
	_layout_pages_top_bottom := LEAST(CEILING(_layout_min_height / _layout_page_height), _layout_max_pages_top_bottom);


	_layout_too_wide := (CEILING(_layout_min_width / _layout_page_width) > _layout_max_pages_left_right)::int;
	_layout_too_high := (CEILING(_layout_min_height / _layout_page_height) > _layout_max_pages_top_bottom)::int;


	_layout_frame_width = (_layout_page_width * _layout_pages_left_right - _layout_page_margin_left_right * 2) * _layout_map_scale_denom;
	_layout_frame_width_no_header = (_layout_page_width * (_layout_pages_left_right - _tegningshoved_egen_side) - _layout_page_margin_left_right * (2 - _tegningshoved_egen_side)) * _layout_map_scale_denom;
	_layout_frame_height = (_layout_page_height * _layout_pages_top_bottom - _layout_page_margin_top_bottom * 2) * _layout_map_scale_denom;


	IF _tegningshoved_reference_punkt IN(3,4) THEN

		_layout_frame_base_point := ST_MakePoint(
										CASE
											WHEN _layout_too_wide = 0
											THEN ST_XMin(_exterior_ring) + _bounds_width / 2 - _layout_frame_width_no_header / 2
											ELSE ST_XMin(_exterior_ring) - _layout_map_margin_left_right
										END
										,ST_YMin(_exterior_ring) + _bounds_height / 2 - _layout_frame_height / 2
									);

	ELSIF _tegningshoved_reference_punkt IN(1,2) THEN

		_layout_frame_base_point := ST_MakePoint(
										CASE
											WHEN _layout_too_wide = 0
											THEN ST_XMin(_exterior_ring) + _bounds_width / 2 + _layout_frame_width_no_header / 2 - _layout_frame_width
											ELSE ST_XMax(_exterior_ring) + _layout_map_margin_left_right - _layout_frame_width
										END
										,ST_YMin(_exterior_ring) + _bounds_height / 2 - _layout_frame_height / 2
									);

	END IF;


	-- Rettet til at udgangspunktet altid er fra tegningshoved og mod venstre. Kan evt. implementeres i ovenstående (originale) udkommenteret kode
	-- _layout_frame_base_point := ST_MakePoint(
									-- CASE
										-- WHEN _layout_too_wide = 0
											-- AND _tegningshoved_egen_side = 1
										-- THEN ST_XMin(_exterior_ring) + _bounds_width / 2 + _layout_frame_width_no_header / 2 - _layout_frame_width + _layout_page_width * _layout_map_scale_denom
										-- WHEN _layout_too_wide = 0
										-- THEN ST_XMin(_exterior_ring) + _bounds_width / 2 + _layout_frame_width_no_header / 2 - _layout_frame_width
										-- WHEN _tegningshoved_egen_side = 1
										-- THEN ST_XMax(_exterior_ring) + _layout_map_margin_left_right - _layout_frame_width + _layout_page_width * _layout_map_scale_denom
										-- ELSE ST_XMax(_exterior_ring) + _layout_map_margin_left_right - _layout_frame_width
									-- END
									-- ,ST_YMin(_exterior_ring) + _bounds_height / 2 - _layout_frame_height / 2
								-- );


	-- Frame som klassisk bbox med udgangspunkt i base_point
	-- (MINX, MINY), (MINX, MAXY), (MAXX, MAXY), (MAXX, MINY), (MINX, MINY)
	_layout_frame_single := ST_SetSRID(
						ST_MakePolygon(
							ST_MakeLine(
								ARRAY[
									ST_SetSRID(_layout_frame_base_point, 0)
									,ST_MakePoint(
										ST_X(_layout_frame_base_point)
										,ST_Y(_layout_frame_base_point) + _layout_frame_height
									)
									,ST_MakePoint(
										ST_X(_layout_frame_base_point) + _layout_frame_width
										,ST_Y(_layout_frame_base_point) + _layout_frame_height
									)
									,ST_MakePoint(
										ST_X(_layout_frame_base_point) + _layout_frame_width
										,ST_Y(_layout_frame_base_point)
									)
									,ST_SetSRID(_layout_frame_base_point, 0)
								]
							)
						)
						,25832
					);


	-- Layout reference punkt til tegningshoved
	_layout_reference_point := ST_PointN(ST_ExteriorRing(_layout_frame_single), _tegningshoved_reference_punkt);


	-- Layout med margin og sidemarkering
	WITH

		layout_page_divider_left_right AS(
			SELECT
				ST_Union(
					ST_Union(
						ST_MakeLine(
							ST_MakePoint(divider_x, divider_y1)
							,ST_MakePoint(divider_x, divider_y2)
						)
						,ST_MakeLine(
							ST_MakePoint(divider_x, divider_y3)
							,ST_MakePoint(divider_x, divider_y4)
						)
					)
				) AS geom
			FROM generate_series(1, _layout_pages_left_right - 1) g
				,COALESCE(ST_X(_layout_frame_base_point) - _layout_page_margin_left_right * _layout_map_scale_denom + g * _layout_page_width * _layout_map_scale_denom) divider_x

				,COALESCE(ST_Y(_layout_frame_base_point) + _layout_frame_height + _layout_page_margin_top_bottom * _layout_map_scale_denom) divider_y1
				,COALESCE(ST_Y(_layout_frame_base_point) + _layout_frame_height) divider_y2

				,COALESCE(ST_Y(_layout_frame_base_point)) divider_y3
				,COALESCE(ST_Y(_layout_frame_base_point) - _layout_page_margin_top_bottom * _layout_map_scale_denom) divider_y4
		)

		,layout_page_divider_top_bottom AS(
			SELECT
				ST_Union(
					ST_Union(
						ST_MakeLine(
							ST_MakePoint(divider_x1, divider_y)
							,ST_MakePoint(divider_x2, divider_y)
						)
						,ST_MakeLine(
							ST_MakePoint(divider_x3, divider_y)
							,ST_MakePoint(divider_x4, divider_y)
						)
					)
				) AS geom
			FROM generate_series(1, _layout_pages_top_bottom - 1) g
				,COALESCE(ST_Y(_layout_frame_base_point) - _layout_page_margin_top_bottom * _layout_map_scale_denom + g * _layout_page_height * _layout_map_scale_denom) divider_y

				,COALESCE(ST_X(_layout_frame_base_point) + _layout_frame_width + _layout_page_margin_left_right * _layout_map_scale_denom) divider_x1
				,COALESCE(ST_X(_layout_frame_base_point) + _layout_frame_width) divider_x2

				,COALESCE(ST_X(_layout_frame_base_point)) divider_x3
				,COALESCE(ST_X(_layout_frame_base_point) - _layout_page_margin_left_right * _layout_map_scale_denom) divider_x4
		)

		,layout_page_frame AS(
			SELECT
				ST_Collect(
					outer_frame
					,inner_frame
				) AS geom
				,ST_Collect(
					ARRAY[
						ST_PointN(outer_frame, 1)
						,ST_PointN(outer_frame, 2)
						,ST_PointN(outer_frame, 3)
						,ST_PointN(outer_frame, 4)
					]
				) AS extent_points
			FROM ST_ExteriorRing(_layout_frame_single) inner_frame
				,ST_MakeLine(
					ARRAY[
						ST_Translate(ST_PointN(inner_frame, 1), _layout_page_margin_left_right * _layout_map_scale_denom * -1, _layout_page_margin_top_bottom * _layout_map_scale_denom * -1)
						,ST_Translate(ST_PointN(inner_frame, 2), _layout_page_margin_left_right * _layout_map_scale_denom * -1, _layout_page_margin_top_bottom * _layout_map_scale_denom)
						,ST_Translate(ST_PointN(inner_frame, 3), _layout_page_margin_left_right * _layout_map_scale_denom, _layout_page_margin_top_bottom * _layout_map_scale_denom)
						,ST_Translate(ST_PointN(inner_frame, 4), _layout_page_margin_left_right * _layout_map_scale_denom, _layout_page_margin_top_bottom * _layout_map_scale_denom * -1)
						,ST_Translate(ST_PointN(inner_frame, 1), _layout_page_margin_left_right * _layout_map_scale_denom * -1, _layout_page_margin_top_bottom * _layout_map_scale_denom * -1)
					]
				) outer_frame
		)

	SELECT
		ST_Union(
			ARRAY[
				layout_page_frame.geom
				,ST_SetSRID(layout_page_divider_left_right.geom, 25832)
				,ST_SetSRID(layout_page_divider_top_bottom.geom, 25832)
			]
		)
		,extent_points
	FROM layout_page_frame
		,layout_page_divider_left_right
		,layout_page_divider_top_bottom
	INTO _layout_geom
		,_layout_extent_points;


	IF _tegningshoved_reference_point IS NOT NULL THEN

		_layout_geom_inkl_tegningshoved := COALESCE(
												ST_Union(
													_layout_geom
													,ST_Translate(
														ST_Scale(
															_tegningshoved_layout
															,ST_MakePoint(_layout_map_scale_denom, _layout_map_scale_denom)
															,_tegningshoved_reference_point
														)
														,ST_X(_layout_reference_point) - ST_X(_tegningshoved_reference_point)
														,ST_Y(_layout_reference_point) - ST_Y(_tegningshoved_reference_point)
													)
												)
												,_layout_geom
											);

	ELSE

		_layout_geom_inkl_tegningshoved := _layout_geom;

	END IF;


	-- Fjern tegningshoved fra frame
	_layout_frame := ST_Multi(
						COALESCE(
							ST_Difference(
								_layout_frame_single
								,ST_Translate(
									ST_Scale(
										_tegningshoved_frame
										,ST_MakePoint(_layout_map_scale_denom, _layout_map_scale_denom)
										,_tegningshoved_reference_point
									)
									,ST_X(_layout_reference_point) - ST_X(_tegningshoved_reference_point)
									,ST_Y(_layout_reference_point) - ST_Y(_tegningshoved_reference_point)
								)
							)
							,_layout_frame_single
						)
					);


	-- Rotér tilbage til oprindelig orientering
	_layout_frame := ST_Rotate(
						_layout_frame
						,-radians(_layout_rotation)
						,_azimuth_p1
					);


	_layout_geom := ST_Rotate(
						_layout_geom
						,-radians(_layout_rotation)
						,_azimuth_p1
					);


	_layout_geom_inkl_tegningshoved := ST_Rotate(
						_layout_geom_inkl_tegningshoved
						,-radians(_layout_rotation)
						,_azimuth_p1
					);


	_layout_reference_point := ST_Rotate(
							_layout_reference_point
							,-radians(_layout_rotation)
							,_azimuth_p1
						);


	_layout_extent_points := ST_Rotate(
							_layout_extent_points
							,-radians(_layout_rotation)
							,_azimuth_p1
						);

	RETURN;

END $BODY$;




/* DROP FUNCTION IF EXISTS aflob_plan.layout(
	_plan_guid uuid
) CASCADE;
--*/
/*
CREATE OR REPLACE FUNCTION aflob_plan.layout(
	_plan_guid uuid

	,OUT _layout_geom geometry('MULTILINESTRING', 25832)
	,OUT _layout_geom_inkl_tegningshoved geometry('MULTILINESTRING', 25832)
	,OUT _layout_frame geometry('MULTIPOLYGON', 25832)
	,OUT _layout_reference_point geometry('POINT', 25832)
	,OUT _layout_extent_points geometry('MULTIPOINT', 25832)

	,OUT _layout_rotation double precision
	,OUT _layout_pages_left_right integer
	,OUT _layout_pages_top_bottom integer
	,OUT _layout_too_wide integer
	,OUT _layout_too_high integer

	,OUT _tegningshoved_reference_guid uuid
)
	RETURNS RECORD
	STABLE
	STRICT
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	SELECT
		f._layout_geom
		,f._layout_geom_inkl_tegningshoved
		,f._layout_frame
		,f._layout_reference_point
		,f._layout_extent_points

		,f._layout_rotation
		,f._layout_pages_left_right
		,f._layout_pages_top_bottom
		,f._layout_too_wide
		,f._layout_too_high
	FROM aflob_plan.f_planer p
		,aflob_plan.layout(
			_geom := p.geom

			,_tegningshoved_guid := p.tegningshoved_guid
			,_tegningshoved_egen_side := p.tegningshoved_egen_side

			,_layout_page_width := p.layout_page_width
			,_layout_page_height := p.layout_page_height
			,_layout_page_margin_left_right := p.layout_page_margin_left_right
			,_layout_page_margin_top_bottom := p.layout_page_margin_top_bottom

			,_layout_page_flip_top_bottom := p.layout_page_flip_top_bottom

			,_layout_max_pages_left_right := p.layout_max_pages_left_right
			,_layout_max_pages_top_bottom := p.layout_max_pages_top_bottom

			,_layout_map_scale_denom := p.layout_map_scale_denom
			,_layout_map_margin_left_right := p.layout_map_margin_left_right
			,_layout_map_margin_top_bottom := p.layout_map_margin_top_bottom
		) f
	WHERE p.guid = _plan_guid
		AND (
			p.delt = 1
			OR p.oprettet_af = session_user
		)
	INTO _layout_geom
		,_layout_geom_inkl_tegningshoved
		,_layout_frame
		,_layout_reference_point
		,_layout_extent_points

		,_layout_rotation
		,_layout_pages_left_right
		,_layout_pages_top_bottom
		,_layout_too_wide
		,_layout_too_high

		,_tegningshoved_reference_guid;

	RETURN;

END $BODY$;
*/



-- DROP FUNCTION IF EXISTS aflob_plan.f_planer_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.f_planer_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF (TG_OP = 'DELETE') THEN

		DELETE FROM aflob_plan.f_indhold_p i
			WHERE i.plan_guid = OLD.guid;

		DELETE FROM aflob_plan.f_indhold_l i
			WHERE i.plan_guid = OLD.guid;

		DELETE FROM aflob_plan.f_indhold_a i
			WHERE i.plan_guid = OLD.guid;

		RETURN OLD;

	ELSIF (TG_OP = 'UPDATE') THEN

		NEW.guid := OLD.guid;
		NEW.datooprettet := OLD.datooprettet;
		NEW.oprettet_af := OLD.oprettet_af;
		NEW.datoopdateret := current_timestamp;
		NEW.initialer := session_user;

	ELSIF (TG_OP = 'INSERT') THEN

		NEW.guid := COALESCE(NEW.guid, uuid_generate_v4());

		NEW.datooprettet := current_timestamp;
		NEW.oprettet_af := session_user;
		NEW.datoopdateret := current_timestamp;
		NEW.initialer := session_user;

	END IF;

	-- Default values
	NEW.aktiv := COALESCE(NEW.aktiv, 1);
	NEW.delt := COALESCE(NEW.delt, 1);

	NEW.plan_nr := COALESCE(NEW.plan_nr, '0000');


	SELECT
		_layout_geom
		,_layout_geom_inkl_tegningshoved
		,_layout_frame
		,_layout_reference_point
		,_layout_extent_points

		,_layout_rotation
		,_layout_pages_left_right
		,_layout_pages_top_bottom
		,_layout_too_wide
		,_layout_too_high

		,_tegningshoved_reference_guid
	FROM aflob_plan.layout(
		_geom := NEW.geom

		,_tegningshoved_guid := NEW.tegningshoved_guid
		,_tegningshoved_egen_side := NEW.tegningshoved_egen_side

		,_layout_page_width := NEW.layout_page_width
		,_layout_page_height := NEW.layout_page_height
		,_layout_page_margin_left_right := NEW.layout_page_margin_left_right
		,_layout_page_margin_top_bottom := NEW.layout_page_margin_top_bottom

		,_layout_page_flip_top_bottom := NEW.layout_page_flip_top_bottom

		,_layout_max_pages_left_right := NEW.layout_max_pages_left_right
		,_layout_max_pages_top_bottom := NEW.layout_max_pages_top_bottom

		,_layout_map_scale_denom := NEW.layout_map_scale_denom
		,_layout_map_margin_left_right := NEW.layout_map_margin_left_right
		,_layout_map_margin_top_bottom := NEW.layout_map_margin_top_bottom
	)
	INTO NEW.layout_geom
		,NEW.layout_geom_inkl_tegningshoved
		,NEW.layout_frame
		,NEW.layout_reference_point
		,NEW.layout_extent_points

		,NEW.layout_rotation
		,NEW.layout_pages_left_right
		,NEW.layout_pages_top_bottom
		,NEW.layout_too_wide
		,NEW.layout_too_high

		,NEW.tegningshoved_reference_guid;

	RETURN NEW;

END $BODY$;




-- DROP FUNCTION IF EXISTS aflob_plan.v_planer_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_planer_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_plan_guid uuid[] := ARRAY[]::uuid[];

BEGIN

	IF TG_OP = 'DELETE' THEN

		DELETE FROM aflob_plan.f_planer
			WHERE guid = OLD.guid;

		RETURN OLD;

	END IF;

	IF NEW.split_plan > 1 THEN

		WITH

			cte1 AS(
				INSERT INTO aflob_plan.f_planer(
					guid
					,geom
					,aktiv
					,delt


					-- Plan
					,plan_nr
					,plan_navn
					,plan_type

					,plan_dato

					,vejnavn
					,vejnavn_fra
					,vejnavn_til
					,vejnavn_nr
					,vejnavn_nr_total

					,projekteret
					,tegnet
					,kontrol
					,godkendt
					,revision

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
				) SELECT
					uuid_generate_v4()
					,sub.geom
					,NEW.aktiv
					,NEW.delt


					-- Plan
					,NEW.plan_nr
					,NEW.plan_navn
					,NEW.plan_type

					,NEW.plan_dato

					,NEW.vejnavn
					,NEW.vejnavn_fra
					,NEW.vejnavn_til
					,NEW.vejnavn_nr
					,NEW.vejnavn_nr_total

					,NEW.projekteret
					,NEW.tegnet
					,NEW.kontrol
					,NEW.godkendt
					,NEW.revision

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
				FROM generate_series(2, NEW.split_plan) g
					,ST_LineSubstring(
						NEW.geom
						,(g - 1)::double precision / NEW.split_plan
						,g::double precision / NEW.split_plan
					) sub(geom)
				RETURNING guid
			)

		SELECT
			_plan_guid || array_agg(c.guid)
		FROM cte1 c
		INTO _plan_guid;


		NEW.geom := ST_LineSubstring(
						NEW.geom
						,0
						,1::double precision / NEW.split_plan
					);

	END IF;


	IF TG_OP = 'UPDATE' THEN

		UPDATE aflob_plan.f_planer
			SET
				geom = NEW.geom
				,aktiv = NEW.aktiv
				,delt = NEW.delt


				-- Plan
				,plan_nr = NEW.plan_nr
				,plan_navn = NEW.plan_navn
				,plan_type = NEW.plan_type

				,plan_dato = NEW.plan_dato

				,vejnavn = NEW.vejnavn
				,vejnavn_fra = NEW.vejnavn_fra
				,vejnavn_til = NEW.vejnavn_til
				,vejnavn_nr = NEW.vejnavn_nr
				,vejnavn_nr_total = NEW.vejnavn_nr_total

				,projekteret = NEW.projekteret
				,tegnet = NEW.tegnet
				,kontrol = NEW.kontrol
				,godkendt = NEW.godkendt
				,revision = NEW.revision

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
		WHERE guid = OLD.guid;


		_plan_guid := _plan_guid || OLD.guid;

	ELSIF TG_OP = 'INSERT' THEN

		INSERT INTO aflob_plan.f_planer(
			guid
			,geom
			,aktiv
			,delt


			-- Plan
			,plan_nr
			,plan_navn
			,plan_type

			,plan_dato

			,vejnavn
			,vejnavn_fra
			,vejnavn_til
			,vejnavn_nr
			,vejnavn_nr_total

			,projekteret
			,tegnet
			,kontrol
			,godkendt
			,revision

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
			COALESCE(NEW.guid, uuid_generate_v4())
			,NEW.geom
			,NEW.aktiv
			,NEW.delt


			-- Plan
			,NEW.plan_nr
			,NEW.plan_navn
			,NEW.plan_type

			,NEW.plan_dato

			,NEW.vejnavn
			,NEW.vejnavn_fra
			,NEW.vejnavn_til
			,NEW.vejnavn_nr
			,NEW.vejnavn_nr_total

			,NEW.projekteret
			,NEW.tegnet
			,NEW.kontrol
			,NEW.godkendt
			,NEW.revision

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
		) RETURNING
			_plan_guid || guid
		INTO _plan_guid;

	END IF;

	IF TG_OP IN('INSERT', 'UPDATE') THEN

		IF NEW.aktiver_plan BETWEEN 1 AND 3 THEN

			UPDATE aflob_plan.v_lst_settings_user
				SET
					plan_guids = (
						SELECT
							array_agg(a.guid)::text
						FROM (
							SELECT
								u.guid
							FROM UNNEST(_plan_guid) u(guid)
							WHERE NEW.aktiver_plan BETWEEN 1 AND 2

							UNION

							SELECT
								u.guid
							FROM aflob_plan.v_lst_settings_user s
								,UNNEST(s.plan_guids::uuid[]) u(guid)
							WHERE NEW.aktiver_plan = 2
								OR (
									NEW.aktiver_plan = 3
									AND u.guid != ALL(_plan_guid)
								)
						) a
					);

		END IF;

		RETURN NEW;

	END IF;

END $BODY$;




-- DROP TABLE IF EXISTS aflob_plan.f_planer CASCADE;

CREATE TABLE aflob_plan.f_planer(
	guid uuid PRIMARY KEY DEFAULT uuid_generate_v4()

	,datooprettet timestamp NOT NULL
	,oprettet_af character varying(50) NOT NULL
	,datoopdateret timestamp NOT NULL
	,initialer character varying(50) NOT NULL

	,geom geometry('GEOMETRY', 25832) NOT NULL
	,aktiv integer NOT NULL DEFAULT 1
	,delt integer NOT NULL DEFAULT 1


	-- Plan
	,plan_nr character varying NOT NULL
	,plan_navn character varying
	,plan_type character varying

	,plan_dato date

	,vejnavn character varying
	,vejnavn_fra character varying
	,vejnavn_til character varying
	,vejnavn_nr integer
	,vejnavn_nr_total integer

	,projekteret character varying
	,tegnet character varying
	,kontrol character varying
	,godkendt character varying
	,revision character varying

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

	-- Calculated
	,layout_geom geometry('MULTILINESTRING', 25832)
	,layout_geom_inkl_tegningshoved geometry('MULTILINESTRING', 25832)
	,layout_frame geometry('MULTIPOLYGON', 25832)
	,layout_reference_point geometry('POINT', 25832)
	,layout_extent_points geometry('MULTIPOINT', 25832)

	,layout_rotation double precision
	,layout_pages_left_right integer
	,layout_pages_top_bottom integer
	,layout_too_wide integer
	,layout_too_high integer

	,tegningshoved_reference_guid uuid
);


-- DROP INDEX IF EXISTS aflob_plan.f_planer_geom_gist;
CREATE INDEX plan_f_planer_geom_gist ON aflob_plan.f_planer USING gist(geom);

-- DROP INDEX IF EXISTS aflob_plan.f_planer_import_guid;
CREATE INDEX plan_f_planer_import_guid ON aflob_plan.f_planer(import_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_planer_import_guid_text;
CREATE INDEX plan_f_planer_import_guid_text ON aflob_plan.f_planer((import_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.f_planer_tegningshoved_guid;
CREATE INDEX plan_f_planer_tegningshoved_guid ON aflob_plan.f_planer(tegningshoved_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_planer_tegningshoved_guid_text;
CREATE INDEX plan_f_planer_tegningshoved_guid_text ON aflob_plan.f_planer((tegningshoved_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.f_planer_tegningshoved_reference_guid;
CREATE INDEX plan_f_planer_tegningshoved_reference_guid ON aflob_plan.f_planer(tegningshoved_reference_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_planer_tegningshoved_reference_guid_text;
CREATE INDEX plan_f_planer_tegningshoved_reference_guid_text ON aflob_plan.f_planer((tegningshoved_reference_guid::text));


CREATE TRIGGER plan_f_planer_trg_iud
	BEFORE INSERT OR UPDATE OR DELETE
		ON aflob_plan.f_planer
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.f_planer_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_planer CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_planer AS

SELECT
	p.*

	,plan_navn_calc
	,CASE WHEN p.aktiv = 1 THEN '' ELSE '*' END || p.plan_nr || COALESCE(' ' || plan_navn_calc, '') || CASE WHEN p.aktiv = 1 THEN '' ELSE '*' END AS plan_navn_calc_udv
	,regexp_replace(
		regexp_replace(
			COALESCE(COALESCE(NULLIF(TRIM(vejnavn), ''), plan_navn) || '_') || p.plan_nr
			,'é'
			,'e'
			,'g'
		)
		,'[^a-zA-ZæøåÆØÅ0-9_]'
		,'_'
		,'g'
	) AS filnavn_calc

	-- Calc
	-- Import / Export
	,COALESCE(p.import_guid, s.import_guid) AS import_guid_calc
	,COALESCE(NULLIF(TRIM(p.export_dxf_path), ''), s.export_dxf_path) AS export_dxf_path_calc

	-- Tegningshoved
	,COALESCE(p.tegningshoved_guid, s.tegningshoved_guid) AS tegningshoved_guid_calc
	,COALESCE(p.tegningshoved_egen_side, s.tegningshoved_egen_side) AS tegningshoved_egen_side_calc

	-- Layout
	,COALESCE(p.layout_page_width, s.layout_page_width) AS layout_page_width_calc
	,COALESCE(p.layout_page_height, s.layout_page_height) AS layout_page_height_calc
	,COALESCE(p.layout_page_margin_left_right, s.layout_page_margin_left_right) AS layout_page_margin_left_right_calc
	,COALESCE(p.layout_page_margin_top_bottom, s.layout_page_margin_top_bottom) AS layout_page_margin_top_bottom_calc

	,COALESCE(p.layout_page_flip_top_bottom, s.layout_page_flip_top_bottom) AS layout_page_flip_top_bottom_calc

	,COALESCE(p.layout_max_pages_left_right, s.layout_max_pages_left_right) AS layout_max_pages_left_right_calc
	,COALESCE(p.layout_max_pages_top_bottom, s.layout_max_pages_top_bottom) AS layout_max_pages_top_bottom_calc

	,COALESCE(p.layout_map_scale_denom, s.layout_map_scale_denom) AS layout_map_scale_denom_calc
	,COALESCE(p.layout_map_margin_left_right, s.layout_map_margin_left_right) AS layout_map_margin_left_right_calc
	,COALESCE(p.layout_map_margin_top_bottom, s.layout_map_margin_top_bottom) AS layout_map_margin_top_bottom_calc

	-- Symbol
	,COALESCE(p.symbol_scale, s.symbol_scale) AS symbol_scale_calc
	,COALESCE(p.symbol_rotation, s.symbol_rotation) AS symbol_rotation_calc

	,COALESCE(p.symbol_fill_color, s.symbol_fill_color) AS symbol_fill_color_calc
	,COALESCE(p.symbol_fill_color_opacity, s.symbol_fill_color_opacity) AS symbol_fill_color_opacity_calc

	,COALESCE(p.symbol_outline_color, s.symbol_outline_color) AS symbol_outline_color_calc
	,COALESCE(p.symbol_outline_color_opacity, s.symbol_outline_color_opacity) AS symbol_outline_color_opacity_calc
	,COALESCE(p.symbol_outline_width_mm, s.symbol_outline_width_mm) AS symbol_outline_width_mm_calc
	,COALESCE(p.symbol_outline_dash_mm, s.symbol_outline_dash_mm) AS symbol_outline_dash_mm_calc

	-- Label
	,COALESCE(p.label_color, s.label_color) AS label_color_calc
	,COALESCE(p.label_font, s.label_font) AS label_font_calc
	,COALESCE(p.label_rotation, s.label_rotation) AS label_rotation_calc
	,COALESCE(p.label_size, s.label_size) AS label_size_calc
	,COALESCE(p.label_spacing, s.label_spacing) AS label_spacing_calc

	,COALESCE(p.label_adjustment, s.label_adjustment) AS label_adjustment_calc
	,COALESCE(p.label_offset_x, s.label_offset_x) AS label_offset_x_calc
	,COALESCE(p.label_offset_y, s.label_offset_y) AS label_offset_y_calc

	,COALESCE(p.label_frame, s.label_frame) AS label_frame_calc
	,COALESCE(p.label_frame_width_mm, s.label_frame_width_mm) AS label_frame_width_mm_calc
	,COALESCE(p.label_frame_adjustment, s.label_frame_adjustment) AS label_frame_adjustment_calc
	,COALESCE(p.label_frame_margin_left, s.label_frame_margin_left) AS label_frame_margin_left_calc
	,COALESCE(p.label_frame_margin_right, s.label_frame_margin_right) AS label_frame_margin_right_calc
	,COALESCE(p.label_frame_margin_top, s.label_frame_margin_top) AS label_frame_margin_top_calc
	,COALESCE(p.label_frame_margin_bottom, s.label_frame_margin_bottom) AS label_frame_margin_bottom_calc

	,COALESCE(p.label_callout, s.label_callout) AS label_callout_calc

	-- Font
	,COALESCE(p.font_size_factor_x, s.font_size_factor_x) AS font_size_factor_x_calc
	,COALESCE(p.font_size_factor_y, s.font_size_factor_y) AS font_size_factor_y_calc

	,CASE
		WHEN p.aktiv = 0
		THEN -1
		WHEN p.aktiv = 1
			AND p.guid = ANY(s.plan_guids::uuid[])
		THEN 1
		ELSE 0
	END AS selected_
	,NULL::integer AS aktiver_plan
	,NULL::integer AS split_plan
FROM aflob_plan.f_planer p
LEFT JOIN aflob_plan.v_lst_settings s ON TRUE

INNER JOIN COALESCE(
		CASE
			WHEN NULLIF(p.vejnavn, '') IS NOT NULL
				OR (
					p.vejnavn IS NULL
					AND (
						p.vejnavn_fra IS NOT NULL
						OR p.vejnavn_til IS NOT NULL
					)
				)
			THEN COALESCE(p.vejnavn, 'VEJNAVN MANGLER') || COALESCE(
					' / ' || NULLIF(p.vejnavn_fra, '') || ' - ' || NULLIF(p.vejnavn_til, '') ||
						COALESCE(' | ' || p.vejnavn_nr::text || '/' || p.vejnavn_nr_total::text, '')
					,''
				)
			ELSE NULLIF(p.plan_navn, '')
		END
	) plan_navn_calc ON TRUE
-- INNER JOIN COALESCE(
		-- CASE
			-- WHEN p.aktiv = 1
				-- AND p.guid = ANY(s.plan_guids::uuid[])
			-- THEN 1
			-- ELSE 0
		-- END
	-- ) selected_ ON TRUE

-- LEFT JOIN LATERAL(
	-- SELECT
		-- l._layout_geom AS layout_geom
		-- ,l._layout_geom_inkl_tegningshoved AS layout_geom_inkl_tegningshoved
		-- ,l._layout_frame AS layout_frame
		-- ,l._layout_reference_point AS layout_reference_point
		-- ,l._layout_extent_points AS layout_extent_points
	-- FROM aflob_plan.layout(
		-- CASE
			-- WHEN selected_ = 1
			-- THEN p.guid
		-- END
	-- ) l
-- ) l ON TRUE

-- LEFT JOIN LATERAL(
	-- SELECT
		-- l._layout_geom AS layout_geom
		-- ,l._layout_geom_inkl_tegningshoved AS layout_geom_inkl_tegningshoved
		-- ,l._layout_frame AS layout_frame
		-- ,l._layout_reference_point AS layout_reference_point
		-- ,l._layout_extent_points AS layout_extent_points
	-- FROM aflob_plan.layout(
			-- _geom := CASE
						-- WHEN selected_ = 1
						-- THEN p.geom
					-- END

			-- ,_tegningshoved_guid := p.tegningshoved_guid
			-- ,_tegningshoved_egen_side := p.tegningshoved_egen_side

			-- ,_layout_page_width := p.layout_page_width
			-- ,_layout_page_height := p.layout_page_height
			-- ,_layout_page_margin_left_right := p.layout_page_margin_left_right
			-- ,_layout_page_margin_top_bottom := p.layout_page_margin_top_bottom

			-- ,_layout_page_flip_top_bottom := p.layout_page_flip_top_bottom

			-- ,_layout_max_pages_left_right := p.layout_max_pages_left_right
			-- ,_layout_max_pages_top_bottom := p.layout_max_pages_top_bottom

			-- ,_layout_map_scale_denom := p.layout_map_scale_denom
			-- ,_layout_map_margin_left_right := p.layout_map_margin_left_right
			-- ,_layout_map_margin_top_bottom := p.layout_map_margin_top_bottom
		-- ) l
-- ) l ON TRUE
WHERE p.delt = 1
	OR p.initialer = session_user;


CREATE TRIGGER plan_v_planer_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_planer
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_planer_trg();



