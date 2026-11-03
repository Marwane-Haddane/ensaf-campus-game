shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// Applied only to the separate perimeter geometry, never to the source screen.
uniform vec4 focus_color : source_color = vec4(0.22, 0.91, 0.88, 0.94);

void fragment() {
	ALBEDO = focus_color.rgb;
	ALPHA = focus_color.a;
}
