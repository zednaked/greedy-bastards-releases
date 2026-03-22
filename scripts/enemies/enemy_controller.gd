extends CharacterBody3D
class_name EnemyController

@export var speed: float = 3.5
@export var stopping_distance: float = 1.8
@export var max_health: int = 3
@export var knockback_duration: float = 0.45

@export_group("Ataque")
@export var attack_range: float = 1.8
@export var attack_damage: int = 1
@export var attack_cooldown_time: float = 1.5
@export var attack_windup: float = 0.35
@export var attack_lunge: float = 0.4
@export var attack_knockback: float = 3.0
@export var projectile_scene: PackedScene
@export var bomb_scene: PackedScene
@export var trap_scene: PackedScene

@export_group("Animação Esqueletal")
@export var walk_leg_swing: float = 0.55
@export var walk_knee_bend: float = 0.50
@export var walk_arm_swing: float = 0.40
@export var walk_spine_lean: float = 0.22
@export var walk_spine_sway: float = 0.07
@export var walk_freq: float = 8.0
@export var idle_breathe: float = 0.04

@onready var goblin_mesh: Node3D = $GoblinMesh

# ─── Sistema A — Token System ─────────────────────────────────────────────────
static var _active_attackers: int = 0
static var MAX_ACTIVE_ATTACKERS: int = 2
var _holds_attack_token: bool = false

static func reset_token_pool() -> void:
	_active_attackers = 0
	MAX_ACTIVE_ATTACKERS = 2
	_wave_has_leader = false
	_flank_slots.clear()
	_howl_global_cooldown = 0.0

# Sistema S + X: notificações estáticas (chamadas por instâncias, afetam todas)
static func on_ally_death(origin: Vector3) -> void:
	for e in _enemy_cache:
		if not is_instance_valid(e): continue
		var ec := e as EnemyController
		if ec == null or ec.is_dead: continue
		if ec.global_position.distance_to(origin) < 10.0:
			ec._trigger_rage()

static func notify_player_attacked(origin: Vector3) -> void:
	for e in _enemy_cache:
		if not is_instance_valid(e): continue
		var ec := e as EnemyController
		if ec == null or ec.is_dead: continue
		if ec.global_position.distance_to(origin) < 8.0:
			ec._opportunism_timer = 3.0

static func on_leader_death(origin: Vector3) -> void:
	for e in _enemy_cache:
		if not is_instance_valid(e): continue
		var ec := e as EnemyController
		if ec == null or ec.is_dead: continue
		if ec.global_position.distance_to(origin) < 12.0:
			# Wave 4+: rage; earlier: cower
			if _enemy_cache.size() >= 4:
				ec._trigger_rage()
			else:
				ec._start_cower()
	_wave_has_leader = false

# ─── Sistema B — Circling ─────────────────────────────────────────────────────
var _circle_dir: float = 1.0
var circle_speed_factor: float = 0.65

# ─── Sistema E — Two Attack Types ────────────────────────────────────────────
var _time_since_last_attack: float = 0.0
var heavy_slam_windup: float = 0.6
var heavy_slam_knockback: float = 7.0

# ─── Sistema I — Stumble ─────────────────────────────────────────────────────
var is_stumbling: bool = false
var stumble_duration: float = 0.4
var stumble_speed_factor: float = 0.4
var stumble_threshold: float = 20.0
var _stumble_timer: float = 0.0

# ─── Sistema J — Low Health Retreat ──────────────────────────────────────────
var is_retreating: bool = false
var _retreat_timer: float = 0.0
var retreat_move_factor: float = 0.75

# ─── Sistema K — Charge Attack ────────────────────────────────────────────────
var is_charging: bool = false
var _charge_timer: float = 0.0
var charge_duration: float = 0.45
var charge_speed_mult: float = 2.5
var charge_knockback: float = 5.5
var _circling_time: float = 0.0

# ─── Sistema L — Taunt / Speech ───────────────────────────────────────────────
const _SPEECH_DB: Dictionary = {
	"berserk":         ["SÓ EU CONTRA TODOS!!!", "NÃO VOU FUGIR!", "VENHA, COVARDE!!!", "VOCÊS NÃO ME PEGAM!!!"],
	"rage":            ["VINGANÇA!!!", "POR MEU CAMARADA!!!", "VOCÊ VAI PAGAR!!!", "AAARRR!!!"],
	"player_low":      ["quase... quase...", "agonizando! hehehe!", "só mais um pouquinho!", "tá fraco!"],
	"outnumber":       ["somos muitos!", "não tem escapatória!", "cerquem ele!", "você tá rodeado!"],
	"leader":          ["eu comando aqui!", "sigam-me!!!", "pela horda!", "atacar!!!"],
	"idle":            ["huehuehue!", "vem cá, covarde!", "prepare-se!", "foge não!", "eheheheh!", "você vai morrer!"],
	"howl":            ["AAAAOOOO!!!", "AAAAAUUUU!!!", "OWWWWL!!!"],
	"block":           ["bloqueei!", "que tentativa!", "fácil!", "errou!"],
	"guard_break":     ["argh!", "ui!", "ow!"],
	"howl_cancel":     ["au!", "ow!", "para!"],
	"cower":           ["não! não!", "ui ui ui!", "para!", "misericórdia!"],
	"berserk_trigger": ["EU SOU O ÚLTIMO!!!", "ATÉ O FIM!!!", "MORRA!!!"],
}
const _SPEECH_STYLE: Dictionary = {
	"berserk":         {"color": Color(1.0, 0.10, 0.05), "size": 42, "dur": [1.8, 2.5]},
	"rage":            {"color": Color(1.0, 0.20, 0.10), "size": 40, "dur": [1.2, 1.8]},
	"player_low":      {"color": Color(1.0, 0.85, 0.20), "size": 34, "dur": [1.5, 2.2]},
	"outnumber":       {"color": Color(1.0, 0.85, 0.20), "size": 34, "dur": [1.5, 2.0]},
	"leader":          {"color": Color(1.0, 0.80, 0.10), "size": 36, "dur": [1.5, 2.0]},
	"idle":            {"color": Color(1.0, 0.92, 0.20), "size": 32, "dur": [1.2, 2.0]},
	"howl":            {"color": Color(1.0, 0.30, 0.10), "size": 44, "dur": [1.0, 1.4]},
	"block":           {"color": Color(0.8, 0.80, 1.00), "size": 30, "dur": [0.5, 0.8]},
	"guard_break":     {"color": Color(1.0, 0.50, 0.20), "size": 28, "dur": [0.4, 0.6]},
	"howl_cancel":     {"color": Color(0.7, 1.00, 0.70), "size": 28, "dur": [0.5, 0.7]},
	"cower":           {"color": Color(0.75, 0.75, 1.0), "size": 30, "dur": [0.8, 1.2]},
	"berserk_trigger": {"color": Color(1.0, 0.10, 0.05), "size": 46, "dur": [2.0, 2.5]},
}
var is_taunting: bool = false
var _taunt_timer: float = 0.0
var _taunt_cooldown: float = 0.0

# ─── Sistema Q — Throw / Kite ─────────────────────────────────────────────────
@export var is_ranged: bool = false
@export var is_bomber: bool = false
@export var is_trapper: bool = false
@export var throw_range_min: float = 7.0
@export var throw_range_max: float = 16.0
@export var throw_damage: int = 1
@export var throw_speed: float = 13.0
@export var kite_retreat_range: float = 5.5
var is_throwing: bool = false
var _throw_cooldown: float = 0.0

# ─── Sistema R — Feint ────────────────────────────────────────────────────────
var is_feinting: bool = false

# ─── Sistema S — Rage (morte de aliado) ──────────────────────────────────────
var _is_raging: bool = false
var _rage_timer: float = 0.0
var _rage_mat: StandardMaterial3D = null

# ─── Sistema T — Cower (medo pós-parry) ──────────────────────────────────────
var is_cowering: bool = false
var _cower_timer: float = 0.0

# ─── Sistema U — Zigzag Approach ─────────────────────────────────────────────
var _zigzag_phase: float = 0.0
var _zigzag_freq: float = 2.0
var _zigzag_amp: float = 0.5

# ─── Sistema V — Last One Berserk ────────────────────────────────────────────
var _is_berserk: bool = false

# ─── Sistema W — Recovering (pós-knockback) ──────────────────────────────────
var is_recovering: bool = false
var _recovery_timer: float = 0.0

# ─── Sistema X — Mob Awareness ───────────────────────────────────────────────
var _opportunism_timer: float = 0.0

# ─── Sistema Y — Jump Attack ─────────────────────────────────────────────────
var is_jumping: bool = false
var _jump_hit_done: bool = false
var _jump_cooldown: float = 0.0

# ─── Sistema Z — Guard Stance ─────────────────────────────────────────────────
var is_blocking_stance: bool = false
var _guard_timer: float = 0.0
var _guard_cooldown: float = 0.0

# ─── Sistema AA — Pack Leader ─────────────────────────────────────────────────
var is_leader: bool = false
var _leader_mat: StandardMaterial3D = null
static var _wave_has_leader: bool = false

# ─── Sistema AB — War Howl ────────────────────────────────────────────────────
var is_howling: bool = false
var _howl_timer: float = 0.0
static var _howl_global_cooldown: float = 0.0

# ─── Sistema AF — Shove on Contact ───────────────────────────────────────────
var _shove_cooldown: float = 0.0

# ─── Sistema AG — Coordinated Flanking ───────────────────────────────────────
static var _flank_slots: Dictionary = {}
static var _flank_timer: float = 0.0

# ─── Bomber ───────────────────────────────────────────────────────────────────
var _bomb_cooldown: float = 0.0

# ─── Trapper ──────────────────────────────────────────────────────────────────
var _trap_cooldown: float = 0.0
var _trapper_visible_timer: float = 0.0
var _trapper_mat: StandardMaterial3D = null

# ─── Wave tracking (para drop de moedas) ─────────────────────────────────────
var _wave_num: int = 0

# ─── Sistema O — Blood FX ─────────────────────────────────────────────────────
var _blood_trail_timer: float = 0.0
var _gore_mat: StandardMaterial3D
var _hit_flash_mat: StandardMaterial3D

# Texturas pré-carregadas — evita I/O síncrono em cada hit
static var _blood_textures: Array = []
static var _textures_loaded := false

# Cache da lista de inimigos para separação — refresh a cada 0.15s
static var _enemy_cache: Array = []
static var _enemy_cache_timer: float = 0.0

# Throttle de separação — roda a cada 3 frames
var _sep_frame: int = 0
# Throttle de animação esqueletal — roda a cada 2 frames
var _anim_frame: int = 0

# ─── Watchdog — Anti-freeze ───────────────────────────────────────────────────
var _freeze_watch_timer: float = 0.0
var _freeze_watch_pos:   Vector3 = Vector3.ZERO

# ─── Sistema P — Squash & Stretch Jiggle ─────────────────────────────────────
var _jiggle_scale      := Vector3.ONE
var _jiggle_vel        := Vector3.ZERO
var _prev_vel          := Vector3.ZERO
var _was_grounded      := true
var _goblin_base_scale := Vector3.ONE   # scale do spawner (tamanho + variação)
var _jiggle_ready      := false         # true após primeira captura do base scale

var health: int
var player: Node3D
var is_knocked := false
var is_dead := false
var is_attacking := false
var is_in_windup := false
var is_in_strike := false
var _attack_cooldown := 1.0
var _attack_tween: Tween = null

# Esqueleto
var _skeleton: Skeleton3D
var _bones: Dictionary = {}

# Rim glow shader
var _rim_mat: ShaderMaterial = null

# Animação
var run_time := 0.0
var base_mesh_pos: Vector3

const GRAVITY := 9.8
const ARENA_RADIUS: float = 20.0  # margem interna do raio da arena (wall_radius=21)

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	_circle_dir = 1.0 if randf() > 0.5 else -1.0
	_taunt_cooldown = randf_range(4.0, 12.0)
	_throw_cooldown = randf_range(0.5, 2.5)
	_attack_cooldown = randf_range(0.5, 2.0)
	if goblin_mesh:
		base_mesh_pos = goblin_mesh.position
		await get_tree().process_frame
		_cache_skeleton()
		_setup_rim_shader()

	# Material compartilhado entre todos os gore chunks deste goblin
	_gore_mat = StandardMaterial3D.new()
	_gore_mat.albedo_color = Color(0.42, 0.02, 0.02)
	_gore_mat.roughness = 0.95
	_gore_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visível dos dois lados ao tumble

	# Material de hit flash — branco/laranja com emissão
	_hit_flash_mat = StandardMaterial3D.new()
	_hit_flash_mat.albedo_color = Color(1.0, 0.6, 0.3, 1.0)
	_hit_flash_mat.emission_enabled = true
	_hit_flash_mat.emission = Color(1.0, 0.4, 0.1)
	_hit_flash_mat.emission_energy_multiplier = 4.0

	# Pré-carrega texturas de sangue uma única vez (static)
	if not _textures_loaded:
		_textures_loaded = true
		for i in range(1, 8):
			var tex = load("res://assets/textures/blood/blood%d.png" % i)
			if tex:
				_blood_textures.append(tex)

	_sep_frame = randi_range(0, 2)  # offset para não sincronizar todos os goblins

	# Sistema U: zigzag — cada goblin tem fase e frequência únicas
	_zigzag_phase = randf() * TAU
	_zigzag_freq  = randf_range(1.5, 3.5)
	_zigzag_amp   = randf_range(0.3, 0.7)

	# Sistema AB: howl global cooldown staggered per goblin
	_howl_timer = randf_range(15.0, 30.0)
	_jump_cooldown = randf_range(2.0, 5.0)
	_guard_cooldown = randf_range(3.0, 7.0)
	_bomb_cooldown = randf_range(2.0, 5.0)
	_trap_cooldown = randf_range(5.0, 10.0)

	# Sistema S: material de raiva — vermelho pulsante
	_rage_mat = StandardMaterial3D.new()
	_rage_mat.albedo_color = Color(1.0, 0.15, 0.1, 1.0)
	_rage_mat.emission_enabled = true
	_rage_mat.emission = Color(0.8, 0.0, 0.0)
	_rage_mat.emission_energy_multiplier = 1.5

# ─── Sistema F — Wave Escalation ─────────────────────────────────────────────

func emerge_from_cage() -> void:
	if goblin_mesh == null:
		return
	var target := goblin_mesh.scale
	goblin_mesh.scale = Vector3.ZERO
	var tw := goblin_mesh.create_tween()
	tw.tween_property(goblin_mesh, "scale", target * 1.25, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(goblin_mesh, "scale", target, 0.10)
	# Grito ao sair da jaula
	tw.tween_callback(func(): _speak_ctx("rage"))

func apply_wave_scaling(wave: int) -> void:
	var w := mini(wave, 15)
	_wave_num = wave

	# Velocidade — +0.07/wave, crescimento bem suave
	speed += 0.07 * (w - 1)

	# Cooldown de ataque — floor em 0.90s, redução lenta
	attack_cooldown_time = maxf(0.90, attack_cooldown_time - 0.04 * (w - 1))

	# HP: spike tardio — wave 8 = 4 HP, wave 12 = 5 HP
	if wave >= 12:
		max_health = 5
	elif wave >= 8:
		max_health = 4
	health = max_health

	# Dano: só aumenta bem tarde — wave 9 = 2, nunca 3
	if wave >= 9:
		attack_damage = 2

	# Atacantes simultâneos — máximo 3 sempre
	if wave >= 4:
		MAX_ACTIVE_ATTACKERS = 3

# ─── Esqueleto ────────────────────────────────────────────────────────────────

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var r = _find_skeleton(child)
		if r:
			return r
	return null

func _cache_skeleton() -> void:
	_skeleton = _find_skeleton(goblin_mesh)
	if _skeleton == null:
		return
	for n in ["coluna", "clav.R", "clav.L", "bra.R", "bra.L",
			  "cabeca", "qua.R", "qua.L", "coxa.R", "coxa.L",
			  "perna.R", "perna.L"]:
		_bones[n] = _skeleton.find_bone(n)

func _setup_rim_shader() -> void:
	var shader := load("res://shaders/goblin_rim.gdshader") as Shader
	if shader == null or goblin_mesh == null:
		return
	_rim_mat = ShaderMaterial.new()
	_rim_mat.shader = shader
	# Aplica como next_pass em cada surface de cada MeshInstance3D do goblin_mesh
	for mi in goblin_mesh.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		for s in mesh_inst.mesh.get_surface_count():
			var orig := mesh_inst.get_active_material(s)
			if orig != null:
				orig.next_pass = _rim_mat
			else:
				mesh_inst.set_surface_override_material(s, _rim_mat)

func _sb(name: String, q: Quaternion) -> void:
	var idx: int = _bones.get(name, -1)
	if idx >= 0:
		_skeleton.set_bone_pose_rotation(idx, q)

func _slerp_bone(name: String, target: Quaternion, t: float) -> void:
	var idx: int = _bones.get(name, -1)
	if idx < 0:
		return
	var cur := _skeleton.get_bone_pose_rotation(idx)
	_skeleton.set_bone_pose_rotation(idx, cur.slerp(target, t))

# ─── Física ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Safety net: NaN velocity (de knockback com vetor zero normalizado) congela o enemy
	if not velocity.is_finite():
		velocity = Vector3.ZERO

	# Clamp de posição: nunca sair da arena independente do estado
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length_squared() > ARENA_RADIUS * ARENA_RADIUS:
		flat = flat.normalized() * ARENA_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y
		velocity.x = 0.0
		velocity.z = 0.0

	# Refresh do cache de inimigos: apenas um goblin por frame (round-robin via timer estático)
	_enemy_cache_timer -= delta
	if _enemy_cache_timer <= 0.0:
		_enemy_cache_timer = 0.15
		_enemy_cache = get_tree().get_nodes_in_group("enemies")

	_update_jiggle(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_taunt_cooldown = maxf(0.0, _taunt_cooldown - delta)
	_throw_cooldown = maxf(0.0, _throw_cooldown - delta)
	_time_since_last_attack += delta
	EnemyController._howl_global_cooldown = maxf(0.0, EnemyController._howl_global_cooldown - delta)

	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_guard_cooldown = maxf(0.0, _guard_cooldown - delta)
	_shove_cooldown = maxf(0.0, _shove_cooldown - delta)
	_bomb_cooldown = maxf(0.0, _bomb_cooldown - delta)
	_trap_cooldown = maxf(0.0, _trap_cooldown - delta)

	# Sistema AG: flank slot assignment (only one instance does it per tick)
	_flank_timer -= delta
	if _flank_timer <= 0.0:
		_flank_timer = 3.0
		_assign_flank_slots()

	# Sistema Z: guard stance timer
	if is_blocking_stance:
		_guard_timer -= delta
		if _guard_timer <= 0.0:
			is_blocking_stance = false
			_guard_cooldown = randf_range(6.0, 12.0)

	# Sistema AB: war howl timer
	if is_howling:
		_howl_timer -= delta
		if _howl_timer <= 0.0:
			is_howling = false
			_finish_howl()

	# Trapper: fade visibility back in after reveal
	if is_trapper and _trapper_visible_timer > 0.0:
		_trapper_visible_timer -= delta
		if _trapper_visible_timer <= 0.0:
			_set_trapper_alpha(0.18)

	if is_stumbling:
		_stumble_timer -= delta
		if _stumble_timer <= 0.0:
			is_stumbling = false

	# Sistema S: rage timer
	if _is_raging:
		_rage_timer -= delta
		if _rage_timer <= 0.0:
			_is_raging = false
			if not _is_berserk:
				_set_mesh_override(null)

	# Sistema T: cower timer
	if is_cowering:
		_cower_timer -= delta
		if _cower_timer <= 0.0:
			is_cowering = false

	# Sistema W: recovering timer
	if is_recovering:
		_recovery_timer -= delta
		if _recovery_timer <= 0.0:
			is_recovering = false

	# Sistema X: oportunismo timer
	if _opportunism_timer > 0.0:
		_opportunism_timer -= delta

	# Sistema V: berserk — só um goblin restante
	if not _is_berserk and not is_dead and _enemy_cache.size() == 1:
		_trigger_berserk()

	# Sistema L: taunting
	if is_taunting:
		_taunt_timer -= delta
		if _taunt_timer <= 0.0:
			is_taunting = false
		_animate_idle(delta)
		move_and_slide()
		return

	# Sistema T: cowering — move muito devagar, não ataca
	if is_cowering:
		velocity.x = move_toward(velocity.x, 0.0, speed * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * 5.0)
		_animate_idle(delta)
		move_and_slide()
		return

	# Sistema W: recovering pós-knockback — janela de punição
	if is_recovering:
		velocity.x = move_toward(velocity.x, 0.0, speed * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * 5.0)
		_animate_idle(delta)
		move_and_slide()
		return

	# Sistema R: feinting — velocidade setada async, não sobrescrever
	if is_feinting:
		_sep_frame = (_sep_frame + 1) % 3
		if _sep_frame == 0:
			_apply_separation()
		move_and_slide()
		return

	# Sistema Q: throwing (async, just freeze movement)
	if is_throwing:
		move_and_slide()
		return

	# Sistema Y: jump attack — airborne phase
	if is_jumping:
		if is_on_floor() and not _jump_hit_done:
			_on_jump_land()
		_sep_frame = (_sep_frame + 1) % 3
		if _sep_frame == 0:
			_apply_separation()
		move_and_slide()
		return

	# Sistema AB: howling — frozen during wind-up
	if is_howling:
		velocity.x = move_toward(velocity.x, 0.0, speed * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * 5.0)
		_animate_idle(delta)
		move_and_slide()
		return

	# Sistema K: charge é independente do token system — trata primeiro
	if is_charging:
		_update_charge(delta)
		_sep_frame = (_sep_frame + 1) % 3
		if _sep_frame == 0:
			_apply_separation()
		move_and_slide()
		return

	# Sistema O: trail de sangue durante voo de knockback
	if is_knocked:
		if is_on_floor() and velocity.y <= 0.0:
			# Pousou antes do timer — encerra knockback imediatamente
			is_knocked = false
			if not is_dead:
				is_recovering = true
				_recovery_timer = randf_range(0.25, 0.45)
				_spawn_blood_decal(0.7, 1.5)
			if health <= 0 and not is_dead:
				_die()
			# Não retorna — cai para is_recovering ou fluxo normal
		else:
			if not is_on_floor():
				_blood_trail_timer -= delta
				if _blood_trail_timer <= 0.0:
					_blood_trail_timer = 0.25
					_spawn_blood_decal(0.18, 0.5)
			move_and_slide()
			return

	# Watchdog: se o goblin não se mover por 2s, libera estados e aplica impulso de fuga.
	# Estados intencionalmente parados são ignorados (cower, taunt, howl, guard, dead).
	if not is_dead:
		_freeze_watch_timer += delta
		if _freeze_watch_timer >= 1.5:
			var moved := global_position.distance_to(_freeze_watch_pos)
			_freeze_watch_pos = global_position
			_freeze_watch_timer = 0.0
			var intentionally_still := is_taunting or is_cowering or is_howling or is_blocking_stance or is_throwing
			if moved < 0.4 and not intentionally_still:
				# Libera todos os estados de bloqueio
				is_knocked    = false
				is_recovering = false
				is_stumbling  = false
				is_feinting   = false
				is_charging   = false
				is_retreating = false
				is_jumping    = false
				# Corrige posição se estiver no ar
				if not is_on_floor():
					global_position.y = 0.0
				# Impulso aleatório perpendicular para escapar do obstáculo
				var escape := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
				velocity = escape * speed * 4.0

	if is_dead:
		return  # física parada — set_physics_process(false) cuida disso
	if player == null or is_attacking:
		move_and_slide()
		return

	var distance := global_position.distance_to(player.global_position)

	# Sistema J: retreat — goblin corre para longe, de costas para o player
	if is_retreating:
		_retreat_timer -= delta
		# Cancela retreat se perto demais da borda (evita ficar preso na parede)
		var dist_center := Vector2(global_position.x, global_position.z).length()
		if _retreat_timer <= 0.0 or dist_center > ARENA_RADIUS - 2.5:
			is_retreating = false
		else:
			# Vira de costas e foge
			var away := global_position - player.global_position
			away.y = 0.0
			if away.length() > 0.1:
				look_at(global_position + away)
			_move_retreat(delta)
			_sep_frame = (_sep_frame + 1) % 3
			if _sep_frame == 0:
				_apply_separation()
			move_and_slide()
			return

	# Look at player (somente quando não está em retreat)
	if distance > 0.1:
		var look_target := player.global_position
		look_target.y = global_position.y
		look_at(look_target)

	# Bomber: stays at range and lobs bombs
	if is_bomber:
		if distance < 6.0:
			if not is_retreating:
				is_retreating = true
				_retreat_timer = randf_range(1.5, 3.0)
		elif distance <= 18.0 and _bomb_cooldown <= 0.0:
			_start_throw_bomb()
		elif distance <= 18.0:
			_move_circling(delta)
		else:
			var dir: Vector3 = (player.global_position - global_position).normalized()
			dir.y = 0.0
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_animate_run(delta)
		_sep_frame = (_sep_frame + 1) % 3
		if _sep_frame == 0:
			_apply_separation()
		move_and_slide()
		return

	# Trapper: near-invisible, places traps, retreats from player
	if is_trapper:
		if distance < 4.5:
			# Perto demais — recua
			if not is_retreating:
				is_retreating = true
				_retreat_timer = randf_range(2.0, 3.5)
			# (o bloco is_retreating no topo cuidará do movimento)
		elif distance > 11.0:
			# Longe demais — aproxima lentamente em direção ao player
			var dir: Vector3 = (player.global_position - global_position).normalized()
			dir.y = 0.0
			velocity.x = dir.x * speed * 0.55
			velocity.z = dir.z * speed * 0.55
			_animate_run(delta)
		elif _trap_cooldown <= 0.0:
			# No range ideal — coloca armadilha
			_start_place_trap()
			# Deriva lateralmente enquanto coloca
			var dir: Vector3 = (player.global_position - global_position).normalized()
			dir.y = 0.0
			var tangent := Vector3(_circle_dir * dir.z, 0.0, -_circle_dir * dir.x).normalized()
			velocity.x = tangent.x * speed * 0.3
			velocity.z = tangent.z * speed * 0.3
			_animate_run(delta)
		else:
			# Orbita ao redor do player mantendo range 5-10m
			var dir: Vector3 = (player.global_position - global_position).normalized()
			dir.y = 0.0
			var tangent := Vector3(_circle_dir * dir.z, 0.0, -_circle_dir * dir.x).normalized()
			# Leve pull inward pra não se afastar demais
			var move_dir := (tangent * 0.75 + dir * 0.25).normalized()
			velocity.x = move_dir.x * speed * 0.5
			velocity.z = move_dir.z * speed * 0.5
			_animate_run(delta)
		_sep_frame = (_sep_frame + 1) % 3
		if _sep_frame == 0:
			_apply_separation()
		move_and_slide()
		return

	# Sistema Q: ranged kite logic
	if is_ranged:
		if distance < kite_retreat_range:
			# Too close — back away
			if not is_retreating:
				is_retreating = true
				_retreat_timer = randf_range(1.2, 2.5)
		elif distance <= throw_range_max and _throw_cooldown <= 0.0:
			_start_throw()
		elif distance <= throw_range_max:
			_move_circling(delta)
		elif distance > stopping_distance:
			_circling_time = 0.0
			var dir: Vector3 = (player.global_position - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			_zigzag_phase += delta * _zigzag_freq * TAU
			var perp := Vector3(-dir.z, 0.0, dir.x)
			var lateral := perp * sin(_zigzag_phase) * _zigzag_amp * 0.5  # amplitude reduzida no kite
			velocity.x = (dir.x + lateral.x) * speed
			velocity.z = (dir.z + lateral.z) * speed
			_animate_run(delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
			_animate_idle(delta)
	elif distance <= attack_range and _attack_cooldown <= 0.0:
		# Sistema V: berserk ignora token system
		var can_attack: bool = _active_attackers < MAX_ACTIVE_ATTACKERS or _is_berserk
		if can_attack:
			_circling_time = 0.0
			_start_attack()
		else:
			_circling_time += delta
			# Sistema X: oportunismo reduz threshold de charge
			var charge_thresh: float = 1.5 if _opportunism_timer > 0.0 else 3.5
			if _circling_time > charge_thresh and randf() < delta * 0.25:
				_start_charge()
			elif _circling_time > 1.5 and not is_feinting and randf() < delta * 0.12:
				_start_feint()
			else:
				_move_circling(delta)
	elif distance <= attack_range and _attack_cooldown > 0.0:
		_circling_time += delta
		var charge_thresh: float = 1.5 if _opportunism_timer > 0.0 else 3.5
		if _circling_time > charge_thresh and randf() < delta * 0.25:
			_start_charge()
		elif _circling_time > 1.5 and not is_feinting and randf() < delta * 0.12:
			_start_feint()
		else:
			_move_circling(delta)
	elif distance > stopping_distance:
		_circling_time = 0.0
		# Sistema AC: blind spot detection
		var to_goblin := (global_position - player.global_position)
		to_goblin.y = 0.0
		var in_blind_spot: bool = to_goblin.length_squared() > 0.01 and \
				player.global_transform.basis.z.dot(to_goblin.normalized()) > 0.45
		var blind_spot_mult: float = 1.4 if in_blind_spot else 1.0
		var blind_spot_range: float = 0.5 if in_blind_spot else 0.0

		# Sistema L: taunt only if not in blind spot (don't reveal position)
		if distance > 9.0 and _taunt_cooldown <= 0.0 and health == max_health and not in_blind_spot and randf() < delta * 0.4:
			_start_taunt()
		else:
			var dir: Vector3 = (player.global_position - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			var rage_mult: float = 1.35 if _is_raging else 1.0
			var current_speed: float = speed * (stumble_speed_factor if is_stumbling else 1.0) * rage_mult * blind_spot_mult
			_zigzag_phase += delta * _zigzag_freq * TAU
			var perp := Vector3(-dir.z, 0.0, dir.x)
			var lateral := perp * sin(_zigzag_phase) * _zigzag_amp
			velocity.x = (dir.x + lateral.x) * current_speed
			velocity.z = (dir.z + lateral.z) * current_speed
			_animate_run(delta)

			# Sistema Y: jump attack at medium range
			if distance < 5.5 and distance > 2.5 and _jump_cooldown <= 0.0 and not is_ranged and not is_trapper and not is_bomber and randf() < delta * 0.18:
				_start_jump_attack()

			# Sistema Z: guard stance trigger during approach
			if not is_blocking_stance and _guard_cooldown <= 0.0 and not is_ranged and not is_trapper and not is_bomber and randf() < delta * 0.06:
				_start_guard_stance()
	else:
		_circling_time = 0.0
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		_animate_idle(delta)

		# Sistema AF: shove player on contact
		if distance < 1.0 and _shove_cooldown <= 0.0 and not is_ranged and not is_trapper:
			_shove_cooldown = 2.5
			var lateral := Vector3(global_transform.basis.x.x, 0.5, global_transform.basis.x.z).normalized()
			if randf() > 0.5: lateral = -lateral
			if player.has_method("take_damage"):
				player.take_damage(0, lateral * 5.0)

		# Sistema AB: war howl trigger when standing near player
		if _howl_global_cooldown <= 0.0 and health == max_health and distance < 8.0 and not is_ranged and randf() < delta * 0.02:
			_start_war_howl()

	_sep_frame = (_sep_frame + 1) % 3
	if _sep_frame == 0:
		_apply_separation()
	move_and_slide()

# ─── Sistema B — Circling ─────────────────────────────────────────────────────

func _move_circling(delta: float) -> void:
	var to_player := (player.global_position - global_position)
	to_player.y = 0.0
	var my_id := get_instance_id()
	# Sistema AG: use assigned flank slot if available
	if _flank_slots.has(my_id) and player != null:
		var angle: float = _flank_slots[my_id]
		var target := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (stopping_distance * 2.0)
		var to_target := (target - global_position)
		to_target.y = 0.0
		if to_target.length() > 0.5:
			var dir := to_target.normalized()
			velocity.x = dir.x * speed * circle_speed_factor
			velocity.z = dir.z * speed * circle_speed_factor
		else:
			# At flank position — just idle
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
		_animate_run(delta)
		return
	var tangent := Vector3(_circle_dir * to_player.z, 0.0, -_circle_dir * to_player.x).normalized()
	var dir := (tangent * 0.7 + to_player.normalized() * 0.3).normalized()
	velocity.x = dir.x * speed * circle_speed_factor
	velocity.z = dir.z * speed * circle_speed_factor
	_animate_run(delta)

# ─── Sistema J — Retreat ─────────────────────────────────────────────────────

func _move_retreat(delta: float) -> void:
	var away := (global_position - player.global_position)
	away.y = 0.0
	away = away.normalized()
	velocity.x = away.x * speed * retreat_move_factor
	velocity.z = away.z * speed * retreat_move_factor
	_animate_run(delta)

# ─── Sistema L — Taunt ────────────────────────────────────────────────────────

func _pick_taunt_ctx() -> String:
	if _is_berserk:      return "berserk"
	if _is_raging:       return "rage"
	var player_hp = player.get("health") if player else null
	if player_hp != null and player_hp <= 1: return "player_low"
	if _enemy_cache.size() >= 6:             return "outnumber"
	if is_leader:                            return "leader"
	return "idle"

func _start_taunt() -> void:
	is_taunting = true
	_taunt_cooldown = randf_range(12.0, 25.0)
	_taunt_timer = randf_range(1.2, 2.2)
	velocity.x = 0.0
	velocity.z = 0.0
	_speak_ctx(_pick_taunt_ctx())
	if _skeleton:
		_sb("bra.R", Quaternion(Vector3.FORWARD,  1.1))
		_sb("bra.L", Quaternion(Vector3.FORWARD, -1.1))
		_sb("coluna", Quaternion(Vector3.RIGHT, 0.12))

# ─── Sistema Q — Throw ────────────────────────────────────────────────────────

func _start_throw() -> void:
	if is_dead or player == null:
		return
	is_throwing = true
	_throw_cooldown = throw_cooldown_time() + randf_range(-0.5, 1.2)
	velocity.x = 0.0
	velocity.z = 0.0

	# Windup pose
	if _skeleton:
		_sb("bra.R",  Quaternion(Vector3.FORWARD, 1.3))
		_sb("clav.R", Quaternion(Vector3.FORWARD, 0.45))
		_sb("coluna", Quaternion(Vector3.RIGHT, 0.18))

	await get_tree().create_timer(0.38, true).timeout
	if is_dead or not is_instance_valid(self):
		is_throwing = false
		return

	_launch_projectile()

	# Release pose
	if _skeleton:
		_sb("bra.R",  Quaternion(Vector3.FORWARD, -0.5))
		_sb("clav.R", Quaternion(Vector3.FORWARD, -0.1))

	await get_tree().create_timer(0.28, true).timeout
	if is_dead or not is_instance_valid(self):
		is_throwing = false
		return
	is_throwing = false

func throw_cooldown_time() -> float:
	return attack_cooldown_time * 1.5

func _launch_projectile() -> void:
	if player == null:
		return
	var proj_scene := projectile_scene
	if proj_scene == null:
		proj_scene = load("res://scenes/enemies/projectile.tscn") as PackedScene
	if proj_scene == null:
		return
	var proj := proj_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var origin := global_position + Vector3(0.0, 1.4, 0.0)
	# Aim slightly ahead of player based on their velocity
	var target := player.global_position + Vector3(0.0, 0.9, 0.0)
	proj.damage = throw_damage
	proj.launch(origin, target, throw_speed)

# ─── Sistema R — Feint ────────────────────────────────────────────────────────

func _start_feint() -> void:
	if is_feinting or is_dead or player == null: return
	is_feinting = true
	_circling_time = 0.0
	# Charge agressivo por 0.35s
	var dir: Vector3 = (player.global_position - global_position).normalized()
	dir.y = 0.0
	velocity.x = dir.x * speed * 2.2
	velocity.z = dir.z * speed * 2.2
	if _skeleton:
		_sb("coluna", Quaternion(Vector3.RIGHT, -0.35))
		_sb("cabeca", Quaternion(Vector3.RIGHT,  0.2))
	await get_tree().create_timer(0.35, true).timeout
	if not is_instance_valid(self) or is_dead:
		is_feinting = false
		return
	# Para e recua levemente
	velocity.x = 0.0
	velocity.z = 0.0
	await get_tree().create_timer(0.18, true).timeout
	if not is_instance_valid(self) or is_dead:
		is_feinting = false
		return
	is_feinting = false

# ─── Sistema S — Rage ─────────────────────────────────────────────────────────

func _trigger_rage() -> void:
	if _is_raging or is_dead: return
	_is_raging = true
	_rage_timer = randf_range(4.0, 6.5)
	if _rim_mat:
		_rim_mat.set_shader_parameter("rage_glow", 1.0)
	if _rage_mat:
		_set_mesh_override(_rage_mat)
	# Grito de raiva curto
	_speak_ctx("rage")

# ─── Sistema Y — Jump Attack ─────────────────────────────────────────────────

func _start_jump_attack() -> void:
	if is_jumping or is_dead or player == null: return
	is_jumping = true
	_jump_hit_done = false
	_jump_cooldown = randf_range(6.0, 12.0)
	var to_player := (player.global_position - global_position)
	to_player.y = 0.0
	var dir := to_player.normalized()
	# Crouch windup
	if _skeleton:
		_sb("coluna", Quaternion(Vector3.RIGHT, 0.55))
		_sb("coxa.R", Quaternion(Vector3.RIGHT, 0.4))
		_sb("coxa.L", Quaternion(Vector3.RIGHT, 0.4))
	velocity.y = 8.5
	velocity.x = dir.x * 5.5
	velocity.z = dir.z * 5.5

func _on_jump_land() -> void:
	_jump_hit_done = true
	is_jumping = false
	# Squash on landing
	_jiggle_vel.y -= 0.8
	_jiggle_vel.x += 0.4
	_jiggle_vel.z += 0.4
	if player == null or is_dead: return
	var d := global_position.distance_to(player.global_position)
	if d < 2.2:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0.0
		player.take_damage(attack_damage, dir * attack_knockback * 1.5 + Vector3(0, 3.5, 0))
		_spawn_blood_decal(0.5, 1.0)

# ─── Sistema Z — Guard Stance ─────────────────────────────────────────────────

func _start_guard_stance() -> void:
	if is_blocking_stance or is_dead: return
	is_blocking_stance = true
	_guard_timer = randf_range(1.8, 3.2)
	if _skeleton:
		_sb("bra.R", Quaternion(Vector3.FORWARD,  1.2))
		_sb("bra.L", Quaternion(Vector3.FORWARD, -1.2))
		_sb("coluna", Quaternion(Vector3.RIGHT, -0.2))

# ─── Sistema AA — Pack Leader ─────────────────────────────────────────────────

func promote_to_leader() -> void:
	if is_dead: return
	is_leader = true
	EnemyController._wave_has_leader = true
	max_health += 1
	health = max_health
	if _rim_mat:
		_rim_mat.set_shader_parameter("leader_glow", 1.0)
	speed *= 1.12
	if goblin_mesh:
		goblin_mesh.scale *= 1.12
	_leader_mat = StandardMaterial3D.new()
	_leader_mat.albedo_color = Color(1.0, 0.75, 0.2, 1.0)
	_leader_mat.emission_enabled = true
	_leader_mat.emission = Color(0.6, 0.4, 0.0)
	_leader_mat.emission_energy_multiplier = 0.8
	_set_mesh_override(_leader_mat)

# ─── Sistema AB — War Howl ────────────────────────────────────────────────────

func _start_war_howl() -> void:
	if is_howling or is_dead: return
	is_howling = true
	_howl_timer = 0.55
	EnemyController._howl_global_cooldown = randf_range(20.0, 35.0)
	_speak_ctx("howl")
	if _skeleton:
		_sb("bra.R", Quaternion(Vector3.FORWARD,  1.3))
		_sb("bra.L", Quaternion(Vector3.FORWARD, -1.3))
		_sb("cabeca", Quaternion(Vector3.RIGHT, -0.4))

func _finish_howl() -> void:
	for e in _enemy_cache:
		if not is_instance_valid(e): continue
		var ec := e as EnemyController
		if ec == null or ec == self or ec.is_dead: continue
		if global_position.distance_to(ec.global_position) < 10.0:
			ec._attack_cooldown = 0.0
			ec._opportunism_timer = 3.0

# ─── Sistema AG — Coordinated Flanking ───────────────────────────────────────

static func _assign_flank_slots() -> void:
	var waiting: Array = []
	for e in _enemy_cache:
		if not is_instance_valid(e): continue
		var ec := e as EnemyController
		if ec == null or ec.is_dead or ec.is_attacking or ec.is_jumping: continue
		if not ec._holds_attack_token:
			waiting.append(ec)
	if waiting.size() < 2:
		_flank_slots.clear()
		return
	var angles := [0.0, TAU / 3.0, TAU * 2.0 / 3.0, TAU * 5.0 / 6.0]
	_flank_slots.clear()
	for i in mini(waiting.size(), angles.size()):
		_flank_slots[waiting[i].get_instance_id()] = angles[i]

# ─── Bomber ───────────────────────────────────────────────────────────────────

func _start_throw_bomb() -> void:
	if is_dead or player == null: return
	is_throwing = true
	_bomb_cooldown = randf_range(5.0, 9.0)
	velocity.x = 0.0
	velocity.z = 0.0
	if _skeleton:
		_sb("bra.R",  Quaternion(Vector3.FORWARD, 1.3))
		_sb("clav.R", Quaternion(Vector3.FORWARD, 0.45))
		_sb("coluna", Quaternion(Vector3.RIGHT, 0.2))
	await get_tree().create_timer(0.5, true).timeout
	if is_dead or not is_instance_valid(self):
		is_throwing = false
		return
	_launch_bomb()
	if _skeleton:
		_sb("bra.R",  Quaternion(Vector3.FORWARD, -0.5))
		_sb("clav.R", Quaternion(Vector3.FORWARD, -0.1))
	await get_tree().create_timer(0.35, true).timeout
	if is_dead or not is_instance_valid(self):
		is_throwing = false
		return
	is_throwing = false

func _launch_bomb() -> void:
	if player == null: return
	var b_scene := bomb_scene
	if b_scene == null:
		b_scene = load("res://scenes/enemies/bomb.tscn") as PackedScene
	if b_scene == null: return
	var bomb := b_scene.instantiate()
	get_tree().current_scene.add_child(bomb)
	var origin := global_position + Vector3(0.0, 1.4, 0.0)
	# Land slightly offset from player (area denial, not instant hit)
	var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var target := player.global_position + offset
	bomb.launch(origin, target, 12.0)

# ─── Trapper ──────────────────────────────────────────────────────────────────

func setup_trapper() -> void:
	is_trapper = true
	_trap_cooldown = randf_range(3.0, 6.0)
	_trapper_mat = StandardMaterial3D.new()
	_trapper_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trapper_mat.albedo_color = Color(0.4, 0.6, 0.3, 0.18)
	_set_trapper_alpha(0.18)

func _set_trapper_alpha(alpha: float) -> void:
	if _trapper_mat == null: return
	_trapper_mat.albedo_color.a = alpha
	_set_mesh_override(_trapper_mat)

func _start_place_trap() -> void:
	if is_dead or player == null: return
	var t_scene := trap_scene
	if t_scene == null:
		t_scene = load("res://scenes/enemies/spike_trap.tscn") as PackedScene
	if t_scene == null: return
	_trap_cooldown = randf_range(8.0, 14.0)
	# Place trap between player and a random nearby position (high-traffic area)
	var dir_to_player := (player.global_position - global_position).normalized()
	dir_to_player.y = 0.0
	var offset := dir_to_player * randf_range(3.0, 7.0)
	offset += Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
	var trap_pos := global_position + offset
	trap_pos.y = global_position.y
	var trap := t_scene.instantiate()
	get_tree().current_scene.add_child(trap)
	trap.global_position = trap_pos
	trap.trapper = self  # trapper reference so trap can call notify_triggered()

func notify_trap_triggered() -> void:
	# Briefly reveal the trapper
	_trapper_visible_timer = 1.8
	_set_trapper_alpha(0.85)

# ─── Sistema T — Cower ────────────────────────────────────────────────────────

func _start_cower() -> void:
	if is_cowering or is_dead: return
	is_cowering = true
	_cower_timer = randf_range(0.7, 1.2)
	velocity.x = 0.0
	velocity.z = 0.0
	if _skeleton:
		_sb("bra.R",  Quaternion(Vector3.FORWARD, -0.9))
		_sb("bra.L",  Quaternion(Vector3.FORWARD,  0.9))
		_sb("coluna", Quaternion(Vector3.RIGHT, 0.5))
		_sb("cabeca", Quaternion(Vector3.RIGHT, 0.4))
	if randf() < 0.45:
		_speak_ctx("cower")

# ─── Sistema V — Berserk ──────────────────────────────────────────────────────

func _trigger_berserk() -> void:
	if _is_berserk or is_dead: return
	_is_berserk = true
	speed *= 1.8
	attack_cooldown_time = maxf(0.45, attack_cooldown_time - 0.5)
	_rage_timer = 9999.0   # rage permanente via berserk
	_is_raging = true
	if _rage_mat:
		_set_mesh_override(_rage_mat)
	if goblin_mesh:
		goblin_mesh.scale *= 1.15
	_speak_ctx("berserk_trigger")

# ─── Sistema L — Speech helpers ───────────────────────────────────────────────

func _speak(text: String, color: Color, size: int, duration: float) -> void:
	if not is_instance_valid(self): return
	var lbl := Label3D.new()
	lbl.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size    = size
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.position     = Vector3(randf_range(-0.3, 0.3), 0.9, 0.0)
	lbl.modulate     = color
	lbl.text         = text
	add_child(lbl)

	var tw := lbl.create_tween()
	# Scale bounce: 0 → 1.15 → 1.0
	lbl.scale = Vector3.ZERO
	tw.tween_property(lbl, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.08)
	# Float up over full duration
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 0.4, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Fade out in last 40% of duration
	tw.tween_property(lbl, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6 - 0.2)
	tw.tween_callback(lbl.queue_free)

func _speak_ctx(ctx: String) -> void:
	if not _SPEECH_DB.has(ctx) or not _SPEECH_STYLE.has(ctx): return
	var db: Array   = _SPEECH_DB[ctx]
	var st: Dictionary = _SPEECH_STYLE[ctx]
	if db.is_empty(): return
	var text: String     = db[randi() % db.size()]
	var dur: float       = randf_range(st["dur"][0], st["dur"][1])
	_speak(text, st["color"], st["size"], dur)

# ─── Sistema K — Charge Attack ────────────────────────────────────────────────

func _start_charge() -> void:
	is_charging = true
	_charge_timer = charge_duration
	_circling_time = 0.0
	# Abaixa a cabeça na pose de investida
	if _skeleton:
		_sb("coluna", Quaternion(Vector3.RIGHT, -0.4))
		_sb("cabeca", Quaternion(Vector3.RIGHT, 0.3))
		_sb("bra.R",  Quaternion(Vector3.RIGHT, -0.3))
		_sb("bra.L",  Quaternion(Vector3.RIGHT, -0.3))

func _update_charge(delta: float) -> void:
	_charge_timer -= delta
	if player == null or is_dead or _charge_timer <= 0.0:
		is_charging = false
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()

	# Mantém o olhar no player durante a carga
	if dist > 0.1:
		var look_target := player.global_position
		look_target.y = global_position.y
		look_at(look_target)

	var dir := to_player.normalized()
	dir.y = 0.0
	velocity.x = dir.x * speed * charge_speed_mult
	velocity.z = dir.z * speed * charge_speed_mult
	_animate_run(delta)

	if dist <= attack_range * 1.1:
		_do_attack_hit_with_force(charge_knockback)
		is_charging = false

# ─── Sistema P — Squash & Stretch Jiggle ─────────────────────────────────────

func _update_jiggle(delta: float) -> void:
	if goblin_mesh == null:
		return

	var on_floor := is_on_floor()
	if on_floor and not _was_grounded:
		# Captura o scale base do spawner (inclui variação de tamanho + promoções)
		# Feito aqui porque _ready() roda antes do spawner aplicar o scale.
		if not _jiggle_ready:
			_goblin_base_scale = goblin_mesh.scale
			_jiggle_ready = true
		var impact := clampf(-_prev_vel.y, 0.0, 14.0)
		# Impulso UNIFORME — scale sempre proporcional em X/Y/Z → Jolt não reclama
		var impulse := -impact * 0.08
		_jiggle_vel = Vector3(impulse, impulse, impulse)
	_was_grounded = on_floor
	_prev_vel.y = velocity.y

	var mag := absf(_jiggle_vel.x) + absf(_jiggle_vel.y) + absf(_jiggle_vel.z)
	if mag < 0.005 and _jiggle_scale.is_equal_approx(Vector3.ONE):
		return

	_jiggle_vel   += (Vector3.ONE - _jiggle_scale) * 200.0 * delta
	_jiggle_vel   *= maxf(0.0, 1.0 - 14.0 * delta)
	_jiggle_scale += _jiggle_vel * delta
	_jiggle_scale  = _jiggle_scale.clamp(Vector3(0.55, 0.55, 0.55), Vector3(1.6, 1.6, 1.6))

	# Aplica relativo ao base scale do spawner — preserva variação de tamanho
	goblin_mesh.scale = _goblin_base_scale * _jiggle_scale

# ─── Sistema M — Separation Force ────────────────────────────────────────────

func _apply_separation() -> void:
	const SEP_RADIUS := 1.1
	const SEP_FORCE  := 3.0
	for enemy in _enemy_cache:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var diff: Vector3 = global_position - (enemy as Node3D).global_position
		diff.y = 0.0
		var dist := diff.length()
		if dist < SEP_RADIUS and dist > 0.01:
			var strength := (SEP_RADIUS - dist) / SEP_RADIUS * SEP_FORCE
			velocity.x += diff.x / dist * strength
			velocity.z += diff.z / dist * strength

# ─── Animação ─────────────────────────────────────────────────────────────────

func _animate_run(delta: float) -> void:
	if goblin_mesh == null:
		return
	var freq_mult: float = 0.7 if health == 1 else 1.0
	run_time += delta * walk_freq * freq_mult
	goblin_mesh.position = base_mesh_pos + Vector3(0, abs(sin(run_time)) * 0.06, 0)

	# Bones só a cada 2 frames — imperceptível a 60fps
	_anim_frame = (_anim_frame + 1) % 2
	if _skeleton == null or _anim_frame != 0:
		return

	var s := sin(run_time)
	var c := cos(run_time)

	_sb("coxa.R",  Quaternion(Vector3.RIGHT,  s * walk_leg_swing))
	var limp: float = 0.35 if health == 1 else 1.0
	_sb("coxa.L",  Quaternion(Vector3.RIGHT, -s * walk_leg_swing * limp))
	_sb("perna.R", Quaternion(Vector3.RIGHT, maxf(0.0, -s) * walk_knee_bend))
	_sb("perna.L", Quaternion(Vector3.RIGHT, maxf(0.0,  s) * walk_knee_bend * limp))
	_sb("bra.R", Quaternion(Vector3.RIGHT, -s * walk_arm_swing))
	_sb("bra.L", Quaternion(Vector3.RIGHT,  s * walk_arm_swing))
	_sb("coluna",
		Quaternion(Vector3.RIGHT, -walk_spine_lean) *
		Quaternion(Vector3.FORWARD, c * walk_spine_sway))
	_sb("cabeca", Quaternion(Vector3.RIGHT, walk_spine_lean * 0.5))

func _animate_idle(delta: float) -> void:
	if goblin_mesh == null:
		return
	run_time += delta * 1.5
	goblin_mesh.position.y = lerpf(
		goblin_mesh.position.y,
		base_mesh_pos.y + sin(run_time) * 0.01,
		delta * 5.0)

	_anim_frame = (_anim_frame + 1) % 2
	if _skeleton == null or _anim_frame != 0:
		return

	var lerp_t := 1.0 - pow(0.02, delta)

	for b in ["coxa.R", "coxa.L", "perna.R", "perna.L", "bra.R", "bra.L", "cabeca"]:
		_slerp_bone(b, Quaternion.IDENTITY, lerp_t)

	var breathe := Quaternion(Vector3.RIGHT, sin(run_time * 1.2) * idle_breathe)
	_slerp_bone("coluna", breathe, lerp_t)

# ─── Ataque ───────────────────────────────────────────────────────────────────

func _release_attack_token() -> void:
	if _holds_attack_token:
		_holds_attack_token = false
		_active_attackers = maxi(0, _active_attackers - 1)

func _start_attack() -> void:
	_active_attackers += 1
	_holds_attack_token = true
	is_attacking = true
	velocity.x = 0.0
	velocity.z = 0.0

	var hesitation := randf_range(0.0, 0.15)
	if hesitation > 0.02:
		await get_tree().create_timer(hesitation, true).timeout

	if is_dead or not is_instance_valid(self):
		_release_attack_token()
		is_attacking = false
		return

	is_in_windup = true
	is_in_strike = false
	_attack_cooldown = maxf(0.5, attack_cooldown_time + randf_range(-0.2, 0.4))

	var use_heavy := _time_since_last_attack > 2.0
	_time_since_last_attack = 0.0
	var windup := heavy_slam_windup if use_heavy else attack_windup
	var kb     := heavy_slam_knockback if use_heavy else attack_knockback

	_run_attack_tween(windup, kb, use_heavy)

func _run_attack_tween(windup: float, kb: float, is_heavy: bool) -> void:
	var t_windup  := windup * 0.55
	var t_strike  := windup * 0.30
	var t_recover := windup * 0.70

	var tween := create_tween()
	_attack_tween = tween
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if is_heavy:
		tween.tween_method(_pose_windup_heavy, 0.0, 1.0, t_windup)
	else:
		tween.tween_method(_pose_windup, 0.0, 1.0, t_windup)

	tween.tween_callback(func():
		is_in_windup = false
		is_in_strike = true
		_do_attack_hit_with_force(kb))

	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_method(_pose_strike, 0.0, 1.0, t_strike)

	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_pose_recover, 0.0, 1.0, t_recover)
	tween.tween_callback(func():
		is_in_strike = false
		is_attacking = false
		_release_attack_token())

func _pose_windup(t: float) -> void:
	if _skeleton == null: return
	_sb("bra.R",  Quaternion(Vector3.FORWARD, 0.8 * t))
	_sb("clav.R", Quaternion(Vector3.FORWARD, 0.25 * t))
	_sb("coluna", Quaternion(Vector3.RIGHT, 0.15 * t))

func _pose_windup_heavy(t: float) -> void:
	if _skeleton == null: return
	_sb("bra.R",  Quaternion(Vector3.FORWARD,  0.9 * t))
	_sb("bra.L",  Quaternion(Vector3.FORWARD, -0.9 * t))
	_sb("clav.R", Quaternion(Vector3.FORWARD,  0.3 * t))
	_sb("clav.L", Quaternion(Vector3.FORWARD, -0.3 * t))
	_sb("coluna", Quaternion(Vector3.RIGHT, 0.25 * t))

func _pose_strike(t: float) -> void:
	if _skeleton == null: return
	_sb("bra.R",  Quaternion(Vector3.FORWARD, lerpf(0.8, -0.7, t)))
	_sb("clav.R", Quaternion(Vector3.FORWARD, lerpf(0.25, -0.1, t)))
	_sb("coluna", Quaternion(Vector3.RIGHT, lerpf(0.15, -0.30, t)))

func _pose_recover(t: float) -> void:
	if _skeleton == null: return
	_slerp_bone("bra.R",  Quaternion.IDENTITY, t * 0.6)
	_slerp_bone("clav.R", Quaternion.IDENTITY, t * 0.6)
	_slerp_bone("coluna", Quaternion.IDENTITY, t * 0.4)

func _do_attack_hit_with_force(kb: float) -> void:
	if is_dead or player == null: return
	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0.0
		velocity = dir * attack_lunge
		velocity.y = 1.5
		if player.has_method("take_damage"):
			player.take_damage(attack_damage, dir * kb)

# ─── Dano / Morte ─────────────────────────────────────────────────────────────

func take_hit(knockback: Vector3) -> void:
	if is_dead: return
	# Guard: vetor zero ou NaN normalizado → NaN no velocity → freeze permanente
	if not knockback.is_finite() or knockback.length_squared() < 0.0001:
		knockback = Vector3.BACK * 2.0

	# Sistema Z: guard stance absorbs one normal hit (heavy slam kb >= 35 breaks through)
	if is_blocking_stance:
		var kb_mag := knockback.length()
		if kb_mag < 35.0:
			is_blocking_stance = false
			_guard_cooldown = randf_range(8.0, 14.0)
			_bounce_mesh()
			_flash_hit()
			_speak_ctx("block")
			return
		else:
			# Heavy slam shatters guard
			is_blocking_stance = false
			_guard_cooldown = randf_range(4.0, 6.0)
			_speak_ctx("guard_break")

	# Sistema AB: hitting howler cancels the howl
	if is_howling:
		is_howling = false
		_howl_timer = 0.0
		_speak_ctx("howl_cancel")

	if is_attacking and _attack_tween:
		_attack_tween.kill()
		_attack_tween = null
		is_in_windup = false
		is_in_strike = false
		is_attacking = false
		_release_attack_token()
	# Interrompe qualquer estado assíncrono em andamento
	is_charging  = false
	is_feinting  = false
	is_howling   = false
	is_jumping   = false
	health -= 1
	var hit_dir := knockback.normalized() if knockback.length_squared() > 0.0001 else Vector3.BACK
	_play_blood(-hit_dir + Vector3(0, 0.6, 0))  # spray sobe e se afasta do golpe
	_bounce_mesh()
	_flash_hit()

	# Sistema O: partículas sólidas que ficam no chão
	_spawn_gore_chunks(2, -hit_dir * 2.0)

	# Splat no chão a cada hit
	var n_splats := 2 if health == 0 else 1
	for i in n_splats:
		var offset := Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
		_spawn_blood_decal(0.35, 0.85, offset)

	# Sistema J: ao chegar em 1 HP, recua
	if health == 1 and not is_retreating:
		is_retreating = true
		_retreat_timer = randf_range(1.0, 2.0)

	# Rim shader — flash branco de dano
	if _rim_mat:
		_rim_mat.set_shader_parameter("damage_flash", 1.0)
		var ft := create_tween()
		ft.tween_method(func(v: float): _rim_mat.set_shader_parameter("damage_flash", v),
			1.0, 0.0, 0.18)

	# Sistema X: notifica goblins próximos que o player atacou
	EnemyController.notify_player_attacked(global_position)

	var kb_magnitude := knockback.length()
	if kb_magnitude < stumble_threshold and not is_attacking:
		# Sistema I: stumble leve
		is_stumbling = true
		_stumble_timer = stumble_duration
		velocity.x = knockback.x * 0.3
		velocity.z = knockback.z * 0.3
		# Sistema N: pose direcional
		_flinch_from_direction(knockback.normalized())
		if health <= 0:
			_die()
	else:
		velocity = knockback
		velocity.y = 5.0
		is_knocked = true
		is_recovering = false
		get_tree().create_timer(knockback_duration, true).timeout.connect(func():
			if not is_instance_valid(self) or not is_knocked:
				return  # Já pousou — transição já feita no _physics_process
			is_knocked = false
			# Sistema W: recovering — janela de punição ao pousar
			if not is_dead:
				is_recovering = true
				_recovery_timer = randf_range(0.25, 0.45)
			# Sistema O: landing splat ao pousar
			_spawn_blood_decal(0.7, 1.5)
			if health <= 0 and not is_dead:
				_die()
		, CONNECT_ONE_SHOT)
		# Sistema T: cower se foi parry (kb >= 35)
		if kb_magnitude >= 35.0:
			get_tree().create_timer(knockback_duration + 0.2, true).timeout.connect(func():
				if is_instance_valid(self) and not is_dead:
					_start_cower()
			, CONNECT_ONE_SHOT)

# ─── Sistema N — Directional Flinch ──────────────────────────────────────────

func _flinch_from_direction(hit_dir: Vector3) -> void:
	if _skeleton == null: return
	# Converte direção do hit para espaço local do goblin
	var local_hit := global_transform.basis.inverse() * hit_dir
	if local_hit.x > 0.4:
		# Golpe vindo da direita → inclina para a esquerda
		_sb("coluna", Quaternion(Vector3.FORWARD, -0.45))
		_sb("bra.L",  Quaternion(Vector3.FORWARD, -0.65))
	elif local_hit.x < -0.4:
		# Golpe vindo da esquerda → inclina para a direita
		_sb("coluna", Quaternion(Vector3.FORWARD, 0.45))
		_sb("bra.R",  Quaternion(Vector3.FORWARD, 0.65))
	elif local_hit.z > 0.0:
		# Golpe de frente → recua a coluna
		_sb("coluna", Quaternion(Vector3.RIGHT, 0.55))
		_sb("cabeca", Quaternion(Vector3.RIGHT, 0.25))
	else:
		# Golpe por trás → lança para frente
		_sb("coluna", Quaternion(Vector3.RIGHT, -0.45))
		_sb("cabeca", Quaternion(Vector3.RIGHT, -0.2))

func _bounce_mesh() -> void:
	# Impulso no spring — squash lateral + compressão vertical (cartoonístico)
	_jiggle_vel.x += 1.4
	_jiggle_vel.y -= 2.2
	_jiggle_vel.z += 1.4

func _flash_hit() -> void:
	_set_mesh_override(_hit_flash_mat)
	get_tree().create_timer(0.07, true).timeout.connect(func():
		# Trapper restaura invisibilidade após flash; outros voltam ao material padrão
		if is_trapper and _trapper_visible_timer <= 0.0:
			_set_mesh_override(_trapper_mat)
		else:
			_set_mesh_override(null)
	)

func _set_mesh_override(mat: Material) -> void:
	if goblin_mesh == null: return
	_traverse_meshes(goblin_mesh, mat)

func _traverse_meshes(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_traverse_meshes(child, mat)

func _play_blood(direction: Vector3 = Vector3.UP) -> void:
	# Não usar $BloodParticles (segue o goblin no ar) — spawna independente na cena
	_spawn_blood_jet(global_position + Vector3(0, 0.7, 0), direction, 28, 0.18, 0.55)

func _die() -> void:
	if is_dead: return
	is_dead = true
	# Reset de todos os estados — garante que nenhuma flag fica "presa" no zombie state
	is_charging    = false
	is_throwing    = false
	is_feinting    = false
	is_howling     = false
	is_taunting    = false
	is_cowering    = false
	is_retreating  = false
	is_recovering  = false
	is_stumbling   = false
	is_blocking_stance = false
	is_jumping     = false
	is_in_windup   = false
	is_in_strike   = false
	# Garante que o death tween sempre roda, mesmo com árvore pausada (baú, pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Mata attack tween se ainda estiver ativo
	if _attack_tween:
		_attack_tween.kill()
		_attack_tween = null
		is_attacking = false
	_release_attack_token()
	remove_from_group("enemies")  # sai do grupo imediatamente — não espera queue_free
	_drop_coins()
	EnemyController.on_ally_death(global_position)  # Sistema S: notifica aliados próximos
	if is_leader:
		EnemyController.on_leader_death(global_position)
	set_physics_process(false)    # para toda física — sem float, sem slide
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	velocity = Vector3.ZERO

	# Sistema L: decal de sangue no chão + burst de gore
	_spawn_blood_decal()
	_spawn_gore_chunks(4, Vector3.ZERO)
	# Jets de morte: 2 jets em vez de 4 (fundido em burst maior)
	var death_origin := global_position + Vector3(0, 0.8, 0)
	var fwd := -global_transform.basis.z
	_spawn_blood_jet(death_origin, fwd,        50, 0.08, 0.28)
	_spawn_blood_jet(death_origin, Vector3.UP, 30, 0.06, 0.18)

	# Sistema H: death variety
	var death_roll := randf()
	if _skeleton:
		if death_roll < 0.4:
			_sb("coluna", Quaternion(Vector3.RIGHT, -0.8))
			_sb("cabeca", Quaternion(Vector3.RIGHT, -0.4))
		elif death_roll < 0.8:
			_sb("coluna", Quaternion(Vector3.RIGHT, 0.7))
			_sb("bra.R",  Quaternion(Vector3.FORWARD,  0.6))
			_sb("bra.L",  Quaternion(Vector3.FORWARD, -0.6))
		# else: spin — sem pose, tween rotaciona

	# Safety: garante queue_free mesmo que os awaits abaixo travem
	get_tree().create_timer(2.0, true).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	, CONNECT_ONE_SHOT)

	Engine.time_scale = 0.15
	await get_tree().create_timer(0.18, true, false, true).timeout
	Engine.time_scale = 1.0
	var tween := create_tween()
	var visual := goblin_mesh if goblin_mesh != null else self
	if death_roll >= 0.8:
		tween.tween_property(self, "rotation:y", rotation.y + TAU * 1.5, 0.35)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(visual, "scale", Vector3.ZERO, 0.35)
	else:
		tween.tween_property(visual, "scale", Vector3.ZERO, 0.25)
	await tween.finished
	if not is_instance_valid(self): return
	if player and player.has_method("add_combo_kill"):
		player.add_combo_kill()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_kill"):
		hud.register_kill()
	queue_free()

func _drop_coins() -> void:
	var coin_scene := load("res://scenes/economy/coin.tscn") as PackedScene
	if coin_scene == null:
		return
	# Base por tipo + bônus de wave (+1 a cada 3 waves)
	var base: int = 1
	if is_leader:
		base = 4
	elif is_bomber:
		base = 3
	elif is_trapper or is_ranged:
		base = 2
	var coin_count: int = base + (_wave_num / 3)
	for i in coin_count:
		var coin := coin_scene.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + Vector3(
			randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4)
		)
		coin.linear_velocity = Vector3(
			randf_range(-3.0, 3.0), randf_range(3.0, 6.0), randf_range(-3.0, 3.0)
		)

# ─── Sistema O — Blood Jets + Gore Chunks ────────────────────────────────────

func _spawn_blood_jet(origin: Vector3, direction: Vector3,
		count: int = 35, scale_min: float = 0.06, scale_max: float = 0.18) -> void:
	var ps := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()

	mat.direction = direction.normalized()
	mat.spread = 22.0
	mat.initial_velocity_min = 7.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0.0, -18.0, 0.0)
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = Color(0.85, 0.02, 0.02)
	mat.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED

	ps.process_material = mat
	ps.amount = count
	ps.lifetime = 0.55
	ps.one_shot = true
	ps.explosiveness = 0.92   # quase tudo de uma vez — burst
	ps.emitting = true

	get_tree().current_scene.add_child(ps)
	ps.global_position = origin

	# Free assim que o burst terminar (one_shot finished signal)
	ps.finished.connect(func(): if is_instance_valid(ps): ps.queue_free())
	# Fallback caso finished não dispare
	get_tree().create_timer(2.0).timeout.connect(
		func(): if is_instance_valid(ps): ps.queue_free()
	)

func _spawn_gore_chunks(count: int, base_vel: Vector3) -> void:
	var origin := global_position + Vector3(0, 0.65, 0)
	for i in count:
		var rb := RigidBody3D.new()

		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var sz := Vector2(randf_range(0.08, 0.26), randf_range(0.06, 0.20))
		quad.size = sz
		mi.mesh = quad
		mi.material_override = _gore_mat

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(sz.x, 0.015, sz.y)
		col.shape = box

		rb.add_child(mi)
		rb.add_child(col)
		get_tree().current_scene.add_child(rb)
		rb.global_position = origin + Vector3(
			randf_range(-0.25, 0.25),
			randf_range(0.0, 0.35),
			randf_range(-0.25, 0.25)
		)

		var spread := Vector3(
			randf_range(-4.0, 4.0),
			randf_range(2.5, 7.0),
			randf_range(-4.0, 4.0)
		)
		rb.linear_velocity = base_vel * 0.6 + spread
		rb.angular_velocity = Vector3(
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0)
		)

		# Auto-free em 5s
		get_tree().create_timer(5.0).timeout.connect(
			func(): if is_instance_valid(rb): rb.queue_free()
		)

# ─── Sistema L — Blood Decal ──────────────────────────────────────────────────

func _spawn_blood_decal(min_size: float = 1.0, max_size: float = 2.2, offset: Vector3 = Vector3.ZERO) -> void:
	var decal := Decal.new()
	var s := randf_range(min_size, max_size)
	decal.size = Vector3(s, 1.0, s * randf_range(0.75, 1.35))
	decal.rotation_degrees.y = randf() * 360.0
	if _blood_textures.size() > 0:
		decal.texture_albedo = _blood_textures[randi() % _blood_textures.size()]
	get_tree().current_scene.add_child(decal)
	var pos := global_position + offset
	pos.y = 0.05
	decal.global_position = pos
	get_tree().create_timer(20.0).timeout.connect(
		func(): if is_instance_valid(decal): decal.queue_free()
	)
