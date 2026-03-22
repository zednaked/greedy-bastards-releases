extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const GRAVITY = 9.8
const ARENA_RADIUS: float = 20.8  # wall_radius(21) - margem do jogador

@export_group("Head Bob")
@export var bob_freq: float = 2.2
@export var bob_amp_y: float = 0.10
@export var bob_amp_x: float = 0.06
@export var bob_roll: float = 0.05

@export_group("Camera Reactions")
@export var cam_spring: float = 18.0
@export var cam_damp: float = 0.45
@export var strafe_lean: float = 0.012   # roll ao strafar
@export var forward_lean: float = 0.005  # pitch ao acelerar/frear
@export var jump_kick: float = 2.2       # impulso de pitch ao pular
@export var land_pos_scale: float = 0.015 # queda em Y ao aterrissar
@export var land_rx_scale: float = 0.08  # nod frontal ao aterrissar

@export var default_weapon_scene: PackedScene

@export_group("Saúde")
@export var max_health: int = 5
@export var invincibility_time: float = 0.8

@export_group("Movement Feel")
@export var accel_ground: float = 60.0
@export var decel_ground: float = 40.0
@export var accel_air: float = 18.0
@export var decel_air: float = 6.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Hit Feedback")
@export var hit_punch_z: float = 0.035
@export var hit_punch_rx: float = 0.06
@export var parry_punch_rx: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.18
@export var dash_cooldown_time: float = 0.7
@export var double_tap_window: float = 0.25
@export var dash_roll: float = 2.5       # impulso de roll ao dashar
@export var dash_pitch: float = 1.2      # impulso de pitch ao dashar

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_pivot: Node3D = $Head/WeaponPivot
@onready var sword_mesh: Node3D = $Head/WeaponPivot/SwordMesh

var equipped_weapon: String = ""
var bob_t := 0.0
var head_base_y: float

var health: int
var _invincible_timer := 0.0

# Camera spring state
var _rx := 0.0   # pitch offset
var _rz := 0.0   # roll offset
var _vx := 0.0
var _vz := 0.0

# Land state
var _land_offset := 0.0
var _was_on_floor := true
var _fall_vel := 0.0

# Screen shake
var _trauma := 0.0

# Camera Z-punch (hit feedback)
var _cam_punch_z: float = 0.0
var _cam_punch_vz: float = 0.0

# Coyote & jump buffer
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

# Combo
var _combo: int = 0
var _combo_decay_timer: float = 0.0
const COMBO_DECAY_TIME: float = 3.0

# Economy
var coins: int = 0
var coin_collect_radius: float = 1.5  # upgraded by "magnet"

# Dash state
var _dash_dir := Vector3.ZERO
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_attack_window := 0.0
var _last_dir_action := ""
var _last_dir_time := -999.0

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	head_base_y = head.position.y
	health = max_health
	_notify_hud_health(false)
	if default_weapon_scene:
		equip_weapon("Default", default_weapon_scene.instantiate())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.0, PI / 2.0)
	if event.is_action_pressed("pause"):
		if not get_tree().paused:
			get_tree().paused = true
			var pause_scene := load("res://scenes/ui/pause.tscn") as PackedScene
			get_tree().current_scene.add_child(pause_scene.instantiate())
		return

	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			var now := Time.get_ticks_msec() * 0.001
			if action == _last_dir_action and now - _last_dir_time <= double_tap_window and _dash_cooldown <= 0.0:
				_start_dash(action)
			_last_dir_action = action
			_last_dir_time = now
			break

func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)
	_trauma = maxf(0.0, _trauma - delta * 2.2)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_dash_attack_window = maxf(0.0, _dash_attack_window - delta)
	if _combo > 0:
		_combo_decay_timer = maxf(0.0, _combo_decay_timer - delta)
		if _combo_decay_timer <= 0.0:
			_combo = 0
			_notify_hud_combo()

	if not is_on_floor():
		_fall_vel = velocity.y
		velocity.y -= GRAVITY * delta

	# Land detection — impulso proporcional à queda
	if is_on_floor() and not _was_on_floor:
		var impact := clampf(-_fall_vel, 0.0, 15.0)
		_land_offset = impact * land_pos_scale
		_vx += impact * land_rx_scale

	# Coyote time — permite pular brevemente após sair de plataforma
	if _was_on_floor and not is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_was_on_floor = is_on_floor()

	# Jump buffer — consome o pulo quando possível
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_vx -= jump_kick
		_land_offset += 0.04

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var on_floor := is_on_floor()
		var accel := accel_ground if on_floor else accel_air
		var decel := decel_ground if on_floor else decel_air
		var flat_vel := Vector3(velocity.x, 0.0, velocity.z)
		if direction.length() > 0.01:
			flat_vel = flat_vel.move_toward(direction * SPEED, accel * delta)
		else:
			flat_vel = flat_vel.move_toward(Vector3.ZERO, decel * delta)
		velocity.x = flat_vel.x
		velocity.z = flat_vel.z

	move_and_slide()

	# Clamp dentro da arena
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > ARENA_RADIUS:
		flat = flat.normalized() * ARENA_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y

	_update_camera(delta)

func _start_dash(action: String) -> void:
	var dir := Vector3.ZERO
	match action:
		"move_forward": dir = -transform.basis.z
		"move_back":    dir = transform.basis.z
		"move_left":    dir = -transform.basis.x
		"move_right":   dir = transform.basis.x
	_dash_dir = dir.normalized()
	_dash_timer = dash_duration
	_dash_cooldown = dash_cooldown_time
	_dash_attack_window = 0.2

	# Impulso de câmera na direção do dash
	var local_d := global_transform.basis.inverse() * _dash_dir
	_vz -= local_d.x * dash_roll * 2.2   # lean mais dramático
	_vx += local_d.z * dash_pitch * 1.8

	# FOV: snap instantâneo para 118° — sensação de aceleração brusca — depois lerp suave de volta
	var fov_tween := create_tween()
	fov_tween.tween_property(camera, "fov", 118.0, 0.0)
	fov_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	fov_tween.tween_property(camera, "fov", 90.0, dash_duration + 0.45)

	# Vignette escuro — visão de túnel durante o burst
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_dash"):
		hud.flash_dash()

	# Impacto físico: trauma + punch de câmera pra frente
	add_trauma(0.28)
	_cam_punch_z -= 0.055
	_cam_punch_vz = -0.9

	# Efeitos visuais de velocidade
	_spawn_dash_streaks()
	_spawn_dash_dust()

func _spawn_dash_streaks() -> void:
	var scene := get_tree().current_scene
	var perp := _dash_dir.cross(Vector3.UP).normalized()
	for i in 5:
		var streak := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.018, randf_range(0.55, 1.3))
		streak.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.72, 0.88, 1.0, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.7, 1.0)
		mat.emission_energy_multiplier = 1.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		streak.material_override = mat
		scene.add_child(streak)
		var offset := perp * randf_range(-0.75, 0.75) + Vector3.UP * randf_range(0.4, 1.5)
		streak.global_position = global_position + offset
		if (_dash_dir + offset.normalized()).length() > 0.01:
			streak.look_at(streak.global_position + _dash_dir, Vector3.UP)
		var fly_dist := randf_range(2.5, 5.5)
		var fly_dur := randf_range(0.13, 0.22)
		var t := streak.create_tween().set_parallel(true)
		t.tween_property(streak, "global_position",
				streak.global_position - _dash_dir * fly_dist, fly_dur)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		t.tween_property(mat, "albedo_color:a", 0.0, fly_dur + 0.04)
		t.chain().tween_callback(func(): if is_instance_valid(streak): streak.queue_free())

func _spawn_dash_dust() -> void:
	var ps := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	var emit_dir := (-_dash_dir + Vector3.UP * 0.4).normalized()
	pm.direction = emit_dir
	pm.spread = 50.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0.0, -6.0, 0.0)
	pm.scale_min = 0.06
	pm.scale_max = 0.22
	pm.color = Color(0.78, 0.72, 0.62, 0.85)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	ps.process_material = pm
	ps.amount = 22
	ps.lifetime = 0.55
	ps.one_shot = true
	ps.explosiveness = 0.92
	ps.emitting = true
	get_tree().current_scene.add_child(ps)
	ps.global_position = global_position + Vector3(0.0, 0.12, 0.0)
	ps.finished.connect(func(): if is_instance_valid(ps): ps.queue_free())

func _update_camera(delta: float) -> void:
	# --- Land offset decay ---
	_land_offset = lerpf(_land_offset, 0.0, delta * 16.0)

	# --- Lean contínuo baseado em velocidade local ---
	var lv := global_transform.basis.inverse() * velocity
	var target_rx := -lv.z * forward_lean   # frear = nod pra frente, acelerar = cabeca pra trás
	var target_rz := -lv.x * strafe_lean    # strafe = roll lateral

	# Spring-damper
	_vx += (target_rx - _rx) * cam_spring * delta
	_vx *= pow(cam_damp, delta * 60.0)
	_rx += _vx * delta

	_vz += (target_rz - _rz) * cam_spring * delta
	_vz *= pow(cam_damp, delta * 60.0)
	_rz += _vz * delta

	# --- Bob ---
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		bob_t += delta * hspeed
		var bob_y := sin(bob_t * bob_freq) * bob_amp_y
		var bob_x := sin(bob_t * bob_freq * 0.5) * bob_amp_x
		head.position.y = head_base_y + bob_y - _land_offset
		head.position.x = bob_x
		camera.rotation.z = (-bob_x / bob_amp_x * bob_roll) + _rz
	else:
		head.position.y = lerpf(head.position.y, head_base_y - _land_offset, delta * 10.0)
		head.position.x = lerpf(head.position.x, 0.0, delta * 10.0)
		camera.rotation.z = lerpf(camera.rotation.z, _rz, delta * 10.0)

	camera.rotation.x = _rx
	camera.position.x = 0.0
	camera.position.y = 0.0

	# Screen shake
	var shake := _trauma * _trauma
	if shake > 0.001:
		var st := Time.get_ticks_msec() * 0.001
		camera.rotation.x += sin(st * 47.0) * shake * 0.05
		camera.rotation.y += sin(st * 31.0) * shake * 0.05
		camera.position.x = sin(st * 53.0) * shake * 0.025
		camera.position.y = sin(st * 41.0) * shake * 0.025

	# Camera Z-punch — spring de retorno ao centro
	_cam_punch_vz += (0.0 - _cam_punch_z) * 28.0 * delta
	_cam_punch_vz  *= pow(0.35, delta * 60.0)
	_cam_punch_z   += _cam_punch_vz * delta
	camera.position.z = _cam_punch_z

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func camera_hit_punch(is_parry: bool = false) -> void:
	_cam_punch_z = -hit_punch_z
	_vx += parry_punch_rx if is_parry else hit_punch_rx

func take_damage(amount: int, knockback: Vector3 = Vector3.ZERO) -> void:
	if _invincible_timer > 0.0:
		return
	var unarmed: bool = not weapon_pivot.get("has_weapon")
	var unarmed_mult: float = 1.5 if (unarmed and get_meta("armor_unlocked", false)) else (2.0 if unarmed else 1.0)
	health -= int(amount * unarmed_mult)
	_invincible_timer = 0.1 if unarmed else invincibility_time
	add_trauma(0.65 if unarmed else 0.45)
	if knockback != Vector3.ZERO:
		velocity.x += knockback.x
		velocity.z += knockback.z
		velocity.y = clampf(velocity.y + knockback.y, 0.0, 4.0)
	# Reset combo on taking damage
	_combo = 0
	_combo_decay_timer = 0.0
	_notify_hud_combo()
	_notify_hud_health()
	if health <= 0:
		_die()

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	_notify_hud_health(false)

func _die() -> void:
	Engine.time_scale = 1.0  # garante restauração se morrer durante hit stop
	var kills: int = 0
	var wave: int = 0
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and "kills" in hud:
		kills = hud.kills
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and "_wave" in spawner:
		wave = spawner._wave
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.kills = kills
		gm.wave = wave
		gm.coins = coins
	get_tree().change_scene_to_file("res://scenes/ui/defeat.tscn")

func _notify_hud_health(flash: bool = true) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_health"):
		hud.set_health(health, max_health, flash)

func add_combo_hit(is_parry: bool = false) -> void:
	_combo += 2 if is_parry else 1
	_combo_decay_timer = COMBO_DECAY_TIME
	_notify_hud_combo()

func add_combo_kill() -> void:
	_combo += 1
	_combo_decay_timer = COMBO_DECAY_TIME
	# Bloodlust: cura 1 HP ao matar com combo >= threshold
	var bloodlust_threshold: int = 2 if get_meta("bloodlust_unlocked", false) else 4
	if _combo >= bloodlust_threshold and health < max_health:
		health = mini(health + 1, max_health)
		_notify_hud_health(false)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("flash_gold_vignette"):
			hud.flash_gold_vignette()
	_notify_hud_combo()

func _notify_hud_combo() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_combo"):
		hud.set_combo(_combo)

func equip_weapon(weapon_name: String, weapon_node: Node3D = null) -> void:
	equipped_weapon = weapon_name
	for child in sword_mesh.get_children():
		child.queue_free()
	if weapon_node:
		if weapon_node.get_parent():
			weapon_node.reparent(sword_mesh)
		else:
			sword_mesh.add_child(weapon_node)
		weapon_node.position = Vector3.ZERO
		weapon_node.rotation = Vector3.ZERO

func is_in_dash_attack_window() -> bool:
	return _dash_attack_window > 0.0

func add_coins(amount: int) -> void:
	coins += amount
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_coins"):
		hud.set_coins(coins)

func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"heal":
			health = mini(health + 2, max_health)
			_notify_hud_health(false)
		"max_hp":
			max_health += 1
			health = max_health
			_notify_hud_health(false)
		"atk_speed":
			# Reduce sword attack cooldown — weapon_pivot holds the sword_attack script
			if weapon_pivot and "attack_cooldown_time" in weapon_pivot:
				weapon_pivot.attack_cooldown_time = maxf(0.05, weapon_pivot.attack_cooldown_time * 0.85)
			else:
				# Try first child of weapon_pivot
				var sword := weapon_pivot.get_child(0) if weapon_pivot.get_child_count() > 0 else null
				if sword and "attack_cooldown_time" in sword:
					sword.attack_cooldown_time = maxf(0.05, sword.attack_cooldown_time * 0.85)
		"knockback":
			if weapon_pivot and "knockback_force" in weapon_pivot:
				weapon_pivot.knockback_force *= 1.25
			else:
				var sword := weapon_pivot.get_child(0) if weapon_pivot.get_child_count() > 0 else null
				if sword and "knockback_force" in sword:
					sword.knockback_force *= 1.25
		"dash_cd":
			dash_cooldown_time = maxf(0.15, dash_cooldown_time - 0.12)
		"iframes":
			invincibility_time += 0.3
		"lunge":
			if weapon_pivot and "lunge_force" in weapon_pivot:
				weapon_pivot.lunge_force += 3.0
			else:
				var sword := weapon_pivot.get_child(0) if weapon_pivot.get_child_count() > 0 else null
				if sword and "lunge_force" in sword:
					sword.lunge_force += 3.0
		"bloodlust":
			set_meta("bloodlust_unlocked", true)
		"magnet":
			coin_collect_radius = 4.5
			# Update all existing coins in scene
			for coin in get_tree().get_nodes_in_group("coins"):
				if coin.has_method("set_collect_radius"):
					coin.set_collect_radius(coin_collect_radius)
		"armor":
			set_meta("armor_unlocked", true)
