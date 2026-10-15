
/*

		SELECT
			string_agg(
				FORMAT(
					'%L'
					,c.relname
				)
				,E'\n' || REPEAT(E'\t', 12) || ','
				ORDER BY c.relname
			)
		FROM pg_class c
		INNER JOIN pg_namespace n ON c.relnamespace = n.oid

		WHERE c.relkind = 'r'

			AND n.nspname = 'aflob_plan'
			AND c.relname ~* '^lst_|^f_tegningshoved'

-- */


/*

WITH

	cte1 AS(
		SELECT
			DENSE_RANK() OVER(ORDER BY array_position(
											ARRAY[
												'lst_ja_nej'

												,'lst_reference_punkt'
												,'lst_adjustment'
												,'lst_plan_aktiver'
												,'lst_plan_type'
												,'lst_font'
												,'lst_flow_type'
												,'lst_indhold_gruppe'
												,'lst_indhold_p_type'
												,'lst_indhold_l_type'
												,'lst_indhold_a_type'

												,'lst_tegningshoved'
												,'lst_tegningshoved_p_type'
												,'lst_tegningshoved_l_type'
												,'lst_tegningshoved_a_type'

												,'lst_import'
												,'lst_import_type'

												,'lst_settings'

												,'f_tegningshoved_a'
												,'f_tegningshoved_l'
												,'f_tegningshoved_label_p'
												,'f_tegningshoved_p'
											]
											,c.relname
										)
										,n.nspname
										,c.relname
							) AS _row
			,n.nspname
			,c.relname
			,a.attnum
			,a.attname
			,format_type(a.atttypid, a.atttypmod) AS atttype

			,co.att_order_col
		FROM pg_class c
		INNER JOIN pg_namespace n ON c.relnamespace = n.oid
		INNER JOIN pg_attribute a ON a.attrelid = c.oid
		LEFT JOIN LATERAL(
				SELECT
					string_agg(
						QUOTE_IDENT(a_sub.attname)
						,','
					) AS att_order_col
				FROM pg_attribute a_sub
				INNER JOIN pg_constraint co ON co.conrelid = c.oid
					AND co.contype = 'p'
					AND a_sub.attnum = ANY(co.conkey)
				WHERE a_sub.attrelid = c.oid
			) co ON TRUE
		WHERE a.attnum > 0
			AND NOT(a.attisdropped)
			AND c.relkind = 'r'
			AND pg_get_serial_sequence(
					FORMAT('%I.%I', n.nspname, c.relname)
					,a.attname
				) IS NULL

			AND n.nspname = 'aflob_plan'
			AND c.relname ~* '^lst_|^f_tegningshoved'
	)

	,cte2 AS(
		SELECT
			c._row
			,c.nspname
			,c.relname
			,FORMAT(
$$		SELECT
			%s AS fid

			,%L AS table_schema
			,%L AS table_name
			,ROW_NUMBER() OVER(ORDER BY %s)::int AS table_row

			,ARRAY[
				%s
			] AS att_array
		FROM %2$I.%3$I$$

				,c._row
				,c.nspname
				,c.relname
				,c.att_order_col
				,string_agg(
					FORMAT(
						'ARRAY[%L, %1$I::text, %s, %L]'
						,c.attname
						,CASE
							WHEN c.atttype IN(
									'integer'
									,'boolean'
									,'text'
								)
							THEN 'NULL'
							ELSE QUOTE_LITERAL(c.atttype)
						END
						,CASE
							WHEN c.atttype IN(
									'integer'
									,'boolean'
								)
							THEN 's'
							ELSE 'L'
						END
					)
					,E'\n\t\t\t\t,'
					ORDER BY c.attnum
				)
			) fmt_
		FROM cte1 c
		GROUP BY c._row
			,c.nspname
			,c.relname
			,c.att_order_col
	)

SELECT
	string_agg(
		fmt_
		,E'\n\n\t\tUNION ALL\n\n'
		-- ORDER BY c.nspname, c.relname
		ORDER BY c._row
	)
	,COUNT(*)
FROM cte2 c


-- */





WITH

	__data__ AS(
		SELECT
			1 AS fid

			,'aflob_plan' AS table_schema
			,'lst_ja_nej' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['kode', kode::text, NULL, 's']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_ja_nej

		UNION ALL

		SELECT
			2 AS fid

			,'aflob_plan' AS table_schema
			,'lst_reference_punkt' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['kode', kode::text, NULL, 's']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_reference_punkt

		UNION ALL

		SELECT
			3 AS fid

			,'aflob_plan' AS table_schema
			,'lst_adjustment' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['kode', kode::text, NULL, 's']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['label', label::text, NULL, 's']
				,ARRAY['frame', frame::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_adjustment

		UNION ALL

		SELECT
			4 AS fid

			,'aflob_plan' AS table_schema
			,'lst_plan_aktiver' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['kode', kode::text, NULL, 's']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_plan_aktiver

		UNION ALL

		SELECT
			5 AS fid

			,'aflob_plan' AS table_schema
			,'lst_plan_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_plan_type

		UNION ALL

		SELECT
			6 AS fid

			,'aflob_plan' AS table_schema
			,'lst_font' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['font', font::text, 'character varying', 'L']
				,ARRAY['font_style', font_style::text, 'character varying', 'L']
				,ARRAY['font_size_factor_x', font_size_factor_x::text, 'double precision', 'L']
				,ARRAY['font_size_factor_y', font_size_factor_y::text, 'double precision', 'L']
			] AS att_array
		FROM aflob_plan.lst_font

		UNION ALL

		SELECT
			7 AS fid

			,'aflob_plan' AS table_schema
			,'lst_flow_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['kode', kode::text, NULL, 's']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['geom', geom::text, 'geometry(Geometry,25832)', 'L']
			] AS att_array
		FROM aflob_plan.lst_flow_type

		UNION ALL

		SELECT
			8 AS fid

			,'aflob_plan' AS table_schema
			,'lst_indhold_gruppe' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_indhold_gruppe

		UNION ALL

		SELECT
			9 AS fid

			,'aflob_plan' AS table_schema
			,'lst_indhold_p_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['gruppe', gruppe::text, 'character varying', 'L']
				,ARRAY['symbol_fill', symbol_fill::text, NULL, 's']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline', symbol_outline::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
				,ARRAY['geom', geom::text, 'geometry(Geometry,25832)', 'L']
			] AS att_array
		FROM aflob_plan.lst_indhold_p_type

		UNION ALL

		SELECT
			10 AS fid

			,'aflob_plan' AS table_schema
			,'lst_indhold_l_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['gruppe', gruppe::text, 'character varying', 'L']
				,ARRAY['symbol_fill', symbol_fill::text, NULL, 's']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline', symbol_outline::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
			] AS att_array
		FROM aflob_plan.lst_indhold_l_type

		UNION ALL

		SELECT
			11 AS fid

			,'aflob_plan' AS table_schema
			,'lst_indhold_a_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['gruppe', gruppe::text, 'character varying', 'L']
				,ARRAY['symbol_fill', symbol_fill::text, NULL, 's']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline', symbol_outline::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
			] AS att_array
		FROM aflob_plan.lst_indhold_a_type

		UNION ALL

		SELECT
			12 AS fid

			,'aflob_plan' AS table_schema
			,'lst_tegningshoved' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
			] AS att_array
		FROM aflob_plan.lst_tegningshoved

		UNION ALL

		SELECT
			13 AS fid

			,'aflob_plan' AS table_schema
			,'lst_tegningshoved_p_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['symbol_fill', symbol_fill::text, NULL, 's']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline', symbol_outline::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
				,ARRAY['geom', geom::text, 'geometry(Geometry,25832)', 'L']
			] AS att_array
		FROM aflob_plan.lst_tegningshoved_p_type

		UNION ALL

		SELECT
			14 AS fid

			,'aflob_plan' AS table_schema
			,'lst_tegningshoved_l_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['symbol_fill', symbol_fill::text, NULL, 's']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline', symbol_outline::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
			] AS att_array
		FROM aflob_plan.lst_tegningshoved_l_type

		UNION ALL

		SELECT
			15 AS fid

			,'aflob_plan' AS table_schema
			,'lst_tegningshoved_a_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY kode)::int AS table_row

			,ARRAY[
				ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['symbol_fill', symbol_fill::text, NULL, 's']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline', symbol_outline::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
			] AS att_array
		FROM aflob_plan.lst_tegningshoved_a_type

		UNION ALL

		SELECT
			16 AS fid

			,'aflob_plan' AS table_schema
			,'lst_import' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['gruppe', gruppe::text, 'character varying', 'L']
				,ARRAY['import_baggrundskort_guid', import_baggrundskort_guid::text, 'uuid', 'L']
				,ARRAY['import_type_guids', import_type_guids::text, 'uuid[]', 'L']
			] AS att_array
		FROM aflob_plan.lst_import

		UNION ALL

		SELECT
			17 AS fid

			,'aflob_plan' AS table_schema
			,'lst_import_type' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['beskrivelse', beskrivelse::text, 'character varying', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['dest_schema', dest_schema::text, NULL, 'L']
				,ARRAY['dest_table', dest_table::text, NULL, 'L']
				,ARRAY['source_insert_columns', source_insert_columns::text, NULL, 'L']
				,ARRAY['source_select', source_select::text, NULL, 'L']
			] AS att_array
		FROM aflob_plan.lst_import_type

		UNION ALL

		SELECT
			18 AS fid

			,'aflob_plan' AS table_schema
			,'lst_settings' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['initialer', initialer::text, 'character varying(50)', 'L']
				,ARRAY['plan_guids', plan_guids::text, 'uuid[]', 'L']
				,ARRAY['import_guid', import_guid::text, 'uuid', 'L']
				,ARRAY['export_dxf_path', export_dxf_path::text, NULL, 'L']
				,ARRAY['tegningshoved_guid', tegningshoved_guid::text, 'uuid', 'L']
				,ARRAY['tegningshoved_egen_side', tegningshoved_egen_side::text, NULL, 's']
				,ARRAY['layout_page_width', layout_page_width::text, 'double precision', 'L']
				,ARRAY['layout_page_height', layout_page_height::text, 'double precision', 'L']
				,ARRAY['layout_page_margin_left_right', layout_page_margin_left_right::text, 'double precision', 'L']
				,ARRAY['layout_page_margin_top_bottom', layout_page_margin_top_bottom::text, 'double precision', 'L']
				,ARRAY['layout_page_flip_top_bottom', layout_page_flip_top_bottom::text, NULL, 's']
				,ARRAY['layout_max_pages_left_right', layout_max_pages_left_right::text, NULL, 's']
				,ARRAY['layout_max_pages_top_bottom', layout_max_pages_top_bottom::text, NULL, 's']
				,ARRAY['layout_map_scale_denom', layout_map_scale_denom::text, NULL, 's']
				,ARRAY['layout_map_margin_left_right', layout_map_margin_left_right::text, NULL, 's']
				,ARRAY['layout_map_margin_top_bottom', layout_map_margin_top_bottom::text, NULL, 's']
				,ARRAY['symbol_scale', symbol_scale::text, 'double precision', 'L']
				,ARRAY['symbol_rotation', symbol_rotation::text, 'double precision', 'L']
				,ARRAY['symbol_fill_color', symbol_fill_color::text, NULL, 'L']
				,ARRAY['symbol_fill_color_opacity', symbol_fill_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_color', symbol_outline_color::text, NULL, 'L']
				,ARRAY['symbol_outline_color_opacity', symbol_outline_color_opacity::text, NULL, 's']
				,ARRAY['symbol_outline_width_mm', symbol_outline_width_mm::text, 'double precision', 'L']
				,ARRAY['symbol_outline_dash_mm', symbol_outline_dash_mm::text, NULL, 'L']
				,ARRAY['label_color', label_color::text, 'character varying', 'L']
				,ARRAY['label_font', label_font::text, 'character varying', 'L']
				,ARRAY['label_rotation', label_rotation::text, 'double precision', 'L']
				,ARRAY['label_size', label_size::text, 'double precision', 'L']
				,ARRAY['label_spacing', label_spacing::text, 'double precision', 'L']
				,ARRAY['label_adjustment', label_adjustment::text, NULL, 's']
				,ARRAY['label_offset_x', label_offset_x::text, 'double precision', 'L']
				,ARRAY['label_offset_y', label_offset_y::text, 'double precision', 'L']
				,ARRAY['label_frame', label_frame::text, NULL, 's']
				,ARRAY['label_frame_width_mm', label_frame_width_mm::text, 'double precision', 'L']
				,ARRAY['label_frame_adjustment', label_frame_adjustment::text, NULL, 's']
				,ARRAY['label_frame_margin_left', label_frame_margin_left::text, 'double precision', 'L']
				,ARRAY['label_frame_margin_right', label_frame_margin_right::text, 'double precision', 'L']
				,ARRAY['label_frame_margin_top', label_frame_margin_top::text, 'double precision', 'L']
				,ARRAY['label_frame_margin_bottom', label_frame_margin_bottom::text, 'double precision', 'L']
				,ARRAY['label_callout', label_callout::text, NULL, 's']
				,ARRAY['font_size_factor_x', font_size_factor_x::text, 'double precision', 'L']
				,ARRAY['font_size_factor_y', font_size_factor_y::text, 'double precision', 'L']
			] AS att_array
		FROM aflob_plan.lst_settings
		WHERE initialer = '__system__'

		UNION ALL

		SELECT
			19 AS fid

			,'aflob_plan' AS table_schema
			,'f_tegningshoved_a' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['tegningshoved_guid', tegningshoved_guid::text, 'uuid', 'L']
				,ARRAY['type', type::text, 'character varying', 'L']
				,ARRAY['scale_reference', scale_reference::text, 'uuid', 'L']
				,ARRAY['rotation_reference', rotation_reference::text, 'uuid', 'L']
				,ARRAY['frame', frame::text, NULL, 's']
				,ARRAY['geom', geom::text, 'geometry(Polygon,25832)', 'L']
			] AS att_array
		FROM aflob_plan.f_tegningshoved_a

		UNION ALL

		SELECT
			20 AS fid

			,'aflob_plan' AS table_schema
			,'f_tegningshoved_l' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['tegningshoved_guid', tegningshoved_guid::text, 'uuid', 'L']
				,ARRAY['type', type::text, 'character varying', 'L']
				,ARRAY['scale_reference', scale_reference::text, 'uuid', 'L']
				,ARRAY['rotation_reference', rotation_reference::text, 'uuid', 'L']
				,ARRAY['layout', layout::text, NULL, 's']
				,ARRAY['geom', geom::text, 'geometry(LineString,25832)', 'L']
			] AS att_array
		FROM aflob_plan.f_tegningshoved_l

		UNION ALL

		SELECT
			21 AS fid

			,'aflob_plan' AS table_schema
			,'f_tegningshoved_label_p' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['tegningshoved_guid', tegningshoved_guid::text, 'uuid', 'L']
				,ARRAY['label', label::text, 'character varying', 'L']
				,ARRAY['scale_reference', scale_reference::text, 'uuid', 'L']
				,ARRAY['rotation_reference', rotation_reference::text, 'uuid', 'L']
				,ARRAY['label_color', label_color::text, 'character varying', 'L']
				,ARRAY['label_font', label_font::text, 'character varying', 'L']
				,ARRAY['label_rotation', label_rotation::text, 'double precision', 'L']
				,ARRAY['label_size', label_size::text, 'double precision', 'L']
				,ARRAY['label_adjustment', label_adjustment::text, NULL, 's']
				,ARRAY['label_offset_x', label_offset_x::text, 'double precision', 'L']
				,ARRAY['label_offset_y', label_offset_y::text, 'double precision', 'L']
				,ARRAY['geom', geom::text, 'geometry(Point,25832)', 'L']
			] AS att_array
		FROM aflob_plan.f_tegningshoved_label_p

		UNION ALL

		SELECT
			22 AS fid

			,'aflob_plan' AS table_schema
			,'f_tegningshoved_p' AS table_name
			,ROW_NUMBER() OVER(ORDER BY guid)::int AS table_row

			,ARRAY[
				ARRAY['guid', guid::text, 'uuid', 'L']
				,ARRAY['aktiv', aktiv::text, NULL, 's']
				,ARRAY['tegningshoved_guid', tegningshoved_guid::text, 'uuid', 'L']
				,ARRAY['type', type::text, 'character varying', 'L']
				,ARRAY['scale_reference', scale_reference::text, 'uuid', 'L']
				,ARRAY['rotation_reference', rotation_reference::text, 'uuid', 'L']
				,ARRAY['reference_punkt', reference_punkt::text, NULL, 's']
				,ARRAY['reference', reference::text, NULL, 'L']
				,ARRAY['reference_value', reference_value::text, 'double precision', 'L']
				,ARRAY['geom', geom::text, 'geometry(Point,25832)', 'L']
			] AS att_array
		FROM aflob_plan.f_tegningshoved_p
)



	,tabs AS(
		SELECT
			4 AS tab_width
	)

	,cte1 AS(
		SELECT DISTINCT
			d.fid

			,d.table_schema
			,d.table_name
			,0 AS table_row

			,'header' AS header_value
			,g AS header_value_order
			,header_value_count

			,QUOTE_IDENT(d.att_array[g][1]) AS att_header_value

		FROM __data__ d
			,array_length(att_array, 1) header_value_count
			,generate_series(1, header_value_count) g

		UNION ALL

		SELECT
			d.fid

			,d.table_schema
			,d.table_name
			,d.table_row

			,'value' AS header_value
			,g AS header_value_order
			,header_value_count

			,CASE
				WHEN d.att_array[g][4] = 'L'
					AND d.att_array[g][2] ~* E'\n|\t'
				THEN 'E'
				ELSE ''
			END
				|| CASE
					WHEN d.att_array[g][4] = 'L'
						AND d.att_array[g][2] ~* E'\n|\t'
					THEN REPLACE(
							REPLACE(
								REPLACE(
									f
									,E'\\'
									,E'\\\\'
								)
								,E'\n'
								,'\n'
							)
							,E'\t'
							,'\t'
						)
					ELSE f
				END AS att_header_value

		FROM __data__ d
			,array_length(att_array, 1) header_value_count
			,generate_series(1, header_value_count) g
			,COALESCE(
				FORMAT(
					'%' || d.att_array[g][4]
					-- ,d.att_array[g][2]
					,CASE
						WHEN d.att_array[g][4] = 's'
						THEN COALESCE(d.att_array[g][2], 'NULL')
						ELSE d.att_array[g][2]
					END
				)
				|| COALESCE('::' || d.att_array[g][3], '')
			) f


		ORDER BY fid
			,header_value
			,table_row
			,header_value_order
	)

	,cte2 AS(
		SELECT
			c.fid

			,c.table_schema
			,c.table_name
			,c.table_row

			,c.header_value
			,c.header_value_order
			,c.header_value_count

			,c.att_header_value

			,LENGTH(c.att_header_value) + 1 + 1 * (c.header_value_order = 1)::int AS lgd

		FROM cte1 c
	)

	,cte3 AS(
		SELECT
			c.fid

			,c.table_schema
			,c.table_name
			,c.table_row

			,c.header_value
			,c.header_value_order
			,c.header_value_count

			,c.att_header_value

			,t.tab_width
			,LENGTH(c.att_header_value) + 1 + 1 * (c.header_value_order = 1)::int AS lgd
			,MAX(c.lgd) OVER(PARTITION BY c.fid, c.header_value_order) + t.tab_width - MAX(c.lgd) OVER(PARTITION BY c.fid, c.header_value_order) % t.tab_width AS lgd_pr_col

		FROM cte2 c
			,tabs t
		ORDER BY c.fid
			,c.header_value
			,c.table_row
			,c.header_value_order
	)

	,cte4 AS(
		SELECT
			c.fid

			,c.table_schema
			,c.table_name
			,c.table_row

			,c.header_value
			,c.header_value_order

			,c.att_header_value
				|| REPEAT(
						E'\t'
						,CEILING(
							(c.lgd_pr_col - c.lgd)::float / c.tab_width
						)::int * (c.header_value_order < c.header_value_count)::int
					) AS att_header_value

		FROM cte3 c
		ORDER BY c.fid
			,c.header_value
			,c.table_row
			,c.header_value_order
	)

	,cte5 AS(
		SELECT
			c.fid

			,c.table_schema
			,c.table_name
			,c.table_row

			,c.header_value

			,FORMAT(
				CASE
					WHEN c.header_value = 'header'
					THEN ' %s'
					ELSE '(%s)'
				END

				,string_agg(
					c.att_header_value
					,','
					ORDER BY c.header_value_order
				)
			) AS att_header_value

		FROM cte4 c
		GROUP BY c.fid

			,c.table_schema
			,c.table_name
			,c.table_row

			,c.header_value
		ORDER BY c.fid
			,c.header_value
			,c.table_row
	)

	,cte6 AS(
		SELECT
			c.fid

			,c.table_schema
			,c.table_name

			,array_agg(
				c.att_header_value
				ORDER BY c.table_row
			) AS att_header_value

		FROM cte5 c
		GROUP BY c.fid

			,c.table_schema
			,c.table_name
		ORDER BY c.fid
	)

SELECT
	string_agg(
		FORMAT(
$$-- TRUNCATE %I.%I;
INSERT INTO %1$I.%I(
	 %s
) VALUES
	 %s
;$$

			-- ,'sandbox'
			,c.table_schema
			,c.table_name

			,att_header_value[1]
			,array_to_string(
				att_header_value[2:]
				,E'\n\t,'
			)
		)
		,E'\n\n\n\n\n'
		ORDER BY c.fid
	)
FROM cte6 c


