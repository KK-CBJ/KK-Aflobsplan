/* DROP FUNCTION IF EXISTS aflob_plan.label_meta(
	_label text
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.label_meta(
	_label text

	,OUT _label_array text[]
	,OUT _label_max_length integer
	,OUT _label_rows integer
)
	RETURNS RECORD
	IMMUTABLE
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	SELECT
		array_agg(t.label ORDER BY u.ordinality)
		,MAX(LENGTH(t.label))
		,COUNT(*)
	FROM string_to_array(
			regexp_replace(
				regexp_replace(
						_label
						,'^[^\w]+'
						,''
				)
				,'[^\w]+$'
				,''
			)
			,E'\n'
		) label_array
		,UNNEST(label_array) WITH ORDINALITY u(label)
		,TRIM(u.label) t(label)
	INTO _label_array
		,_label_max_length
		,_label_rows;

	RETURN;

END $BODY$;

COMMENT ON FUNCTION aflob_plan.label_meta(
	_label text
) IS 'Omdanner label til basisinfo omkring bredde/højde af labelramme, samt array med hver linje.';




/* DROP FUNCTION IF EXISTS aflob_plan.label_layout(
	_label_max_length integer
	,_label_rows integer

	,_label_rotation double precision
	,_label_size double precision
	,_label_spacing double precision

	,_label_adjustment integer

	,_label_frame_adjustment integer
	,_label_frame_margin_left double precision
	,_label_frame_margin_right double precision
	,_label_frame_margin_top double precision
	,_label_frame_margin_bottom double precision

	,_font_size_factor_x double precision
	,_font_size_factor_y double precision
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.label_layout(
	_label_max_length integer DEFAULT NULL
	,_label_rows integer DEFAULT NULL

	,_label_rotation double precision DEFAULT NULL
	,_label_size double precision DEFAULT NULL
	,_label_spacing double precision DEFAULT NULL

	,_label_adjustment integer DEFAULT NULL

	,_label_frame_adjustment integer DEFAULT NULL
	,_label_frame_margin_left double precision DEFAULT NULL
	,_label_frame_margin_right double precision DEFAULT NULL
	,_label_frame_margin_top double precision DEFAULT NULL
	,_label_frame_margin_bottom double precision DEFAULT NULL

	,_font_size_factor_x double precision DEFAULT NULL
	,_font_size_factor_y double precision DEFAULT NULL

	,OUT _label_geom geometry('LINESTRING', 25832)
	,OUT _label_points geometry('MULTIPOINT', 25832)
	,OUT _label_points_centroid geometry('POINT', 25832)
)
	RETURNS RECORD
	IMMUTABLE
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_label_frame_width double precision;
	_label_frame_height double precision;

	_label_frame_adjustment_x double precision;
	_label_frame_adjustment_y double precision;

	_label_base_point geometry('POINT', 25832);

	_label_adjustment_x double precision := 0;

	_exp_factor numeric := -0.0018;

BEGIN


	-- _label_frame_width := _label_size * _label_max_length * _font_size_factor_x
							-- + _label_frame_margin_left
							-- + _label_frame_margin_right;

	-- _label_frame_height := (_label_size * _label_rows + _label_spacing * (_label_rows - 1)) * _font_size_factor_y
							-- + _label_frame_margin_top
							-- + _label_frame_margin_bottom;



	-- IF _label_adjustment = 4 THEN

		-- _label_adjustment_x := _label_size * _label_max_length * _font_size_factor_x / 2;

	-- ELSIF _label_adjustment = 3 THEN

		-- _label_adjustment_x := _label_size * _label_max_length * _font_size_factor_x;

	-- END IF;


	_label_frame_width := _label_size * _label_max_length * _font_size_factor_x * POWER(_label_max_length, _label_max_length * _font_size_factor_x * _exp_factor)
							+ _label_frame_margin_left
							+ _label_frame_margin_right;

	_label_frame_height := (_label_size * _label_rows + _label_spacing * (_label_rows - 1)) * _font_size_factor_y
							+ _label_frame_margin_top
							+ _label_frame_margin_bottom;



	IF _label_adjustment = 4 THEN

		_label_adjustment_x := _label_size * _label_max_length * _font_size_factor_x * POWER(_label_max_length, _label_max_length * _font_size_factor_x * _exp_factor) / 2;

	ELSIF _label_adjustment = 3 THEN

		_label_adjustment_x := _label_size * _label_max_length * _font_size_factor_x * POWER(_label_max_length, _label_max_length * _font_size_factor_x * _exp_factor);

	END IF;



	SELECT
		_label_frame_width * x_factor
		,_label_frame_height * y_factor
	FROM (
		VALUES
			 (0, 'Venstre, over'	,-1		,0)
			,(1, 'Center, over'		,-0.5	,0)
			,(2, 'Højre, over'		,0		,0)
			,(3, 'Venstre'			,-1		,-0.5)
			,(4, 'Center'			,-0.5	,-0.5)
			,(5, 'Højre'			,0		,-0.5)
			,(6, 'Venstre, under'	,-1		,-1)
			,(7, 'Center, under'	,-0.5	,-1)
			,(8, 'Højre, under'		,0		,-1)
	) adjustment(kode, beskrivelse, x_factor, y_factor)
	WHERE adjustment.kode = COALESCE(_label_frame_adjustment, 2)
	INTO _label_frame_adjustment_x
		,_label_frame_adjustment_y;



	_label_geom := ST_MakeLine(
						ARRAY[
							ST_MakePoint(0, 0)
							,ST_MakePoint(0, _label_frame_height)
							,ST_MakePoint(_label_frame_width, _label_frame_height)
							,ST_MakePoint(_label_frame_width, 0)
							,ST_MakePoint(0, 0)
						]
					);



	_label_base_point := ST_MakePoint(
							_label_frame_margin_left + _label_adjustment_x
							,_label_frame_margin_bottom + _label_size * _font_size_factor_y / 2
						);



	SELECT
		ST_Multi(
			ST_Collect(
				pts
				ORDER BY CASE
							WHEN g = 0
							THEN 0
							ELSE 1::double precision / g
						END DESC)
		)
	FROM ST_MakeLine(
			ST_SetSRID(_label_base_point, 0)
			,ST_MakePoint(
				ST_X(_label_base_point)
				,_label_frame_height - _label_frame_margin_top - (_label_size * _font_size_factor_y / 2)
			)
		) line_pts
		,generate_series(0, _label_rows - 1) g
		,ST_LineInterpolatePoint(
			line_pts
			,CASE
				WHEN g = 0
				THEN 0
				ELSE 1::double precision / g
			END
		) pts
	INTO _label_points;

	_label_points_centroid := ST_Centroid(_label_points);



	_label_geom := ST_SetSRID(
						ST_Rotate(
							ST_Translate(
								_label_geom
								,_label_frame_adjustment_x
								,_label_frame_adjustment_y
							)
							,-radians(_label_rotation)
						)
						,25832
					);

	_label_points := ST_SetSRID(
						ST_Multi(
							ST_Rotate(
								ST_Translate(
									_label_points
									,_label_frame_adjustment_x
									,_label_frame_adjustment_y
								)
								,-radians(_label_rotation)
							)
						)
						,25832
					);

	_label_points_centroid := ST_SetSRID(
								ST_Rotate(
									ST_Translate(
										_label_points_centroid
										,_label_frame_adjustment_x
										,_label_frame_adjustment_y
									)
									,-radians(_label_rotation)
								)
								,25832
							);


	RETURN;

END $BODY$;

COMMENT ON FUNCTION aflob_plan.label_layout(
	_label_max_length integer
	,_label_rows integer

	,_label_rotation double precision
	,_label_size double precision
	,_label_spacing double precision

	,_label_adjustment integer

	,_label_frame_adjustment integer
	,_label_frame_margin_left double precision
	,_label_frame_margin_right double precision
	,_label_frame_margin_top double precision
	,_label_frame_margin_bottom double precision

	,_font_size_factor_x double precision
	,_font_size_factor_y double precision
) IS 'Generisk funktion baseret udelukkende på basisinfo. Danner en labelramme og et punkt pr. linje i label omkring koordinatsæt 0,0.';




/* DROP FUNCTION IF EXISTS aflob_plan.label(
	_label character varying

	,_label_point geometry('POINT', 25832)
	,_label_reference_point geometry('POINT', 25832)

	,_plan_guid uuid

	,_label_font character varying
	,_label_rotation double precision
	,_label_size double precision
	,_label_spacing double precision

	,_label_adjustment integer
	,_label_offset_x double precision
	,_label_offset_y double precision

	,_label_frame integer
	,_label_frame_adjustment integer
	,_label_frame_margin_left double precision
	,_label_frame_margin_right double precision
	,_label_frame_margin_top double precision
	,_label_frame_margin_bottom double precision

	,_label_callout integer

	,_font_size_factor_x double precision
	,_font_size_factor_y double precision
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.label(
	_label character varying


	,_label_reference_point geometry('POINT', 25832)
	,_label_point geometry('POINT', 25832) DEFAULT NULL

	,_plan_guid uuid DEFAULT NULL

	,_label_font character varying DEFAULT NULL
	,_label_rotation double precision DEFAULT NULL
	,_label_size double precision DEFAULT NULL
	,_label_spacing double precision DEFAULT NULL

	,_label_adjustment integer DEFAULT NULL
	,_label_offset_x double precision DEFAULT NULL
	,_label_offset_y double precision DEFAULT NULL

	,_label_frame integer DEFAULT NULL
	,_label_frame_adjustment integer DEFAULT NULL
	,_label_frame_margin_left double precision DEFAULT NULL
	,_label_frame_margin_right double precision DEFAULT NULL
	,_label_frame_margin_top double precision DEFAULT NULL
	,_label_frame_margin_bottom double precision DEFAULT NULL

	,_label_callout integer DEFAULT NULL

	,_font_size_factor_x double precision DEFAULT NULL
	,_font_size_factor_y double precision DEFAULT NULL

	,OUT _label_array text[]
	,OUT _label_geom geometry('LINESTRING', 25832)
	,OUT _label_points geometry('MULTIPOINT', 25832)
	,OUT _label_points_centroid geometry('POINT', 25832)

	,OUT _font character varying
	,OUT _font_style character varying
)
	RETURNS RECORD
	STABLE
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_label_max_length integer;
	_label_rows integer;

BEGIN

	IF NULLIF(TRIM(_label), '') IS NULL THEN

		RETURN;

	END IF;

	-- Label meta
	SELECT
		l._label_array
		,l._label_max_length
		,l._label_rows
	FROM aflob_plan.label_meta(
		NULLIF(TRIM(_label), '')
	) l
	INTO _label_array
		,_label_max_length
		,_label_rows;




	-- Default værdier fra plan
	IF _plan_guid IS NOT NULL
		AND EXISTS(
			SELECT
				'1'
			FROM aflob_plan.v_planer p
			WHERE p.guid = _plan_guid
		)
	THEN

		SELECT
			COALESCE(_label_rotation, p.label_rotation_calc, 0)
			,COALESCE(_label_size, p.label_size_calc, 1)
			,COALESCE(_label_spacing, p.label_spacing_calc, 0)

			,COALESCE(_label_adjustment, p.label_adjustment_calc, 3)
			,COALESCE(_label_offset_x, p.label_offset_x_calc, 0)
			,COALESCE(_label_offset_y, p.label_offset_y_calc, 0)

			,COALESCE(_label_frame, p.label_frame_calc, 1)
			,COALESCE(_label_frame_adjustment, p.label_frame_adjustment_calc, 2)
			,COALESCE(_label_frame_margin_left, p.label_frame_margin_left_calc, 0.25)
			,COALESCE(_label_frame_margin_right, p.label_frame_margin_right_calc, 0.25)
			,COALESCE(_label_frame_margin_top, p.label_frame_margin_top_calc, 0.4)
			,COALESCE(_label_frame_margin_bottom, p.label_frame_margin_bottom_calc, 0.4)

			,COALESCE(_label_callout, p.label_callout_calc, 0)

			,COALESCE(fo.font_size_factor_x * COALESCE(_font_size_factor_x, p.font_size_factor_x_calc, 1), 1)
			,COALESCE(fo.font_size_factor_y * COALESCE(_font_size_factor_y, p.font_size_factor_y_calc, 1), 1)

			,fo.font
			,fo.font_style
		FROM aflob_plan.v_planer p
		LEFT JOIN aflob_plan.lst_font fo ON fo.beskrivelse = COALESCE(_label_font, p.label_font_calc, 'KBH')
			AND fo.aktiv = 1
		WHERE p.guid = _plan_guid
		INTO _label_rotation
			,_label_size
			,_label_spacing

			,_label_adjustment
			,_label_offset_x
			,_label_offset_y

			,_label_frame
			,_label_frame_adjustment
			,_label_frame_margin_left
			,_label_frame_margin_right
			,_label_frame_margin_top
			,_label_frame_margin_bottom

			,_label_callout

			,_font_size_factor_x
			,_font_size_factor_y

			,_font
			,_font_style;

	-- Default værdier fra settings
	ELSE

		SELECT
			COALESCE(_label_rotation, s.label_rotation, 0)
			,COALESCE(_label_size, s.label_size, 1)
			,COALESCE(_label_spacing, s.label_spacing, 0)

			,COALESCE(_label_adjustment, s.label_adjustment, 3)
			,COALESCE(_label_offset_x, s.label_offset_x, 0)
			,COALESCE(_label_offset_y, s.label_offset_y, 0)

			,COALESCE(_label_frame, s.label_frame, 1)
			,COALESCE(_label_frame_adjustment, s.label_frame_adjustment, 2)
			,COALESCE(_label_frame_margin_left, s.label_frame_margin_left, 0.25)
			,COALESCE(_label_frame_margin_right, s.label_frame_margin_right, 0.25)
			,COALESCE(_label_frame_margin_top, s.label_frame_margin_top, 0.4)
			,COALESCE(_label_frame_margin_bottom, s.label_frame_margin_bottom, 0.4)

			,COALESCE(_label_callout, s.label_callout, 0)

			,COALESCE(fo.font_size_factor_x * COALESCE(_font_size_factor_x, s.font_size_factor_x, 1), 1)
			,COALESCE(fo.font_size_factor_y * COALESCE(_font_size_factor_y, s.font_size_factor_y, 1), 1)

			,fo.font
			,fo.font_style
		FROM aflob_plan.v_lst_settings s
		LEFT JOIN aflob_plan.lst_font fo ON fo.beskrivelse = COALESCE(_label_font, s.label_font, 'KBH')
			AND fo.aktiv = 1
		INTO _label_rotation
			,_label_size
			,_label_spacing

			,_label_adjustment
			,_label_offset_x
			,_label_offset_y

			,_label_frame
			,_label_frame_adjustment
			,_label_frame_margin_left
			,_label_frame_margin_right
			,_label_frame_margin_top
			,_label_frame_margin_bottom

			,_label_callout

			,_font_size_factor_x
			,_font_size_factor_y

			,_font
			,_font_style;

	END IF;




	-- Label layout
	SELECT
		l._label_geom
		,l._label_points
		,l._label_points_centroid
	FROM aflob_plan.label_layout(
		_label_max_length := _label_max_length
		,_label_rows := _label_rows

		,_label_rotation := _label_rotation
		,_label_size := _label_size
		,_label_spacing := _label_spacing

		,_label_adjustment := _label_adjustment

		,_label_frame_adjustment := _label_frame_adjustment
		,_label_frame_margin_left := _label_frame_margin_left
		,_label_frame_margin_right := _label_frame_margin_right
		,_label_frame_margin_top := _label_frame_margin_top
		,_label_frame_margin_bottom := _label_frame_margin_bottom

		,_font_size_factor_x := _font_size_factor_x
		,_font_size_factor_y := _font_size_factor_y
	) l
	INTO _label_geom
		,_label_points
		,_label_points_centroid;




	-- Label point
	_label_point := COALESCE(_label_point, _label_reference_point);

	_label_point := ST_SetSRID(
						ST_MakePoint(
							ST_X(_label_point) + _label_offset_x
							,ST_Y(_label_point) + _label_offset_y
						)
						,25832
					);

	IF _label_point IS NOT NULL THEN

		_label_points := ST_Translate(
							_label_points
							,ST_X(_label_point)
							,ST_Y(_label_point)
						);

		_label_points_centroid := ST_Translate(
									_label_points_centroid
									,ST_X(_label_point)
									,ST_Y(_label_point)
								);

		IF _label_frame = 1 THEN

			_label_geom := ST_Translate(
								_label_geom
								,ST_X(_label_point)
								,ST_Y(_label_point)
							);

			IF _label_callout = 1
				AND NOT(ST_Equals(_label_point, _label_reference_point)) THEN

				_label_geom := ST_Collect(
								_label_geom
								,ST_MakeLine(
									ST_ClosestPoint(ST_Points(_label_geom), _label_reference_point)
									,_label_reference_point
								)
							);

			END IF;

		ELSE

			_label_geom := NULL;

		END IF;

	END IF;


	RETURN;

END $BODY$;

COMMENT ON FUNCTION aflob_plan.label(
	_label character varying

	,_label_point geometry('POINT', 25832)
	,_label_reference_point geometry('POINT', 25832)

	,_plan_guid uuid

	,_label_font character varying
	,_label_rotation double precision
	,_label_size double precision
	,_label_spacing double precision

	,_label_adjustment integer
	,_label_offset_x double precision
	,_label_offset_y double precision

	,_label_frame integer
	,_label_frame_adjustment integer
	,_label_frame_margin_left double precision
	,_label_frame_margin_right double precision
	,_label_frame_margin_top double precision
	,_label_frame_margin_bottom double precision

	,_label_callout integer

	,_font_size_factor_x double precision
	,_font_size_factor_y double precision
) IS 'Forbereder basisinfo og omdanner generisk ramme til reel placering, evt. med callout til rammen.';




/* DROP FUNCTION IF EXISTS aflob_plan.label_flip_l(
	_label_flip integer
	,_label_flip_side integer

	,_label_frame_adjustment integer

	,_label_frame_margin_top double precision
	,_label_frame_margin_bottom double precision

) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.label_flip_l(
	INOUT _label_flip integer DEFAULT NULL
	,INOUT _label_flip_side integer DEFAULT NULL

	,INOUT _label_frame_adjustment integer DEFAULT NULL

	,INOUT _label_frame_margin_top double precision DEFAULT NULL
	,INOUT _label_frame_margin_bottom double precision DEFAULT NULL

)
	RETURNS RECORD
	IMMUTABLE
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_label_frame_margin_placeholder double precision;

BEGIN

	_label_flip := COALESCE(_label_flip, 0);
	_label_flip_side := ABS(_label_flip - COALESCE(_label_flip_side, 0));

	_label_frame_adjustment := COALESCE(_label_frame_adjustment, 4);

	_label_frame_margin_top := COALESCE(_label_frame_margin_top, 0);
	_label_frame_margin_bottom := COALESCE(_label_frame_margin_bottom, 0);


	-- Modsat reference og margin ved flip
	IF _label_flip_side = 1 THEN

		SELECT
			adjustment.kode_modsat
		FROM (
			VALUES
				 (0, 'Venstre, over'	,6)
				,(1, 'Center, over'		,7)
				,(2, 'Højre, over'		,8)
				,(3, 'Venstre'			,3)
				,(4, 'Center'			,4)
				,(5, 'Højre'			,5)
				,(6, 'Venstre, under'	,0)
				,(7, 'Center, under'	,1)
				,(8, 'Højre, under'		,2)
		) adjustment(kode, beskrivelse, kode_modsat)
		WHERE adjustment.kode = _label_frame_adjustment
		INTO _label_frame_adjustment;

		_label_frame_margin_placeholder := _label_frame_margin_top;
		_label_frame_margin_top := _label_frame_margin_bottom;
		_label_frame_margin_bottom := _label_frame_margin_placeholder;

	END IF;


	RETURN;

END $BODY$;

COMMENT ON FUNCTION aflob_plan.label_flip_l(
	_label_flip integer
	,_label_flip_side integer

	,_label_frame_adjustment integer

	,_label_frame_margin_top double precision
	,_label_frame_margin_bottom double precision
) IS 'Beregner flip for linjers labels.';




/* DROP FUNCTION IF EXISTS aflob_plan.label_rotation_l(
	_layout_rotation double precision
	,_linestring_rotation double precision

	,_label_flip integer
) CASCADE;
--*/

CREATE OR REPLACE FUNCTION aflob_plan.label_rotation_l(
	_layout_rotation double precision
	,INOUT _linestring_rotation double precision

	,_label_flip integer

	,OUT _label_offset_x double precision
	,OUT _label_offset_y double precision
)
	RETURNS RECORD
	IMMUTABLE
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_linestring_rotation_correction double precision;

BEGIN


	_label_flip := COALESCE(_label_flip, 0);


	-- Ingen offset på label, der følger linjen
	_label_offset_x := 0;
	_label_offset_y := 0;

	-- Korrigér rotation
	_linestring_rotation_correction := _linestring_rotation - _layout_rotation - floor((_linestring_rotation - _layout_rotation) / 360) * 360;

	_linestring_rotation := CASE
							WHEN _linestring_rotation_correction BETWEEN 0 AND 5
							THEN _linestring_rotation + 180
							WHEN _linestring_rotation_correction BETWEEN 5 AND 95
							THEN _linestring_rotation
							WHEN _linestring_rotation_correction BETWEEN 95 AND 185
							THEN _linestring_rotation
							WHEN _linestring_rotation_correction BETWEEN 185 AND 275
							THEN _linestring_rotation - 180
							WHEN _linestring_rotation_correction BETWEEN 275 AND 360
							THEN _linestring_rotation - 180
						END
						-- Ift. 0 grader lig vandret
						- 90
						-- Label flip
						+ CASE
							WHEN _label_flip = 1
							THEN 180
							ELSE 0
						END;


	RETURN;

END $BODY$;

COMMENT ON FUNCTION aflob_plan.label_rotation_l(
	_layout_rotation double precision
	,_linestring_rotation double precision

	,_label_flip integer
) IS 'Beregner rotation for labels placeret på linjer.';





