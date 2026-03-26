extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const GRAVITY = 9.8
const ARENA_RADIUS: float = 20.8  # wall_radius(21) - margem do jogador
const _PAUSE_SCENE = preload("res://scenes/ui/pause.tscn")

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

# ─── Multiplayer ──────────────────────────────────────────────────────────────
var _net_sync_timer := 0.0
var _net_target_pos := Vector3.ZERO
var _net_target_rot_y := 0.0
var _net_target_head_x := 0.0
var _ghost_particle_mats: Array = []  # materiais das partículas do ghost (só não-authority)

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
var _air_jumps_left: int = 1

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
	# Remove o nó Player pré-colocado sem dono real (authority 1 = servidor sem player).
	# Aplica no servidor dedicado E nos clientes conectados a ele.
	# Em listen-server o host (peer 1) É um jogador real — não remove.
	if get_multiplayer_authority() == 1 and NetworkManager.is_multiplayer_session:
		if NetworkManager.is_dedicated_server or not multiplayer.is_server():
			queue_free()
			return
	add_to_group("player")
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# Jogador remoto — desativa câmera e input
		camera.current = false
		set_process_unhandled_input(false)
		_spawn_ghost_body()
	head_base_y = head.position.y
	health = max_health
	if is_multiplayer_authority():
		_notify_hud_health(false)
	if is_multiplayer_authority() and default_weapon_scene:
		equip_weapon("Default", default_weapon_scene.instantiate())

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.0, PI / 2.0)
	if event.is_action_pressed("pause"):
		if not get_tree().paused:
			get_tree().paused = true
			get_tree().current_scene.add_child(_PAUSE_SCENE.instantiate())
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
	# Jogador remoto: apenas interpola para a posição recebida
	if not is_multiplayer_authority():
		global_position = global_position.lerp(_net_target_pos, delta * 12.0)
		rotation.y = lerp_angle(rotation.y, _net_target_rot_y, delta * 12.0)
		head.rotation.x = lerp_angle(head.rotation.x, _net_target_head_x, delta * 12.0)
		return

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
		_air_jumps_left = 1
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
	elif _jump_buffer_timer > 0.0 and not can_jump and _air_jumps_left > 0:
		velocity.y = JUMP_VELOCITY * 0.97
		_jump_buffer_timer = 0.0
		_air_jumps_left -= 1
		_vx -= jump_kick * 0.95
		_spawn_double_jump_fx()

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

	# Sync de posição para outros jogadores em multiplayer
	if NetworkManager.is_multiplayer_session:
		_net_sync_timer -= delta
		if _net_sync_timer <= 0.0:
			_net_sync_timer = 0.05  # 20 Hz
			rpc("_net_receive_state", global_position, rotation.y, head.rotation.x, float(health) / float(max_health))

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
		var dash_target := streak.global_position + _dash_dir
		if (_dash_dir + offset.normalized()).length() > 0.01 and dash_target.is_finite():
			var up := Vector3.RIGHT if abs(_dash_dir.dot(Vector3.UP)) > 0.9 else Vector3.UP
			streak.look_at(dash_target, up)
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

func _spawn_double_jump_fx() -> void:
	# Anel de ar expandindo nos pés
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.05
	cyl.bottom_radius = 0.05
	cyl.height        = 0.04
	ring.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.15, 0.0)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(2.2, 0.06, 2.2), 0.22)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22)\
		.set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func(): if is_instance_valid(ring): ring.queue_free())

	# Burst de partículas para baixo
	var ps := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 60.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0.0, -12.0, 0.0)
	pm.scale_min = 0.04
	pm.scale_max = 0.14
	pm.color = Color(0.5, 0.85, 1.0, 0.9)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	ps.process_material = pm
	ps.amount = 20
	ps.lifetime = 0.4
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.emitting = true
	get_tree().current_scene.add_child(ps)
	ps.global_position = global_position + Vector3(0.0, 0.2, 0.0)
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

# ─── RPCs de Multiplayer ──────────────────────────────────────────────────────

# Recebe posição do peer dono deste nó (unreliable — não importa perda de pacote)
@rpc("any_peer", "unreliable_ordered")
func _net_receive_state(pos: Vector3, rot_y: float, head_x: float, health_ratio: float) -> void:
	if is_multiplayer_authority():
		return
	_net_target_pos = pos
	_net_target_rot_y = rot_y
	_net_target_head_x = head_x
	_update_ghost_color(health_ratio)

# Chamado pelo servidor para aplicar dano num peer específico
@rpc("any_peer", "reliable")
func rpc_take_damage(amount: int, knockback: Vector3) -> void:
	if not is_multiplayer_authority():
		return  # só o dono processa o próprio dano
	take_damage(amount, knockback)

# Chamado pelo servidor para adicionar moedas a um peer específico
@rpc("any_peer", "reliable")
func rpc_add_coins(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	add_coins(amount)

# Chamado pelo servidor para curar um peer específico
@rpc("any_peer", "reliable")
func rpc_heal(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	heal(amount)

# Chamado pelo servidor para combo kill em peer específico
@rpc("any_peer", "reliable")
func rpc_add_combo_kill() -> void:
	if not is_multiplayer_authority():
		return
	add_combo_kill()

func _spawn_ghost_body() -> void:
	var ghost := Node3D.new()
	ghost.name = "GhostBody"
	add_child(ghost)

	var shader := load("res://shaders/ghost_player.gdshader") as Shader
	var color  := Color(0.35, 0.8, 1.0)
	var head_y := head.position.y

	# Névoa em três camadas: pés / torso / cabeça
	# Cada emitter ocupa uma esfera de volume — partículas derivam em todas as direções
	# [pos_y, emit_radius, scale_min, scale_max, amount, alpha]
	var layers := [
		[0.25,          0.32, 1.20, 2.80, 160, 0.28],   # pés
		[head_y * 0.52, 0.34, 1.00, 2.40, 180, 0.24],   # torso
		[head_y + 0.08, 0.24, 0.80, 1.80, 120, 0.22],   # cabeça
	]
	var smoke_tex := _make_smoke_texture()
	for layer in layers:
		var emitter := _make_mist_emitter(color, smoke_tex, layer[0], layer[1],
				layer[2], layer[3], layer[4], layer[5])
		ghost.add_child(emitter)
		# guarda referência ao material para recolorir via health
		var quad := emitter.draw_pass_1 as QuadMesh
		if quad and quad.material:
			_ghost_particle_mats.append(quad.material)

	# Arma — modelo real com ghost shader aplicado recursivamente
	if default_weapon_scene != null:
		var weapon := default_weapon_scene.instantiate() as Node3D
		weapon.position = Vector3(0.38, head_y - 0.15, -0.05)
		weapon.rotation = Vector3(0.3, 0.0, -0.42)
		weapon.scale    = Vector3.ONE * 0.9
		ghost.add_child(weapon)
		_apply_ghost_shader(weapon, shader, Color(0.55, 0.88, 1.0), 3.5, 1.8)

	# Pulso de escala suave
	var pulse := ghost.create_tween().set_loops()
	pulse.tween_property(ghost, "scale", Vector3.ONE * 1.05, 1.4)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ghost, "scale", Vector3.ONE * 0.96, 1.4)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _update_ghost_color(ratio: float) -> void:
	if _ghost_particle_mats.is_empty():
		return
	# cyan (cheio) → amarelo (meio) → vermelho (quase morto)
	var c: Color
	if ratio > 0.5:
		c = Color(0.35, 0.8, 1.0).lerp(Color(0.95, 0.80, 0.1), (1.0 - ratio) * 2.0)
	else:
		c = Color(0.95, 0.80, 0.1).lerp(Color(1.0, 0.08, 0.05), (0.5 - ratio) * 2.0)
	for mat in _ghost_particle_mats:
		var m := mat as StandardMaterial3D
		if m:
			m.albedo_color = Color(c.r, c.g, c.b, m.albedo_color.a)


func _make_mist_emitter(color: Color, smoke_tex: ImageTexture, pos_y: float, emit_r: float,
		sc_min: float, sc_max: float, amount: int, alpha: float) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()

	pm.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = emit_r
	pm.direction              = Vector3.UP
	pm.spread                 = 180.0
	pm.initial_velocity_min   = 0.02
	pm.initial_velocity_max   = 0.28
	pm.gravity                = Vector3(0.0, 0.04, 0.0)
	pm.scale_min              = sc_min
	pm.scale_max              = sc_max
	pm.color                  = Color(color.r, color.g, color.b, alpha)

	var grad := Gradient.new()
	grad.colors  = PackedColorArray([Color(1,1,1,0), Color(1,1,1,1), Color(1,1,1,0)])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = grad
	pm.color_ramp     = ramp_tex
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED

	# QuadMesh billboard com textura de puff — não mais esfera sólida
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode                = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode            = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color              = Color(color.r, color.g, color.b, 1.0)
	mat.albedo_texture            = smoke_tex
	mat.cull_mode                 = BaseMaterial3D.CULL_DISABLED
	quad.material                 = mat

	ps.draw_pass_1  = quad
	ps.draw_passes  = 1
	ps.process_material = pm
	ps.amount        = amount
	ps.lifetime      = 1.8
	ps.randomness    = 1.0
	ps.local_coords  = false  # partículas ficam no mundo — trail
	ps.emitting      = true
	ps.position      = Vector3(0.0, pos_y, 0.0)
	return ps


func _make_smoke_texture() -> ImageTexture:
	var size := 64
	var img  := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Vários blobs suaves sobrepostos — forma de puff irregular
	var blobs := [
		[Vector2(0.50, 0.50), 0.34, 0.65],
		[Vector2(0.36, 0.44), 0.20, 0.38],
		[Vector2(0.64, 0.47), 0.19, 0.34],
		[Vector2(0.50, 0.33), 0.17, 0.30],
		[Vector2(0.48, 0.65), 0.18, 0.32],
		[Vector2(0.28, 0.58), 0.13, 0.22],
		[Vector2(0.70, 0.60), 0.14, 0.24],
	]
	for y in size:
		for x in size:
			var uv := Vector2(float(x) / size, float(y) / size)
			var a  := 0.0
			for blob in blobs:
				var d: float = uv.distance_to(blob[0] as Vector2) / (blob[1] as float)
				a += (blob[2] as float) * maxf(0.0, 1.0 - d * d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _apply_ghost_shader(node: Node, shader: Shader, color: Color, rim_pow: float, energy: float) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _make_ghost_shader_mat(shader, color, rim_pow, energy)
	for child in node.get_children():
		_apply_ghost_shader(child, shader, color, rim_pow, energy)


func _make_ghost_shader_mat(shader: Shader, color: Color, rim_pow: float, energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("ghost_color",  color)
	mat.set_shader_parameter("rim_power",    rim_pow)
	mat.set_shader_parameter("rim_energy",   energy)
	mat.set_shader_parameter("drift_speed",  0.6)
	return mat


func _make_ghost_simple_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


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
	if NetworkManager.is_multiplayer_session:
		# Desativa movimento mas permanece no mundo para outros jogadores
		set_physics_process(false)
		set_process_unhandled_input(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		NetworkManager.close()
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

## Retorna o script da arma equipada (weapon_pivot ou seu primeiro filho)
func _get_weapon_script() -> Node:
	if weapon_pivot == null:
		return null
	if weapon_pivot.get_script() != null:
		return weapon_pivot
	if weapon_pivot.get_child_count() > 0:
		return weapon_pivot.get_child(0)
	return null

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
			var sword := _get_weapon_script()
			if sword and "attack_cooldown_time" in sword:
				sword.attack_cooldown_time = maxf(0.05, sword.attack_cooldown_time * 0.85)
		"knockback":
			var sword := _get_weapon_script()
			if sword and "knockback_force" in sword:
				sword.knockback_force *= 1.25
		"dash_cd":
			dash_cooldown_time = maxf(0.15, dash_cooldown_time - 0.12)
		"iframes":
			invincibility_time += 0.3
		"lunge":
			var sword := _get_weapon_script()
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
