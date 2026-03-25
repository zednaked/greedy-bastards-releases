// Ghost overlay para jogadores remotos.
// Rim fresnel + drift animado de névoa.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform float rim_power  : hint_range(1.0, 8.0) = 2.8;
uniform float rim_energy : hint_range(0.0, 4.0) = 1.2;
uniform float drift_speed : hint_range(0.0, 3.0) = 0.6;
uniform vec4  ghost_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	// Névoa animada — duas ondas se cruzando ao longo dos UVs
	float drift = sin(UV.y * 6.0 + TIME * drift_speed)       * 0.5 + 0.5;
	drift      *= sin(UV.x * 4.0 - TIME * drift_speed * 0.7) * 0.5 + 0.5;

	float alpha = fresnel * rim_energy + drift * 0.08;

	EMISSION = ghost_color.rgb * (fresnel * rim_energy + drift * 0.18);
	ALBEDO   = ghost_color.rgb;
	ALPHA    = clamp(alpha, 0.0, 1.0);
}
