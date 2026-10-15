-- DROP FUNCTION IF EXISTS aflob_plan.f_indhold_l_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.f_indhold_l_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

DECLARE

	_plan_frame geometry('MULTIPOLYGON', 25832);
	_plan_rotation double precision;

BEGIN

	IF (TG_OP = 'UPDATE') THEN

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


	NEW.aktiv := COALESCE(NEW.aktiv, 1);


	IF NEW.plan_guid IS NULL THEN

		SELECT
			p.guid
		FROM aflob_plan.v_planer p
		WHERE p.selected_ = 1
		ORDER BY ST_Distance(
					ST_LineInterpolatePoint(p.geom, 0.5)
					,NEW.geom
				)
		LIMIT 1
		INTO NEW.plan_guid;

	END IF;

	NEW.gruppe := COALESCE(NEW.gruppe, 'Plan');


	NEW.label := NULLIF(TRIM(NEW.label), '');
	NEW.label_show := COALESCE(NEW.label_show, 1);


	NEW.label_move_with_point := COALESCE(NEW.label_move_with_point, 1);


	NEW.label_flip = COALESCE(NEW.label_flip, 0);
	NEW.label_flip_side = COALESCE(NEW.label_flip_side, 0);


	NEW.flow_type = COALESCE(NEW.flow_type, 0);




	IF (TG_OP = 'UPDATE') THEN

		IF NEW.label_position_pct IS DISTINCT FROM OLD.label_position_pct THEN

			NEW.label_position_x := NULL;
			NEW.label_position_y := NULL;

			IF NEW.gruppe = 'Plan' THEN

				NEW.label_frame := 0;

			END IF;

		ELSIF (
				NEW.label_position_x IS DISTINCT FROM OLD.label_position_x
				OR NEW.label_position_y IS DISTINCT FROM OLD.label_position_y
			)
			AND NEW.label_position_x IS NOT NULL
			AND NEW.label_position_y IS NOT NULL
		THEN

			NEW.label_position_pct := NULL;

			-- IF NEW.gruppe = 'Plan'
				-- AND (
					-- OLD.label_position_x IS NULL
					-- OR OLD.label_position_y IS NULL
				-- )
			-- THEN

				-- NEW.label_frame := 1;
				-- NEW.label_callout := 1;

			-- END IF;

		END IF;

	END IF;


	IF NEW.label_position_x IS NULL
		OR NEW.label_position_y IS NULL
	THEN

		NEW.label_position_x := NULL;
		NEW.label_position_y := NULL;

		-- NEW.label_position_pct := COALESCE(NEW.label_position_pct, 50);

	END IF;



	IF NEW.plan_guid IS NOT NULL
		AND NEW.label_position_x IS NULL
		AND NEW.label_position_y IS NULL
		AND NEW.label_position_pct IS NULL
	THEN

		-- Frame layout + rotation
		SELECT
			p.layout_frame
			,p.layout_rotation
		FROM aflob_plan.f_planer p
		WHERE p.guid = NEW.plan_guid
		INTO _plan_frame
			,_plan_rotation;


		-- Fjern eksisterende labels
		SELECT
			COALESCE(
				ST_Multi(
					ST_Difference(
						_plan_frame
						,ST_Union(ST_MakePolygon(COALESCE(ST_GeometryN(i.label_geom, 1), i.label_geom)))
					)
				)
				,_plan_frame
			)
		FROM aflob_plan.v_indhold_plan_label_p i
		WHERE i.plan_guid = NEW.plan_guid
			AND i.guid != NEW.guid
		INTO _plan_frame;
		SELECT
			COALESCE(
				ST_Multi(
					ST_Difference(
						_plan_frame
						,ST_Union(ST_MakePolygon(COALESCE(ST_GeometryN(i.label_geom, 1), i.label_geom)))
					)
				)
				,_plan_frame
			)
		FROM aflob_plan.v_indhold_baggrundskort_label_p i
		WHERE i.plan_guid = NEW.plan_guid
			AND i.guid != NEW.guid
		INTO _plan_frame;


		SELECT
			j.pct
		FROM (VALUES
				(50, 1)
				,(60, 2)
				,(40, 3)
				,(70, 4)
				,(30, 5)
				,(80, 6)
				,(20, 7)
				,(90, 8)
				,(10, 9)
			) j(pct, _order)
			-- Flip
			,(VALUES
				(0, 1)
				,(1, 2)
			) f(flip_side, _order)

			,ST_LineInterpolatePoint(NEW.geom, j.pct::numeric / 100) label_position_point
			,aflob_plan.label_flip_l(
				_label_flip := 0
				,_label_flip_side := f.flip_side

				,_label_frame_adjustment := NEW.label_frame_adjustment

				,_label_frame_margin_top := NEW.label_frame_margin_top
				,_label_frame_margin_bottom := NEW.label_frame_margin_bottom
			) label_flip
			,aflob_plan.label_rotation_l(
				_layout_rotation := _plan_rotation
				,_linestring_rotation := DEGREES(
										ST_Azimuth(
											ST_LineInterpolatePoint(NEW.geom, GREATEST(j.pct::numeric / 100 - 0.00001, 0))
											,ST_LineInterpolatePoint(NEW.geom, LEAST(j.pct::numeric / 100 + 0.00001, 1))
										)
									)

				,_label_flip := label_flip._label_flip
			) label_rotation
			,aflob_plan.label(
				_label := COALESCE(NEW.label, E'12345\n12345\n12345')

				,_label_reference_point := label_position_point
				,_label_point := NULL::geometry

				,_plan_guid := NEW.plan_guid

				,_label_font := NEW.label_font
				,_label_rotation := label_rotation._linestring_rotation
				,_label_size := NEW.label_size
				,_label_spacing := NEW.label_spacing

				,_label_adjustment := NEW.label_adjustment
				,_label_offset_x := label_rotation._label_offset_x
				,_label_offset_y := label_rotation._label_offset_y

				,_label_frame := 1
				,_label_frame_adjustment := label_flip._label_frame_adjustment
				,_label_frame_margin_left := NEW.label_frame_margin_left
				,_label_frame_margin_right := NEW.label_frame_margin_right
				,_label_frame_margin_top := COALESCE(label_flip._label_frame_margin_top, NEW.label_frame_margin_top)
				,_label_frame_margin_bottom := COALESCE(label_flip._label_frame_margin_bottom, NEW.label_frame_margin_bottom)

				,_label_callout := 0

				,_font_size_factor_x := NEW.font_size_factor_x
				,_font_size_factor_y := NEW.font_size_factor_y
			) l
		ORDER BY ST_Area(
					ST_Intersection(
						ST_MakePolygon(l._label_geom)
						,_plan_frame
					)
				)::numeric(10,2) DESC
				,j._order
				,f._order
		LIMIT 1
		INTO NEW.label_position_pct;

	END IF;




	IF (TG_OP = 'UPDATE') THEN

		IF NOT(ST_Equals(NEW.geom, OLD.geom))

			AND NEW.label_move_with_point = 1

			AND NEW.label_position_x IS NOT NULL
			AND NEW.label_position_y IS NOT NULL

			AND NEW.label_position_x IS NOT DISTINCT FROM OLD.label_position_x
			AND NEW.label_position_y IS NOT DISTINCT FROM OLD.label_position_y
		THEN

			NEW.label_position_x = OLD.label_position_x + ST_X(ST_Centroid(NEW.geom)) - ST_X(ST_Centroid(OLD.geom));
			NEW.label_position_y = OLD.label_position_y + ST_Y(ST_Centroid(NEW.geom)) - ST_Y(ST_Centroid(OLD.geom));

		END IF;

	END IF;


	RETURN NEW;

END $BODY$;




-- DROP FUNCTION IF EXISTS aflob_plan.v_indhold_l_trg() CASCADE;
CREATE OR REPLACE FUNCTION aflob_plan.v_indhold_l_trg()
	RETURNS trigger
	LANGUAGE plpgsql AS
$BODY$

BEGIN

	IF TG_OP = 'DELETE' THEN

		DELETE FROM aflob_plan.f_indhold_l
			WHERE guid = OLD.guid;

	ELSIF TG_OP = 'UPDATE' THEN

		UPDATE aflob_plan.f_indhold_l
			SET
				geom = NEW.geom
				,aktiv = NEW.aktiv

				,plan_guid = NEW.plan_guid
				,gruppe = NEW.gruppe
				,type = NEW.type
				,beskrivelse = NEW.beskrivelse

				,label = NEW.label
				,label_show = NEW.label_show

				,label_move_with_point = NEW.label_move_with_point
				,label_position_x = NEW.label_position_x
				,label_position_y = NEW.label_position_y
				,label_position_pct = NEW.label_position_pct

				,label_flip = NEW.label_flip
				,label_flip_side = NEW.label_flip_side

				,flow_type = NEW.flow_type
				,flow_distance_start = NEW.flow_distance_start
				,flow_distance_end = NEW.flow_distance_end


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

	ELSIF TG_OP = 'INSERT' THEN

		INSERT INTO aflob_plan.f_indhold_l(
			guid
			,geom
			,aktiv

			,plan_guid
			,gruppe
			,type
			,beskrivelse

			,label
			,label_show

			,label_move_with_point
			,label_position_x
			,label_position_y
			,label_position_pct

			,label_flip
			,label_flip_side

			,flow_type
			,flow_distance_start
			,flow_distance_end


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

			,NEW.plan_guid
			,NEW.gruppe
			,NEW.type
			,NEW.beskrivelse

			,NEW.label
			,NEW.label_show

			,NEW.label_move_with_point
			,NEW.label_position_x
			,NEW.label_position_y
			,NEW.label_position_pct

			,NEW.label_flip
			,NEW.label_flip_side

			,NEW.flow_type
			,NEW.flow_distance_start
			,NEW.flow_distance_end


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

	RETURN NULL;

END $BODY$;




-- DROP TABLE IF EXISTS aflob_plan.f_indhold_l CASCADE;

CREATE TABLE aflob_plan.f_indhold_l(
	guid uuid PRIMARY KEY

	,datooprettet timestamp NOT NULL
	,oprettet_af character varying(50) NOT NULL
	,datoopdateret timestamp NOT NULL
	,initialer character varying(50) NOT NULL

	,geom geometry('LINESTRING', 25832) NOT NULL
	,aktiv integer NOT NULL DEFAULT 1

	,plan_guid uuid NOT NULL
	,gruppe character varying NOT NULL
	,type character varying NOT NULL
	,beskrivelse character varying

	,label character varying
	,label_show integer

	,label_move_with_point integer
	,label_position_x double precision
	,label_position_y double precision
	,label_position_pct double precision

	,label_flip integer
	,label_flip_side integer

	,flow_type integer
	,flow_distance_start double precision
	,flow_distance_end double precision


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


-- DROP INDEX IF EXISTS aflob_plan.f_indhold_l_geom_gist;
CREATE INDEX plan_f_indhold_l_geom_gist ON aflob_plan.f_indhold_l USING gist(geom);

-- DROP INDEX IF EXISTS aflob_plan.f_indhold_l_plan_guid;
CREATE INDEX plan_f_indhold_l_plan_guid ON aflob_plan.f_indhold_l(plan_guid);
-- DROP INDEX IF EXISTS aflob_plan.f_indhold_l_plan_guid_text;
CREATE INDEX plan_f_indhold_l_plan_guid_text ON aflob_plan.f_indhold_l((plan_guid::text));

-- DROP INDEX IF EXISTS aflob_plan.f_indhold_l_type;
CREATE INDEX plan_f_indhold_l_type ON aflob_plan.f_indhold_l(type);


CREATE TRIGGER plan_f_indhold_l_trg_iu
	BEFORE INSERT OR UPDATE
		ON aflob_plan.f_indhold_l
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.f_indhold_l_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_indhold_plan_l CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_indhold_plan_l AS

SELECT
	i.*




	-- Symbol
	,COALESCE(i.symbol_scale, p.symbol_scale_calc) AS symbol_scale_calc
	,COALESCE(i.symbol_rotation, p.symbol_rotation_calc) AS symbol_rotation_calc

	,COALESCE(i.symbol_fill_color, t.symbol_fill_color, p.symbol_fill_color_calc) AS symbol_fill_color_calc
	,COALESCE(i.symbol_fill_color_opacity, t.symbol_fill_color_opacity, p.symbol_fill_color_opacity_calc) AS symbol_fill_color_opacity_calc

	,COALESCE(i.symbol_outline_color, t.symbol_outline_color, p.symbol_outline_color_calc) AS symbol_outline_color_calc
	,COALESCE(i.symbol_outline_color_opacity, t.symbol_outline_color_opacity, p.symbol_outline_color_opacity_calc) AS symbol_outline_color_opacity_calc
	,COALESCE(i.symbol_outline_width_mm, t.symbol_outline_width_mm, p.symbol_outline_width_mm_calc) AS symbol_outline_width_mm_calc
	,COALESCE(i.symbol_outline_width_mm, t.symbol_outline_width_mm, p.symbol_outline_width_mm_calc)
															* p.layout_map_scale_denom_calc / 1000 AS symbol_outline_width_calc

	,COALESCE(i.symbol_outline_dash_mm, t.symbol_outline_dash_mm, p.symbol_outline_dash_mm_calc) AS symbol_outline_dash_mm_calc
	,style._outline_dash AS symbol_outline_dash_calc

	-- Label
	,COALESCE(i.label_color, p.label_color_calc) AS label_color_calc
	,COALESCE(i.label_font, p.label_font_calc) AS label_font_calc
	,COALESCE(i.label_rotation, p.label_rotation_calc) AS label_rotation_calc
	,COALESCE(i.label_size, p.label_size_calc) AS label_size_calc
	,COALESCE(i.label_spacing, p.label_spacing_calc) AS label_spacing_calc

	,COALESCE(i.label_adjustment, p.label_adjustment_calc) AS label_adjustment_calc
	,COALESCE(i.label_offset_x, p.label_offset_x_calc) AS label_offset_x_calc
	,COALESCE(i.label_offset_y, p.label_offset_y_calc) AS label_offset_y_calc

	,COALESCE(i.label_frame, p.label_frame_calc) AS label_frame_calc
	,COALESCE(i.label_frame_width_mm, p.label_frame_width_mm_calc) AS label_frame_width_mm_calc
	,COALESCE(i.label_frame_width_mm, p.label_frame_width_mm_calc)
															* p.layout_map_scale_denom_calc / 1000 AS label_frame_width_calc
	,COALESCE(i.label_frame_adjustment, p.label_frame_adjustment_calc) AS label_frame_adjustment_calc
	,COALESCE(i.label_frame_margin_left, p.label_frame_margin_left_calc) AS label_frame_margin_left_calc
	,COALESCE(i.label_frame_margin_right, p.label_frame_margin_right_calc) AS label_frame_margin_right_calc
	,COALESCE(i.label_frame_margin_top, p.label_frame_margin_top_calc) AS label_frame_margin_top_calc
	,COALESCE(i.label_frame_margin_bottom, p.label_frame_margin_bottom_calc) AS label_frame_margin_bottom_calc

	,COALESCE(i.label_callout, p.label_callout_calc) AS label_callout_calc

	-- Font
	,COALESCE(i.font_size_factor_x, p.font_size_factor_x_calc) AS font_size_factor_x_calc
	,COALESCE(i.font_size_factor_y, p.font_size_factor_y_calc) AS font_size_factor_y_calc


	,p.layout_rotation

	,i.geom AS style_geom
	-- ,ST_Multi(
		-- COALESCE(
			-- ST_Union(
				-- flow_style_start._geom_fill
				-- ,flow_style_end._geom_fill
			-- )
			-- ,flow_style_start._geom_fill
			-- ,flow_style_end._geom_fill
		-- )
	-- ) AS style_geom_fill
	-- ,style._geom_outline AS style_geom_outline
	,ST_Intersection(
		ST_Multi(
			COALESCE(
				ST_Union(
					flow_style_start._geom_fill
					,flow_style_end._geom_fill
				)
				,flow_style_start._geom_fill
				,flow_style_end._geom_fill
			)
		)
		,p.layout_frame
	) AS style_geom_fill
	,ST_Intersection(style._geom_outline, p.layout_frame) AS style_geom_outline

FROM aflob_plan.f_indhold_l i
INNER JOIN aflob_plan.v_planer p ON p.guid = i.plan_guid
	AND p.selected_ = 1
LEFT JOIN aflob_plan.lst_indhold_l_type t ON t.beskrivelse = i.type
	AND t.aktiv = 1
LEFT JOIN aflob_plan.lst_flow_type f ON f.kode = i.flow_type
	AND f.aktiv = 1


LEFT JOIN aflob_plan.style(
	_geom := i.geom

	,_style_rotation := NULL
	,_style_reference_point := NULL::geometry

	,_scale_map_scale_denom := NULL
	,_scale_reference_point := NULL::geometry

	,_fill := 0

	,_outline := t.symbol_outline
	,_outline_opacity := COALESCE(i.symbol_outline_color_opacity, t.symbol_outline_color_opacity, p.symbol_outline_color_opacity_calc)
	,_outline_dash_mm := COALESCE(i.symbol_outline_dash_mm, t.symbol_outline_dash_mm, p.symbol_outline_dash_mm_calc)
	,_outline_map_scale_denom := p.layout_map_scale_denom_calc
) style ON i.aktiv = 1


LEFT JOIN LATERAL(
	SELECT
		_start
		,_end

		,CASE
			WHEN _start IS FALSE
			THEN NULL
			WHEN geom_length < 10
				AND i.flow_distance_start IS NULL
				AND i.flow_distance_end IS NULL
			THEN 0.5
			ELSE COALESCE(i.flow_distance_start, 2.5 + flow_width)					 / geom_length
		END AS _position_start
		,CASE
			WHEN _end IS FALSE
			THEN NULL
			ELSE (geom_length - COALESCE(i.flow_distance_end, 2.5 + flow_width))	 / geom_length
		END AS _position_end

	FROM ST_Length(i.geom) geom_length
		,COALESCE((ST_XMax(f.geom) - ST_XMin(f.geom)) / 2) flow_width

		,COALESCE(COALESCE(i.flow_distance_start, 1) > 0) _start
		,COALESCE(CASE
						WHEN geom_length < 10
							AND i.flow_distance_start IS NULL
							AND i.flow_distance_end IS NULL
						THEN FALSE
						ELSE COALESCE(i.flow_distance_end, 1) > 0
					END) _end
) flow ON i.flow_type != 0


LEFT JOIN aflob_plan.style(
	_geom := f.geom

	,_style_rotation := DEGREES(
							ST_Azimuth(
								ST_LineInterpolatePoint(i.geom, GREATEST(flow._position_start - 0.00001, 0))
								,ST_LineInterpolatePoint(i.geom, LEAST(flow._position_start + 0.00001, 1))
							)
						) - 90
	,_style_reference_point := ST_LineInterpolatePoint(i.geom, flow._position_start)

	,_scale_map_scale_denom := p.layout_map_scale_denom_calc * COALESCE(i.symbol_scale, p.symbol_scale_calc)
	,_scale_reference_point := NULL::geometry

	,_fill := 1
	,_fill_opacity := COALESCE(i.symbol_fill_color_opacity, t.symbol_fill_color_opacity, p.symbol_fill_color_opacity_calc)

	,_outline := 0
) flow_style_start ON flow._start IS TRUE
LEFT JOIN aflob_plan.style(
	_geom := f.geom

	,_style_rotation := DEGREES(
							ST_Azimuth(
								ST_LineInterpolatePoint(i.geom, GREATEST(flow._position_end - 0.00001, 0))
								,ST_LineInterpolatePoint(i.geom, LEAST(flow._position_end + 0.00001, 1))
							)
						)  - 90
	,_style_reference_point := ST_LineInterpolatePoint(i.geom, flow._position_end)

	,_scale_map_scale_denom := p.layout_map_scale_denom_calc * COALESCE(i.symbol_scale, p.symbol_scale_calc)
	,_scale_reference_point := NULL::geometry

	,_fill := 1
	,_fill_opacity := COALESCE(i.symbol_fill_color_opacity, t.symbol_fill_color_opacity, p.symbol_fill_color_opacity_calc)

	,_outline := 0
) flow_style_end ON flow._end IS TRUE
WHERE i.gruppe = 'Plan';


CREATE TRIGGER plan_v_indhold_plan_l_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_indhold_plan_l
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_indhold_l_trg();




-- DROP VIEW IF EXISTS aflob_plan.v_indhold_baggrundskort_l CASCADE;
CREATE OR REPLACE VIEW aflob_plan.v_indhold_baggrundskort_l AS

SELECT
	i.*




	-- Symbol
	,COALESCE(i.symbol_scale, p.symbol_scale_calc) AS symbol_scale_calc
	,COALESCE(i.symbol_rotation, p.symbol_rotation_calc) AS symbol_rotation_calc

	,COALESCE(i.symbol_fill_color, t.symbol_fill_color, p.symbol_fill_color_calc) AS symbol_fill_color_calc
	,COALESCE(i.symbol_fill_color_opacity, t.symbol_fill_color_opacity, p.symbol_fill_color_opacity_calc) AS symbol_fill_color_opacity_calc

	,COALESCE(i.symbol_outline_color, t.symbol_outline_color, p.symbol_outline_color_calc) AS symbol_outline_color_calc
	,COALESCE(i.symbol_outline_color_opacity, t.symbol_outline_color_opacity, p.symbol_outline_color_opacity_calc) AS symbol_outline_color_opacity_calc
	,COALESCE(i.symbol_outline_width_mm, t.symbol_outline_width_mm, p.symbol_outline_width_mm_calc) AS symbol_outline_width_mm_calc
	,COALESCE(i.symbol_outline_width_mm, t.symbol_outline_width_mm, p.symbol_outline_width_mm_calc)
															* p.layout_map_scale_denom_calc / 1000 AS symbol_outline_width_calc

	,COALESCE(i.symbol_outline_dash_mm, t.symbol_outline_dash_mm, p.symbol_outline_dash_mm_calc) AS symbol_outline_dash_mm_calc
	,style._outline_dash AS symbol_outline_dash_calc

	-- Label
	,COALESCE(i.label_color, p.label_color_calc) AS label_color_calc
	,COALESCE(i.label_font, p.label_font_calc) AS label_font_calc
	,COALESCE(i.label_rotation, p.label_rotation_calc) AS label_rotation_calc
	,COALESCE(i.label_size, p.label_size_calc) AS label_size_calc
	,COALESCE(i.label_spacing, p.label_spacing_calc) AS label_spacing_calc

	,COALESCE(i.label_adjustment, p.label_adjustment_calc) AS label_adjustment_calc
	,COALESCE(i.label_offset_x, p.label_offset_x_calc) AS label_offset_x_calc
	,COALESCE(i.label_offset_y, p.label_offset_y_calc) AS label_offset_y_calc

	,COALESCE(i.label_frame, p.label_frame_calc) AS label_frame_calc
	,COALESCE(i.label_frame_width_mm, p.label_frame_width_mm_calc) AS label_frame_width_mm_calc
	,COALESCE(i.label_frame_width_mm, p.label_frame_width_mm_calc)
															* p.layout_map_scale_denom_calc / 1000 AS label_frame_width_calc
	,COALESCE(i.label_frame_adjustment, p.label_frame_adjustment_calc) AS label_frame_adjustment_calc
	,COALESCE(i.label_frame_margin_left, p.label_frame_margin_left_calc) AS label_frame_margin_left_calc
	,COALESCE(i.label_frame_margin_right, p.label_frame_margin_right_calc) AS label_frame_margin_right_calc
	,COALESCE(i.label_frame_margin_top, p.label_frame_margin_top_calc) AS label_frame_margin_top_calc
	,COALESCE(i.label_frame_margin_bottom, p.label_frame_margin_bottom_calc) AS label_frame_margin_bottom_calc

	,COALESCE(i.label_callout, p.label_callout_calc) AS label_callout_calc

	-- Font
	,COALESCE(i.font_size_factor_x, p.font_size_factor_x_calc) AS font_size_factor_x_calc
	,COALESCE(i.font_size_factor_y, p.font_size_factor_y_calc) AS font_size_factor_y_calc


	,p.layout_rotation

	,i.geom AS style_geom
	,NULL::geometry('MULTIPOLYGON', 25832) AS style_geom_fill
	,ST_Intersection(style._geom_outline, p.layout_frame) AS style_geom_outline

FROM aflob_plan.f_indhold_l i
INNER JOIN aflob_plan.v_planer p ON p.guid = i.plan_guid
	AND p.selected_ = 1
LEFT JOIN aflob_plan.lst_indhold_l_type t ON t.beskrivelse = i.type
	AND t.aktiv = 1


LEFT JOIN aflob_plan.style(
	_geom := i.geom

	,_style_rotation := NULL
	,_style_reference_point := NULL::geometry

	,_scale_map_scale_denom := NULL
	,_scale_reference_point := NULL::geometry

	,_fill := 0

	,_outline := t.symbol_outline
	,_outline_opacity := COALESCE(i.symbol_outline_color_opacity, t.symbol_outline_color_opacity, p.symbol_outline_color_opacity_calc)
	,_outline_dash_mm := COALESCE(i.symbol_outline_dash_mm, t.symbol_outline_dash_mm, p.symbol_outline_dash_mm_calc)
	,_outline_map_scale_denom := p.layout_map_scale_denom_calc
) style ON i.aktiv = 1
WHERE i.gruppe = 'Baggrundskort';


CREATE TRIGGER plan_v_indhold_baggrundskort_l_trg_iud
	INSTEAD OF INSERT OR DELETE OR UPDATE
		ON aflob_plan.v_indhold_baggrundskort_l
	FOR EACH ROW
	EXECUTE PROCEDURE aflob_plan.v_indhold_l_trg();








