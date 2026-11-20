shader_type spatial;
// Fountain pools and falls: tinted transparent water with a cheap moving shimmer.
// No textures or UVs (the baked mesh has none); world position drives the ripples.
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.36, 0.55, 0.58, 0.62);
uniform vec4 crest_color : source_color = vec4(0.82, 0.93, 0.95, 0.78);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	float ripple = sin(world_pos.x * 5.0 + t * 1.7) * sin(world_pos.z * 4.3 - t * 1.3);
	ripple += 0.5 * sin((world_pos.x + world_pos.z) * 9.0 - t * 2.6);
	float fall = sin(world_pos.y * 14.0 + t * 7.0) * 0.5 + 0.5;
	float crest = clamp(ripple * 0.35 + 0.35, 0.0, 1.0) * 0.6 + fall * 0.25;
	vec4 c = mix(deep_color, crest_color, crest);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	NORMAL = normalize(NORMAL + vec3(ripple * 0.06, 0.0, ripple * 0.04));
}
