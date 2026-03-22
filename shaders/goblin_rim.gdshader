// Additive rim overlay para goblins.
// Rage: veias de energia Voronoi craquelando pela superfície.
// Leader: sparkles dourados + shimmer metálico animado.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform float rim_energy   : hint_range(0.0, 5.0) = 1.3;
uniform float rim_power    : hint_range(1.0, 8.0) = 4.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float rage_glow    : hint_range(0.0, 1.0) = 0.0;
uniform float leader_glow  : hint_range(0.0, 1.0) = 0.0;

// Hash rápido sem trig
vec2 hash22(vec2 p) {
	p = fract(p * vec2(234.34, 435.35));
	p += dot(p, p + 34.23);
	return fract(vec2(p.x * p.y, p.x + p.y));
}
float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.35));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

// Voronoi — retorna distância à borda da célula mais próxima (= veias/craquelamento)
float voronoi_edge(vec2 uv, float scale) {
	vec2 i = floor(uv * scale);
	vec2 f = fract(uv * scale);
	float min_d = 10.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 nb  = vec2(float(x), float(y));
			vec2 pt  = hash22(i + nb) + nb - f;
			min_d    = min(min_d, dot(pt, pt));
		}
	}
	// Borda da célula = veia
	return 1.0 - smoothstep(0.0, 0.18, sqrt(min_d));
}

// Sparkles — pontos brilhantes que piscam em fases diferentes
float sparkle(vec2 uv, float t) {
	vec2  i     = floor(uv * 9.0);
	vec2  f     = fract(uv * 9.0) - 0.5;
	float h     = hash21(i);
	float blink = pow(sin(t * (2.0 + h * 5.0) + h * 6.2831) * 0.5 + 0.5, 4.0);
	float star  = max(0.0, 1.0 - abs(f.x) * 7.5) * max(0.0, 1.0 - abs(f.y) * 7.5);
	return pow(star, 2.0) * blink * step(0.60, h);  // só ~40% das células têm sparkle
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	// ── Rim base — laranja perigo ──────────────────────────────────────────
	vec3 rim = vec3(1.0, 0.28, 0.04) * fresnel * rim_energy;

	// ── Rage: veias de energia craquelando ────────────────────────────────
	if (rage_glow > 0.001) {
		float t = TIME;
		// Veias sobem ao longo do UV com o tempo
		vec2  uv_scroll = UV + vec2(sin(t * 0.4) * 0.05, t * 0.12);
		float vein      = voronoi_edge(uv_scroll, 4.5);
		// Pulso que viaja de baixo para cima
		float pulse     = sin(t * 7.0 - UV.y * 10.0) * 0.45 + 0.55;
		vein *= pulse;

		vec3 vein_col = mix(
			vec3(1.0, 0.06, 0.0),   // vermelho profundo (borda das células)
			vec3(1.0, 0.5, 0.1),    // laranja-branco (centro/pico)
			vein * 0.6
		) * (vein * 2.5 + fresnel * 2.5);

		rim = mix(rim, vein_col, rage_glow);
	}

	// ── Leader: sparkles dourados + shimmer metálico ───────────────────────
	if (leader_glow > 0.001) {
		float t = TIME;

		// Sparkles — piscam em fases aleatórias
		float sp = sparkle(UV, t) * 5.0;

		// Shimmer — ondas metálicas animadas em dois eixos
		float sh = sin(UV.x * 18.0 + t * 2.2) * sin(UV.y * 12.0 - t * 1.7);
		sh = sh * 0.5 + 0.5;
		sh *= fresnel;  // mais forte no contorno

		vec3 gold_rim     = vec3(1.0, 0.80, 0.10) * fresnel * 3.0;
		vec3 gold_sparkle = vec3(1.0, 0.96, 0.65) * sp;
		vec3 gold_shimmer = vec3(1.0, 0.88, 0.35) * sh * 1.8;

		rim = mix(rim, gold_rim + gold_sparkle + gold_shimmer, leader_glow);
	}

	// ── Damage flash — burst branco ao tomar dano ─────────────────────────
	float flash = damage_flash * (fresnel * 2.5 + 0.4);

	ALBEDO = rim + vec3(flash);
	ALPHA  = clamp(length(rim) * 0.85 + damage_flash * 0.65, 0.0, 1.0);
}
