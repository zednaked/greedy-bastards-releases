// Chão molhado com poças procedurais e manchas de sangue.
// Aplica sobre o mesh do chão (material_override) substituindo o material base.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, hint_default_white;
uniform vec4  dry_color   : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4  wet_color   : source_color = vec4(0.72, 0.68, 0.62, 1.0);
uniform vec4  blood_color : source_color = vec4(0.35, 0.05, 0.04, 1.0);
uniform float wetness     : hint_range(0.0, 1.0) = 0.30;
uniform float uv_scale    : hint_range(0.1, 8.0) = 2.0;

// Hash rápido sem trig
float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.35));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

// Hash suave — evita bordas duras entre células
float smooth_hash(vec2 uv, float scale) {
	vec2 i = floor(uv * scale);
	vec2 f = fract(uv * scale);
	f = f * f * (3.0 - 2.0 * f);  // smoothstep
	return mix(
		mix(hash21(i),           hash21(i + vec2(1,0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x),
		f.y
	);
}

void fragment() {
	vec2 uv = UV * uv_scale;

	vec4 tex = texture(texture_albedo, uv);

	// Padrão de poças — duas frequências sobrepostas para variação orgânica
	float puddle_a = smooth_hash(UV, 2.2);
	float puddle_b = smooth_hash(UV + vec2(0.31, 0.67), 4.5) * 0.4;
	float puddle   = clamp(puddle_a + puddle_b - 0.15, 0.0, 1.0);
	float local_wet = clamp(wetness * 1.3 * puddle, 0.0, 1.0);

	// Manchas de sangue seco — células maiores, mais esparsas
	float blood_mask = smooth_hash(UV + vec2(1.3, 2.7), 1.1);
	float blood_spot = step(0.74, blood_mask) * smooth_hash(UV, 3.5);

	// Albedo: dry → wet → blood
	vec3 col = mix(dry_color.rgb, wet_color.rgb, local_wet);
	col       = mix(col, blood_color.rgb, blood_spot * 0.40);
	col      *= tex.rgb;

	ALBEDO    = col;
	ROUGHNESS = mix(0.78, 0.05, local_wet);
	METALLIC  = 0.0;
	SPECULAR  = mix(0.20, 0.92, local_wet);
}
