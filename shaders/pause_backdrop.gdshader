shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius : hint_range(0.0, 4.0) = 2.0;

void fragment() {
	vec2 d = SCREEN_PIXEL_SIZE * blur_radius;
	vec2 uv = SCREEN_UV;
	// A bounded nine-tap blur. This canvas pass is hidden during exploration.
	vec3 scene = textureLod(screen_texture, uv, 0.0).rgb * 0.20;
	scene += textureLod(screen_texture, uv + vec2(d.x, 0.0), 0.0).rgb * 0.12;
	scene += textureLod(screen_texture, uv - vec2(d.x, 0.0), 0.0).rgb * 0.12;
	scene += textureLod(screen_texture, uv + vec2(0.0, d.y), 0.0).rgb * 0.12;
	scene += textureLod(screen_texture, uv - vec2(0.0, d.y), 0.0).rgb * 0.12;
	scene += textureLod(screen_texture, uv + d, 0.0).rgb * 0.08;
	scene += textureLod(screen_texture, uv - d, 0.0).rgb * 0.08;
	scene += textureLod(screen_texture, uv + vec2(d.x, -d.y), 0.0).rgb * 0.08;
	scene += textureLod(screen_texture, uv + vec2(-d.x, d.y), 0.0).rgb * 0.08;
	float luminance = dot(scene, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(scene, vec3(luminance), 0.12) * vec3(0.91, 0.96, 1.03) * 0.87;
	float left_shade = 1.0 - smoothstep(0.02, 0.76, uv.x);
	float bottom_shade = smoothstep(0.65, 1.0, uv.y) * 0.12;
	float darkness = clamp(0.08 + left_shade * 0.80 + bottom_shade, 0.0, 0.94);
	vec3 result = mix(graded, vec3(0.009, 0.024, 0.038), darkness);
	COLOR = vec4(result, 1.0);
}
