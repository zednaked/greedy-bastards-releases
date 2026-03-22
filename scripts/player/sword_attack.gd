extends Node3D

@export_group("Combate")
@export var knockback_force: float = 18.0
@export var peak_threshold: float = 12.0
@export var spike_ratio: float = 3.0
@export var attack_window: float = 0.08
@export var attack_cooldown_time: float = 0.14
@export var hit_stop_duration: float = 0.065
@export var hit_stop_parry: float = 0.105
@export var hit_stop_kill: float = 0.13

@export_group("Input Buffer & Lunge")
@export var attack_buffer_window: float = 0.20
@export var lunge_force: float = 5.0
@export var lunge_duration: float = 0.08

@export_group("Física da Arma")
@export var weapon_spring: float = 22.0
@export var weapon_damp: float = 0.50
@export var sway_mouse_factor: float = 0.0008
@export var sway_walk_amplitude: float = 0.030

@export_group("Swing 1 — Estocada")
@export var s1_pull_z: float = 0.14
@export var s1_pull_rot_x: float = 12.0
@export var s1_hit_z: float = -0.48
@export var s1_hit_rot_x: float = -88.0
@export var s1_t_pull: float = 0.03
@export var s1_t_hit: float = 0.03
@export var s1_t_return: float = 0.05

@export_group("Swing 2 — Overhead")
@export var s2_raise_y: float = 0.30
@export var s2_raise_rot_x: float = 35.0
@export var s2_slam_y: float = -0.10
@export var s2_slam_rot_x: float = -75.0
@export var s2_t_raise: float = 0.045
@export var s2_t_slam: float = 0.035
@export var s2_t_return: float = 0.06

@export_group("Arremesso")
@export var throw_speed: float = 22.0
@export var throw_damage_knockback: float = 25.0
@export var throw_pickup_range: float = 2.5

const REST_POS := Vector3(-0.15, 0.05, 0.1)
const REST_ROT := Vector3(0.0, deg_to_rad(80.0), deg_to_rad(-15.0))

@onready var weapon_mesh: Node3D = $SwordMesh
@onready var hitbox: Area3D      = $SwordHitbox
@onready var swing_sound: AudioStreamPlayer3D = $SwingSound

var player: CharacterBody3D

var spring_pos := REST_POS
var spring_vel := Vector3.ZERO

var mouse_accum := Vector2.ZERO
var mouse_peak  := Vector2.ZERO
var prev_peak   := 0.0
var accum_timer := 0.0

var is_attacking    := false
var _is_flick       := false
var attack_cooldown := 0.0
var _attack_id      := 0
var _current_tween: Tween = null
var _hit_bodies: Array = []

var _attack_buffered: bool = false
var _buffer_age: float = 0.0

var _lunge_timer: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO

var _combo_count: int = 0
var _combo_timer: float = 0.0
const COMBO_RESET_TIME := 1.2

var _click_combo: int = 0
var _click_timer: float = 0.0
const CLICK_COMBO_RESET_TIME := 0.9

# ─── Sword glow ───────────────────────────────────────────────────────────────
var _sword_glow_mat: ShaderMaterial = null

# ─── Arremesso ────────────────────────────────────────────────────────────────
var has_weapon: bool = true
var _thrown: RigidBody3D = null
var _throw_label: Label3D = null

func _ready() -> void:
	hitbox.monitoring = false
	spring_pos = REST_POS
	player = get_parent().get_parent()
	_setup_sword_glow()

func _setup_sword_glow() -> void:
	var shader := load("res://shaders/sword_glow.gdshader") as Shader
	if shader == null:
		return
	_sword_glow_mat = ShaderMaterial.new()
	_sword_glow_mat.shader = shader
	# Aplica como next_pass em cada surface de cada MeshInstance3D filha da espada
	for mi in weapon_mesh.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		for s in mesh_inst.mesh.get_surface_count():
			var orig := mesh_inst.get_active_material(s)
			if orig != null:
				orig.next_pass = _sword_glow_mat
			else:
				mesh_inst.set_surface_override_material(s, _sword_glow_mat)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_accum += event.relative
		if event.relative.length() > mouse_peak.length():
			mouse_peak = event.relative

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# RMB: arremessa se tem arma, senão ignora
			if has_weapon:
				_throw_sword()
			return
		if not has_weapon:
			return
		if attack_cooldown <= 0.0:
			var can_fire := not is_attacking or _is_flick
			if can_fire:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_cancel_flick()
					_trigger_click_attack()
			else:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_attack_buffered = true
					_buffer_age = 0.0
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_attack_buffered = true
				_buffer_age = 0.0

	# E para pegar a espada arremessada
	if event.is_action_pressed("interact") and _thrown != null:
		if is_instance_valid(_thrown) and _thrown.get_meta("landed", false):
			if player.global_position.distance_to(_thrown.global_position) <= throw_pickup_range:
				_return_sword()

func _process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if _combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_count = 0
	if _click_combo > 0:
		_click_timer -= delta
		if _click_timer <= 0.0:
			_click_combo = 0

	if _attack_buffered and has_weapon:
		_buffer_age += delta
		if _buffer_age > attack_buffer_window:
			_attack_buffered = false
		elif attack_cooldown <= 0.0 and not is_attacking:
			_attack_buffered = false
			_cancel_flick()
			_trigger_click_attack()

	if _lunge_timer > 0.0 and player:
		_lunge_timer -= delta
		player.velocity.x = lerpf(player.velocity.x, _lunge_dir.x * lunge_force, 0.35)
		player.velocity.z = lerpf(player.velocity.z, _lunge_dir.z * lunge_force, 0.35)

	accum_timer += delta
	if accum_timer >= attack_window:
		var cur_peak := mouse_peak.length()
		if has_weapon and not is_attacking and attack_cooldown <= 0.0:
			if cur_peak > peak_threshold and cur_peak > prev_peak * spike_ratio:
				_is_flick = true
				_trigger_attack(mouse_accum)
		prev_peak   = cur_peak
		mouse_accum = Vector2.ZERO
		mouse_peak  = Vector2.ZERO
		accum_timer = 0.0

	# Prompt de pickup
	if _throw_label != null and is_instance_valid(_throw_label) and _thrown != null:
		if is_instance_valid(_thrown) and _thrown.get_meta("landed", false):
			var dist := player.global_position.distance_to(_thrown.global_position)
			_throw_label.visible = dist <= throw_pickup_range

	if hitbox.monitoring:
		for body in hitbox.get_overlapping_bodies():
			if body not in _hit_bodies:
				_hit_bodies.append(body)
				_on_hit(body)

	_update_spring(delta)

# ─── Arremesso ────────────────────────────────────────────────────────────────

func _throw_sword() -> void:
	if not has_weapon or _thrown != null:
		return
	has_weapon = false
	weapon_mesh.visible = false
	hitbox.monitoring = false
	if _current_tween:
		_current_tween.kill()
	is_attacking = false

	# RigidBody3D projétil
	_thrown = RigidBody3D.new()
	_thrown.set_meta("landed", false)
	_thrown.contact_monitor = true
	_thrown.max_contacts_reported = 1

	# Visual — clona o mesh da espada
	var visual := weapon_mesh.duplicate(7)
	visual.visible = true
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	_thrown.add_child(visual)

	# Colisão
	var cs  := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.09, 0.09, 0.85)
	cs.shape = box
	_thrown.add_child(cs)

	# Prompt de pickup
	_throw_label = Label3D.new()
	_throw_label.text = "[E] Pegar espada"
	_throw_label.pixel_size = 0.004
	_throw_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_throw_label.visible = false
	_thrown.add_child(_throw_label)

	get_tree().current_scene.add_child(_thrown)
	_thrown.global_transform = weapon_mesh.global_transform

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir := -cam.global_transform.basis.z
	_thrown.linear_velocity  = dir * throw_speed
	_thrown.angular_velocity = Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-4.0, 4.0))

	# Conecta colisão — ignora player
	_thrown.body_entered.connect(func(body: Node):
		if body.is_in_group("player"):
			return
		_on_thrown_hit(body)
	)

	# Cleanup de segurança após 30s
	get_tree().create_timer(30.0, true).timeout.connect(func():
		if is_instance_valid(_thrown):
			_thrown.queue_free()
		_thrown = null
		_throw_label = null
		if not has_weapon:
			has_weapon = true
			weapon_mesh.visible = true
	)

func _on_thrown_hit(body: Node) -> void:
	if _thrown == null or not is_instance_valid(_thrown):
		return
	if _thrown.get_meta("landed", false):
		return
	_thrown.set_meta("landed", true)

	if body.is_in_group("enemies") and body.has_method("take_hit"):
		var dir := _thrown.linear_velocity.normalized()
		body.take_hit(dir * throw_damage_knockback)

	# Para e espera pickup
	_thrown.freeze = true
	_thrown.linear_velocity  = Vector3.ZERO
	_thrown.angular_velocity = Vector3.ZERO

func _return_sword() -> void:
	if _thrown != null and is_instance_valid(_thrown):
		_thrown.queue_free()
	_thrown = null
	_throw_label = null
	has_weapon = true
	weapon_mesh.visible = true
	spring_pos = REST_POS
	spring_vel = Vector3.ZERO

# ─── Spring / Sway ────────────────────────────────────────────────────────────

func _cancel_flick() -> void:
	if _current_tween:
		_current_tween.kill()
		_current_tween = null
	hitbox.monitoring = false
	_is_flick = false
	is_attacking = false
	weapon_mesh.position = REST_POS
	weapon_mesh.rotation = REST_ROT
	spring_pos = REST_POS
	spring_vel = Vector3.ZERO

func _update_spring(delta: float) -> void:
	if is_attacking or not has_weapon:
		return

	var mouse_influence := Vector3(
		mouse_accum.x *  sway_mouse_factor,
		mouse_accum.y * -sway_mouse_factor,
		0.0
	).limit_length(sway_mouse_factor * 80.0)

	var walk_sway := Vector3.ZERO
	if player:
		var hvel := Vector2(player.velocity.x, player.velocity.z)
		var speed_t := clampf(hvel.length() / 5.0, 0.0, 1.0)
		var t := Time.get_ticks_msec() * 0.001
		walk_sway = Vector3(
			sin(t * 8.0) * sway_walk_amplitude * speed_t,
			abs(sin(t * 8.0)) * -sway_walk_amplitude * 0.67 * speed_t,
			0.0
		)

	var target := REST_POS + mouse_influence + walk_sway
	spring_vel += (target - spring_pos) * weapon_spring * delta
	spring_vel  *= pow(weapon_damp, delta * 60.0)
	spring_pos  += spring_vel * delta
	weapon_mesh.position = spring_pos

# ─── Ataques ──────────────────────────────────────────────────────────────────

func _trigger_click_attack() -> void:
	if not has_weapon: return
	_click_combo = (_click_combo % 4) + 1
	_click_timer = CLICK_COMBO_RESET_TIME
	match _click_combo:
		1: _do_thrust()
		2: _do_backhand()
		3: _do_overhead()
		4: _do_pommel_strike()

# ── Ataque 1: Estocada ─────────────────────────────────────────────────────
func _do_thrust() -> void:
	_begin_attack()
	var my_id := _attack_id
	weapon_mesh.position = REST_POS
	weapon_mesh.rotation = REST_ROT

	var pull_pos := REST_POS + Vector3(0.0, 0.02, s1_pull_z)
	var pull_rot := REST_ROT + Vector3(deg_to_rad(s1_pull_rot_x), 0.0, 0.0)
	var hit_pos  := REST_POS + Vector3(0.0, 0.0, s1_hit_z)
	var hit_rot  := REST_ROT + Vector3(deg_to_rad(s1_hit_rot_x), 0.0, 0.0)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(weapon_mesh, "position", pull_pos, s1_t_pull)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", pull_rot, s1_t_pull)
	_current_tween.tween_callback(func(): hitbox.monitoring = true)
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_current_tween.tween_property(weapon_mesh, "position", hit_pos, s1_t_hit)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", hit_rot, s1_t_hit)
	_current_tween.parallel().tween_property(hitbox, "position", hit_pos, s1_t_hit)
	_current_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(weapon_mesh, "position", REST_POS, s1_t_return)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", REST_ROT, s1_t_return)
	_current_tween.finished.connect(func(): _on_swing_done(my_id), CONNECT_ONE_SHOT)

# ── Ataque 2: Contragolpe com o reverso ────────────────────────────────────
func _do_backhand() -> void:
	var wind_pos   := REST_POS + Vector3(-0.24, 0.04, 0.04)
	var wind_rot   := REST_ROT + Vector3(0.0, 0.0, deg_to_rad(-35.0))
	var strike_pos := REST_POS + Vector3(0.32, 0.02, -0.06)
	var strike_rot := REST_ROT + Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(55.0))
	_do_swing(strike_pos, strike_rot, 0.055, 0.09, wind_pos, wind_rot)

# ── Ataque 3: Overhead slam ────────────────────────────────────────────────
func _do_overhead() -> void:
	_begin_attack()
	_lunge_timer = 0.0
	var my_id := _attack_id
	weapon_mesh.position = REST_POS
	weapon_mesh.rotation = REST_ROT

	var raise_pos := REST_POS + Vector3(0.0, s2_raise_y, 0.08)
	var raise_rot := REST_ROT + Vector3(deg_to_rad(s2_raise_rot_x), 0.0, 0.0)
	var slam_pos  := REST_POS + Vector3(0.0, s2_slam_y, -0.06)
	var slam_rot  := REST_ROT + Vector3(deg_to_rad(s2_slam_rot_x), 0.0, 0.0)

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(weapon_mesh, "position", raise_pos, s2_t_raise)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", raise_rot, s2_t_raise)
	_current_tween.tween_callback(func(): hitbox.monitoring = true)
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_current_tween.tween_property(weapon_mesh, "position", slam_pos, s2_t_slam)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", slam_rot, s2_t_slam)
	_current_tween.parallel().tween_property(hitbox, "position", slam_pos, s2_t_slam)
	_current_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(weapon_mesh, "position", REST_POS, s2_t_return)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", REST_ROT, s2_t_return)
	_current_tween.finished.connect(func(): _on_swing_done(my_id), CONNECT_ONE_SHOT)

# ── Ataque 4: Golpe com a empunhadura (pommel) ─────────────────────────────
func _do_pommel_strike() -> void:
	_lunge_timer = 0.0
	var raise_pos := REST_POS + Vector3(0.06, 0.22, 0.06)
	var raise_rot := REST_ROT + Vector3(deg_to_rad(60.0), 0.0, deg_to_rad(-20.0))
	var hit_pos   := REST_POS + Vector3(0.04, -0.08, -0.10)
	var hit_rot   := REST_ROT + Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(10.0))
	_do_swing(hit_pos, hit_rot, 0.05, 0.10, raise_pos, raise_rot)

func _trigger_attack(dir: Vector2) -> void:
	if not has_weapon: return
	_combo_count += 1
	_combo_timer = COMBO_RESET_TIME
	var sx := signf(dir.x) if absf(dir.x) > 0.1 else 1.0
	var sy := signf(dir.y) if absf(dir.y) > 0.1 else 1.0
	if _combo_count >= 3:
		_combo_count = 0
		_do_spin_finisher()
		return
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if ay > ax * 1.4:
		if dir.y < 0.0:
			_do_rising_slash(sx)
		else:
			_do_slam_slash(sx)
	elif ax > ay * 1.4:
		_do_horizontal_slash(sx)
	else:
		_do_diagonal_slash(sx, sy)

func _do_horizontal_slash(sx: float) -> void:
	var start_pos := REST_POS + Vector3(sx * 0.22, 0.02, 0.0)
	var start_rot := REST_ROT + Vector3(0.0, 0.0, sx * deg_to_rad(30.0))
	var end_pos   := REST_POS + Vector3(-sx * 0.40, 0.0, 0.0)
	var end_rot   := REST_ROT + Vector3(0.0, 0.0, sx * deg_to_rad(-58.0))
	_do_swing(end_pos, end_rot, 0.05, 0.08, start_pos, start_rot)

func _do_rising_slash(sx: float) -> void:
	var start_pos := REST_POS + Vector3(sx * 0.14, -0.14, 0.05)
	var start_rot := REST_ROT + Vector3(deg_to_rad(22.0), 0.0, sx * deg_to_rad(18.0))
	var end_pos   := REST_POS + Vector3(-sx * 0.18, 0.22, -0.04)
	var end_rot   := REST_ROT + Vector3(deg_to_rad(-54.0), 0.0, sx * deg_to_rad(-38.0))
	_do_swing(end_pos, end_rot, 0.06, 0.09, start_pos, start_rot)

func _do_slam_slash(sx: float) -> void:
	var start_pos := REST_POS + Vector3(sx * 0.08, 0.26, 0.06)
	var start_rot := REST_ROT + Vector3(deg_to_rad(44.0), 0.0, 0.0)
	var end_pos   := REST_POS + Vector3(-sx * 0.10, -0.12, -0.04)
	var end_rot   := REST_ROT + Vector3(deg_to_rad(-78.0), 0.0, sx * deg_to_rad(-22.0))
	_do_swing(end_pos, end_rot, 0.055, 0.09, start_pos, start_rot)

func _do_diagonal_slash(sx: float, sy: float) -> void:
	var start_pos := REST_POS + Vector3(sx * 0.18, -sy * 0.12, 0.02)
	var start_rot := REST_ROT + Vector3(-sy * deg_to_rad(16.0), 0.0, sx * deg_to_rad(22.0))
	var end_pos   := REST_POS + Vector3(-sx * 0.32, sy * 0.18, -0.02)
	var end_rot   := REST_ROT + Vector3(sy * deg_to_rad(-50.0), 0.0, sx * deg_to_rad(-52.0))
	_do_swing(end_pos, end_rot, 0.05, 0.08, start_pos, start_rot)

func _do_spin_finisher() -> void:
	_begin_attack()
	var my_id := _attack_id
	# Wind up: pull back-right and up
	var wind_pos  := REST_POS + Vector3(0.18, 0.20, 0.10)
	var wind_rot  := REST_ROT + Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(25.0))
	# Wide sweep across to far left
	var sweep_pos := REST_POS + Vector3(-0.48, 0.04, -0.04)
	var sweep_rot := REST_ROT + Vector3(deg_to_rad(-18.0), 0.0, deg_to_rad(-72.0))

	weapon_mesh.position = wind_pos
	weapon_mesh.rotation = wind_rot

	_current_tween = create_tween()
	_current_tween.tween_interval(0.07)
	_current_tween.tween_callback(func(): hitbox.monitoring = true)
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_current_tween.tween_property(weapon_mesh, "position", sweep_pos, 0.065)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", sweep_rot, 0.065)
	_current_tween.parallel().tween_property(hitbox, "position", sweep_pos, 0.065)
	_current_tween.tween_callback(func(): hitbox.monitoring = false; hitbox.position = Vector3.ZERO)
	_current_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(weapon_mesh, "position", REST_POS, 0.12)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", REST_ROT, 0.12)
	_current_tween.finished.connect(func(): _on_swing_done(my_id), CONNECT_ONE_SHOT)
	# Extra screen punch for spin finisher
	if player:
		if player.has_method("add_trauma"):
			player.add_trauma(0.20)

func _apply_lunge() -> void:
	if player == null:
		return
	_lunge_dir = -player.global_transform.basis.z
	_lunge_timer = lunge_duration

func _begin_attack() -> void:
	_attack_id += 1
	_hit_bodies.clear()
	if _current_tween:
		_current_tween.kill()
	is_attacking = true
	attack_cooldown = attack_cooldown_time
	if swing_sound:
		swing_sound.play()
	_apply_lunge()
	# FOV kick
	var cam := get_viewport().get_camera_3d()
	if cam:
		var ft := create_tween()
		ft.tween_property(cam, "fov", cam.fov + 7.0, 0.025).set_ease(Tween.EASE_OUT)
		ft.tween_property(cam, "fov", 90.0, 0.18).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Sword glow — acende no ataque
	if _sword_glow_mat:
		_sword_glow_mat.set_shader_parameter("emit_energy", 4.5)
	# Post-process aberração de ataque
	if has_node("/root/ScreenFX"):
		get_node("/root/ScreenFX").trigger_attack()

func _do_swing(end_pos: Vector3, end_rot: Vector3, t_out: float = 0.10, t_back: float = 0.22,
		start_pos: Vector3 = REST_POS, start_rot: Vector3 = REST_ROT) -> void:
	_begin_attack()
	var my_id := _attack_id

	hitbox.monitoring = true
	weapon_mesh.position = start_pos
	weapon_mesh.rotation = start_rot

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_current_tween.tween_property(weapon_mesh, "position", end_pos, t_out)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", end_rot, t_out)
	_current_tween.parallel().tween_property(hitbox, "position", end_pos, t_out)
	_current_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(weapon_mesh, "position", REST_POS, t_back)
	_current_tween.parallel().tween_property(weapon_mesh, "rotation", REST_ROT, t_back)
	_current_tween.finished.connect(func(): _on_swing_done(my_id), CONNECT_ONE_SHOT)

func _on_swing_done(attack_id: int) -> void:
	if attack_id != _attack_id:
		return
	hitbox.monitoring = false
	hitbox.position = Vector3.ZERO
	is_attacking = false
	_is_flick = false
	_hit_bodies.clear()
	spring_pos = REST_POS
	spring_vel = Vector3.ZERO
	# Fade sword glow back out
	if _sword_glow_mat:
		var gt := create_tween()
		gt.tween_method(func(v: float): _sword_glow_mat.set_shader_parameter("emit_energy", v),
			_sword_glow_mat.get_shader_parameter("emit_energy"), 0.0, 0.35)

func _on_hit(body: Node3D) -> void:
	if body == player:
		return
	if not body.is_in_group("enemies") or not body.has_method("take_hit"):
		return

	var direction := (body.global_position - global_position).normalized()
	direction.y = 0.0
	var kb := knockback_force
	var is_parry := false
	var is_kill: bool = "health" in body and body.health <= 1

	if player and player._dash_attack_window > 0.0:
		kb *= 2.0

	if "is_in_windup" in body and body.is_in_windup:
		is_parry = true
		kb *= 2.5
	elif "is_in_strike" in body and body.is_in_strike:
		kb *= 1.6

	body.take_hit(direction * kb)

	var impact_pos := body.global_position + Vector3(0.0, 0.8, 0.0)

	# Hit stop — parry > kill > normal
	var stop_t := hit_stop_parry if is_parry else (hit_stop_kill if is_kill else hit_stop_duration)
	_do_hit_stop(stop_t)

	# Sparks direcionais (saem do ponto de impacto na direção do golpe)
	_spawn_impact_sparks(impact_pos, direction, is_parry)

	# Anel de impacto se expandindo
	_spawn_impact_ring(impact_pos, is_parry)

	# Número flutuante de dano
	_spawn_hit_number(impact_pos, is_parry, is_kill)

	# Flash branco/dourado de tela
	var hud := get_tree().get_first_node_in_group("hud")
	if is_parry:
		if hud and hud.has_method("flash_parry"):
			hud.flash_parry()
		if has_node("/root/ScreenFX"):
			get_node("/root/ScreenFX").trigger_parry()
	else:
		if hud and hud.has_method("flash_hit"):
			hud.flash_hit(is_kill)

	# Recoil da arma — spring recua no eixo Z
	spring_vel.z += 4.5 if is_parry else 2.8

	if player:
		if player.has_method("camera_hit_punch"):
			player.camera_hit_punch(is_parry)
		# FOV punch adicional no momento do impacto
		var cam := get_viewport().get_camera_3d()
		if cam:
			var fov_kick := 14.0 if is_parry else 8.0
			var ft := create_tween()
			ft.tween_property(cam, "fov", cam.fov + fov_kick, 0.0)
			ft.tween_property(cam, "fov", 90.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		if player.has_method("add_combo_hit"):
			player.add_combo_hit(is_parry)
		if player.has_method("add_trauma"):
			player.add_trauma(0.55 if is_parry else (0.45 if is_kill else 0.32))

func _do_hit_stop(duration: float) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _spawn_impact_sparks(origin: Vector3, hit_dir: Vector3, is_parry: bool = false) -> void:
	var ps := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	# Sparks saem na direção do golpe + para cima
	mat.direction = (hit_dir + Vector3.UP * 0.6).normalized()
	mat.spread = 55.0
	mat.initial_velocity_min = 7.0
	mat.initial_velocity_max = 18.0
	mat.gravity = Vector3(0.0, -20.0, 0.0)
	mat.scale_min = 0.05
	mat.scale_max = 0.18
	mat.color = Color(0.5, 0.85, 1.0) if is_parry else Color(1.0, 0.92, 0.25)
	mat.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	ps.process_material = mat
	ps.amount = 28 if is_parry else 18
	ps.lifetime = 0.45
	ps.one_shot = true
	ps.explosiveness = 0.98
	ps.emitting = true
	get_tree().current_scene.add_child(ps)
	ps.global_position = origin
	ps.finished.connect(func(): if is_instance_valid(ps): ps.queue_free())
	get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(ps): ps.queue_free())

func _spawn_impact_ring(origin: Vector3, is_parry: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.05
	cyl.bottom_radius = 0.05
	cyl.height        = 0.04
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode         = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color         = Color(0.5, 0.9, 1.0, 0.9) if is_parry else Color(1.0, 0.95, 0.5, 0.9)
	mat.emission_enabled     = true
	mat.emission             = mat.albedo_color
	mat.emission_energy_multiplier = 3.0
	mat.cull_mode            = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = origin
	var target_r := 1.8 if is_parry else 1.1
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(target_r, 0.1, target_r), 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.18)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.chain().tween_callback(func(): if is_instance_valid(mi): mi.queue_free())

func _spawn_hit_number(origin: Vector3, is_parry: bool, is_kill: bool) -> void:
	var lbl := Label3D.new()
	if is_parry:
		lbl.text = "PARRY!"
		lbl.modulate = Color(0.4, 0.9, 1.0)
		lbl.font_size = 52
	elif is_kill:
		lbl.text = "KILL"
		lbl.modulate = Color(1.0, 0.4, 0.1)
		lbl.font_size = 46
	else:
		lbl.text = "1"
		lbl.modulate = Color(1.0, 0.95, 0.85)
		lbl.font_size = 38
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_tree().current_scene.add_child(lbl)
	lbl.global_position = origin
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", origin.y + 1.2, 0.55)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(lbl, "modulate:a", 0.0, 0.55)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(0.2)
	t.chain().tween_callback(func(): if is_instance_valid(lbl): lbl.queue_free())
