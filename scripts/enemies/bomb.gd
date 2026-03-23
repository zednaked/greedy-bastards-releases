extends Node3D

var _velocity: Vector3 = Vector3.ZERO
var _lifetime: float = 8.0
var _landed: bool = false
var _fuse_timer: float = 2.2
var damage: int = 2
var explosion_radius: float = 3.0
const GRAVITY: float = 9.8

func launch(origin: Vector3, target_pos: Vector3, speed: float) -> void:
	global_position = origin
	var to_target := target_pos - origin
	var horiz_dist := Vector2(to_target.x, to_target.z).length()
	var time_of_flight := horiz_dist / speed
	var dir_h := Vector3(to_target.x, 0.0, to_target.z).normalized()
	_velocity = dir_h * speed
	_velocity.y = (to_target.y + 0.5 * GRAVITY * time_of_flight * time_of_flight) / time_of_flight

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		# Garante que explode no chão mesmo que o timer expire ainda no ar
		if not _landed:
			global_position.y = 0.1
		_explode()
		return

	if not _landed:
		_velocity.y -= GRAVITY * delta
		global_position += _velocity * delta
		# Simple ground check: y near 0
		if global_position.y <= 0.1:
			global_position.y = 0.1
			_landed = true
			_velocity = Vector3.ZERO
			# Pulse scale to hint fuse
			var tween := create_tween().set_loops()
			tween.tween_property(self, "scale", Vector3(1.3, 0.7, 1.3), 0.25)
			tween.tween_property(self, "scale", Vector3.ONE, 0.25)
	else:
		_fuse_timer -= delta
		if _fuse_timer <= 0.0:
			_explode()

func _explode() -> void:
	set_process(false)
	visible = false

	# Dano antes do FX — hit stop do player vai pausar tudo brevemente
	var origin := global_position
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node:
		var p3d := player_node as Node3D
		if p3d and p3d.global_position.distance_to(origin) <= explosion_radius:
			var dir: Vector3 = (p3d.global_position - origin).normalized()
			if p3d.has_method("take_damage"):
				p3d.take_damage(damage, dir * 8.0 + Vector3(0, 4.0, 0))
		# Screen trauma para qualquer distância < radius * 2
		if p3d:
			var dist := p3d.global_position.distance_to(origin)
			var trauma_amt := clampf(1.0 - dist / (explosion_radius * 2.5), 0.0, 1.0)
			if trauma_amt > 0.05 and p3d.has_method("add_trauma"):
				p3d.add_trauma(trauma_amt * 0.9)
			# Flash de tela — laranja se dentro do raio
			if dist <= explosion_radius * 1.5:
				var hud := get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("flash_explosion"):
					hud.flash_explosion(clampf(1.0 - dist / (explosion_radius * 1.5), 0.15, 0.75))

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e3d := enemy as Node3D
		if e3d and e3d.global_position.distance_to(origin) <= explosion_radius:
			var dir: Vector3 = (e3d.global_position - origin).normalized()
			if enemy.has_method("take_hit"):
				enemy.take_hit(dir * 15.0 + Vector3(0, 5.0, 0))

	_spawn_explosion_fx(origin)
	queue_free()

func _spawn_explosion_fx(origin: Vector3) -> void:
	var scene := get_tree().current_scene

	# ── 1. Luz pontual — flash brilhante ──────────────────────────────────────
	var light := OmniLight3D.new()
	light.light_color      = Color(1.0, 0.6, 0.15)
	light.light_energy     = 12.0
	light.omni_range       = explosion_radius * 5.0
	light.shadow_enabled   = false
	scene.add_child(light)
	light.global_position  = origin + Vector3(0.0, 0.6, 0.0)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	lt.tween_callback(func(): if is_instance_valid(light): light.queue_free())

	# ── 2. Esfera de flash — bola de fogo central ─────────────────────────────
	var fireball := MeshInstance3D.new()
	var fb_mesh  := SphereMesh.new()
	fb_mesh.radius = 0.15
	fb_mesh.height = 0.3
	fireball.mesh  = fb_mesh
	var fb_mat := StandardMaterial3D.new()
	fb_mat.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	fb_mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	fb_mat.albedo_color             = Color(1.0, 0.85, 0.4, 0.92)
	fb_mat.emission_enabled         = true
	fb_mat.emission                 = Color(1.0, 0.5, 0.05)
	fb_mat.emission_energy_multiplier = 6.0
	fb_mat.cull_mode                = BaseMaterial3D.CULL_DISABLED
	fireball.material_override = fb_mat
	scene.add_child(fireball)
	fireball.global_position = origin + Vector3(0.0, 0.5, 0.0)
	var ft := fireball.create_tween().set_parallel(true)
	ft.tween_property(fireball, "scale", Vector3.ONE * explosion_radius * 2.2, 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	ft.tween_property(fb_mat, "albedo_color:a", 0.0, 0.32)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	ft.chain().tween_callback(func(): if is_instance_valid(fireball): fireball.queue_free())

	# ── 3. Anel de shockwave no chão ──────────────────────────────────────────
	var ring := MeshInstance3D.new()
	var r_mesh := CylinderMesh.new()
	r_mesh.top_radius    = 0.06
	r_mesh.bottom_radius = 0.06
	r_mesh.height        = 0.05
	ring.mesh = r_mesh
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.albedo_color             = Color(1.0, 0.75, 0.2, 0.9)
	r_mat.emission_enabled         = true
	r_mat.emission                 = Color(1.0, 0.4, 0.0)
	r_mat.emission_energy_multiplier = 4.0
	r_mat.cull_mode                = BaseMaterial3D.CULL_DISABLED
	ring.material_override = r_mat
	scene.add_child(ring)
	ring.global_position = origin + Vector3(0.0, 0.08, 0.0)
	var rt := ring.create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(explosion_radius * 2.8, 0.06, explosion_radius * 2.8), 0.38)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	rt.tween_property(r_mat, "albedo_color:a", 0.0, 0.38)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	rt.chain().tween_callback(func(): if is_instance_valid(ring): ring.queue_free())

	# ── 4. Partículas de fogo — burst principal ───────────────────────────────
	var fire_ps := GPUParticles3D.new()
	var fire_mat := ParticleProcessMaterial.new()
	fire_mat.direction               = Vector3.UP
	fire_mat.spread                  = 75.0
	fire_mat.initial_velocity_min    = 5.0
	fire_mat.initial_velocity_max    = 16.0
	fire_mat.gravity                 = Vector3(0.0, -8.0, 0.0)
	fire_mat.scale_min               = 0.12
	fire_mat.scale_max               = 0.45
	fire_mat.color                   = Color(1.0, 0.5, 0.05)
	fire_mat.collision_mode          = ParticleProcessMaterial.COLLISION_DISABLED
	fire_ps.process_material = fire_mat
	fire_ps.amount       = 80
	fire_ps.lifetime     = 0.65
	fire_ps.one_shot     = true
	fire_ps.explosiveness = 0.96
	fire_ps.emitting     = true
	scene.add_child(fire_ps)
	fire_ps.global_position = origin + Vector3(0.0, 0.3, 0.0)
	fire_ps.finished.connect(func(): if is_instance_valid(fire_ps): fire_ps.queue_free())

	# ── 5. Fumaça — sobe mais devagar e dura mais ─────────────────────────────
	var smoke_ps := GPUParticles3D.new()
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction              = Vector3.UP
	smoke_mat.spread                 = 40.0
	smoke_mat.initial_velocity_min   = 1.5
	smoke_mat.initial_velocity_max   = 4.5
	smoke_mat.gravity                = Vector3(0.0, -1.0, 0.0)
	smoke_mat.scale_min              = 0.3
	smoke_mat.scale_max              = 0.9
	smoke_mat.color                  = Color(0.18, 0.14, 0.10, 0.7)
	smoke_mat.collision_mode         = ParticleProcessMaterial.COLLISION_DISABLED
	smoke_ps.process_material = smoke_mat
	smoke_ps.amount       = 30
	smoke_ps.lifetime     = 1.8
	smoke_ps.one_shot     = true
	smoke_ps.explosiveness = 0.75
	smoke_ps.emitting     = true
	scene.add_child(smoke_ps)
	smoke_ps.global_position = origin + Vector3(0.0, 0.5, 0.0)
	smoke_ps.finished.connect(func(): if is_instance_valid(smoke_ps): smoke_ps.queue_free())

	# ── 6. Debris — pedaços voando para fora ──────────────────────────────────
	for i in 7:
		var rb := RigidBody3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := randf_range(0.06, 0.20)
		bm.size = Vector3(sz, sz * randf_range(0.5, 1.0), sz * randf_range(0.6, 1.0))
		mi.mesh = bm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(randf_range(0.12, 0.28), randf_range(0.08, 0.16), 0.04)
		dm.roughness    = 1.0
		mi.material_override = dm
		var col := CollisionShape3D.new()
		var bs  := BoxShape3D.new()
		bs.size = bm.size
		col.shape = bs
		rb.add_child(mi)
		rb.add_child(col)
		scene.add_child(rb)
		rb.global_position = origin + Vector3(randf_range(-0.3, 0.3), 0.4, randf_range(-0.3, 0.3))
		var angle := randf() * TAU
		var force := randf_range(4.0, 10.0)
		rb.linear_velocity  = Vector3(cos(angle) * force, randf_range(5.0, 12.0), sin(angle) * force)
		rb.angular_velocity = Vector3(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		get_tree().create_timer(4.5).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())

	# ── 7. Marca de queimado no chão (disco escuro plano) ─────────────────────
	var scorch := MeshInstance3D.new()
	var sc_mesh := CylinderMesh.new()
	sc_mesh.top_radius    = explosion_radius * 1.1
	sc_mesh.bottom_radius = explosion_radius * 1.1
	sc_mesh.height        = 0.01
	scorch.mesh = sc_mesh
	var sc_mat := StandardMaterial3D.new()
	sc_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	sc_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	sc_mat.albedo_color   = Color(0.04, 0.03, 0.02, 0.72)
	scorch.material_override = sc_mat
	scene.add_child(scorch)
	scorch.global_position = origin + Vector3(0.0, 0.02, 0.0)
	# Fade lento — persiste por 6s
	var st := scorch.create_tween()
	st.tween_interval(4.0)
	st.tween_property(sc_mat, "albedo_color:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	st.tween_callback(func(): if is_instance_valid(scorch): scorch.queue_free())
