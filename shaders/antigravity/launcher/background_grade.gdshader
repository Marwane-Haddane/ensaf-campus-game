shader_type canvas_item;

// Cinematic background color grading & subtle vignette for dusk campus
uniform vec4 deep_tint : source_color = vec4(0.06, 0.08, 0.12, 1.0);
uniform float image_brightness : hint_range(0.0, 2.0) = 0.88;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.60;
uniform float shadow_navy_mix : hint_range(0.0, 1.0) = 0.22;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 color = tex_color.rgb * image_brightness;
    
    // Soft vignette towards screen edges
    vec2 center = UV - vec2(0.5);
    float dist = length(center);
    float vignette = clamp(1.0 - dist * vignette_strength, 0.0, 1.0);
    color *= vignette;
    
    // Deep navy treatment in shadows while preserving luminous windows and reflections
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float shadow_factor = clamp(1.0 - luma * 1.6, 0.0, 1.0);
    vec3 graded = mix(color, deep_tint.rgb, shadow_factor * shadow_navy_mix);

    // Subtle dark scrim over left and lower area to ensure high contrast and legibility
    float left_scrim = smoothstep(0.45, 0.0, UV.x) * 0.18;
    float bottom_scrim = smoothstep(0.45, 1.0, UV.y) * 0.24;
    float scrim = max(left_scrim, bottom_scrim);
    graded = mix(graded, deep_tint.rgb, scrim);

    COLOR = vec4(graded, 1.0);
}

