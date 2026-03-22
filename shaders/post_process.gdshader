shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float vignette_strength : hint_range(0.0, 3.0) = 0.18;
uniform float grain_amount      : hint_range(0.0, 0.1) = 0.018;
uniform float aberration        : hint_range(0.0, 0.03) = 0.0;
uniform float sharpen           : hint_range(0.0, 2.0) = 0.40;
uniform float hit_flash         : hint_range(0.0, 1.0) = 0.0;
uniform float time              : hint_range(0.0, 10000.0) = 0.0;

// High-quality temporally stable noise
float gold_noise(vec2 uv, float seed) {
	return fract(tan(distance(
		uv * (seed + 1.6180339887),
		vec2(uv.x * 1.6180339887 + 0.3183098861, uv.y * 2.7182818284 + 0.7853981633)
	)) * 1e5);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	// ── Chromatic aberration — R shifts right, B shifts left ──────────────
	float ab = aberration;
	vec4 col;
	col.r = texture(screen_texture, uv + vec2( ab, 0.0)).r;
	col.g = texture(screen_texture, uv               ).g;
	col.b = texture(screen_texture, uv - vec2( ab, 0.0)).b;
	col.a = 1.0;

	// ── Unsharp-mask sharpening ────────────────────────────────────────────
	if (sharpen > 0.001) {
		vec3 blur = (
			texture(screen_texture, uv + vec2( px.x,  0.0)).rgb +
			texture(screen_texture, uv + vec2(-px.x,  0.0)).rgb +
			texture(screen_texture, uv + vec2( 0.0,  px.y)).rgb +
			texture(screen_texture, uv + vec2( 0.0, -px.y)).rgb
		) * 0.25;
		col.rgb += (col.rgb - blur) * sharpen;
	}

	// ── Vignette — oval, darkens edges ────────────────────────────────────
	vec2 vig_uv = (uv * 2.0 - 1.0) * vec2(0.88, 1.0);
	float vig = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;
	vig = clamp(pow(vig, 1.8), 0.0, 1.0);
	col.rgb *= vig;

	// ── Film grain — temporally animated, perceptually weighted ───────────
	float grain = gold_noise(uv, fract(time * 0.0173)) * 2.0 - 1.0;
	// Grain more visible in mids, less in bright/dark areas
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float grain_mask = 1.0 - abs(luma * 2.0 - 1.0);
	col.rgb = clamp(col.rgb + grain * grain_amount * grain_mask, 0.0, 1.0);

	// ── Hit flash — blood bleeds in from edges ────────────────────────────
	if (hit_flash > 0.001) {
		float edge  = 1.0 - vig;
		vec3  blood = vec3(0.82, 0.025, 0.015);
		// Edge bleed
		col.rgb = mix(col.rgb, blood, edge * hit_flash * 0.72);
		// Subtle inner red tint
		col.rgb *= mix(vec3(1.0), vec3(1.12, 0.82, 0.80), hit_flash * 0.22);
	}

	COLOR = col;
}
