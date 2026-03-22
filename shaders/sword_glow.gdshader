// Additive rim + emission overlay — vai como next_pass sobre o material original da espada.
// blend_add: só adiciona luz, nunca cobre a textura original.
// depth_draw_never: sem z-write, sem interferência de depth.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4  rim_color   : source_color = vec4(0.42, 0.70, 1.00, 1.0);
uniform float rim_power   : hint_range(1.0, 8.0) = 3.6;
uniform float rim_energy  : hint_range(0.0, 5.0) = 1.5;

uniform vec4  emit_color  : source_color = vec4(0.30, 0.58, 1.00, 1.0);
uniform float emit_energy : hint_range(0.0, 12.0) = 0.0;  // animado por GDScript no ataque

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	// Rim permanente — azul-branco energético
	vec3 rim = rim_color.rgb * fresnel * rim_energy;

	// Emissão de ataque — pulso rápido durante o swing
	float pulse = sin(TIME * 13.0) * 0.38 + 0.62;
	vec3 emit   = emit_color.rgb * emit_energy * pulse;

	// Hotspot na ponta da lâmina (UV.y perto de 1 = ponta)
	float tip_glow = smoothstep(0.55, 1.0, UV.y) * emit_energy;
	emit += emit_color.rgb * tip_glow * 1.8;

	ALBEDO = rim + emit;
	ALPHA  = clamp(length(rim) * 0.8 + emit_energy * 0.25, 0.0, 1.0);
}
