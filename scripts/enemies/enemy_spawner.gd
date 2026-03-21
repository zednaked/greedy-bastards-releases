extends Node3D

@export var goblin_scene: PackedScene
@export var chest_scene: PackedScene
@export var spawn_radius: float = 15.0

@export_group("Waves")
@export var goblins_wave_1: int = 3
@export var goblins_per_wave_increase: int = 2
@export var spawn_interval: float = 0.8
@export var between_waves_delay: float = 4.0

var _wave: int = 0
var _to_spawn: int = 0
var _spawned: int = 0
var _player: Node3D
var _timer: float = 1.0  # delay inicial antes da wave 1

# Estados: idle | spawning | waiting | cooldown
var _state: String = "idle"

func _ready() -> void:
	add_to_group("spawner")
	_player = get_tree().get_first_node_in_group("player")
	EnemyController.reset_token_pool()

func _process(delta: float) -> void:
	_timer -= delta
	match _state:
		"idle":
			if _timer <= 0.0:
				_start_next_wave()

		"spawning":
			if _timer <= 0.0:
				if _spawned < _to_spawn:
					_spawn_one()
					_spawned += 1
					_timer = spawn_interval
				else:
					_state = "waiting"

		"waiting":
			# Checa todo frame — não depende de coroutine
			if get_tree().get_nodes_in_group("enemies").size() == 0:
				_notify_hud_wave_clear()
				_state = "cooldown"
				_timer = between_waves_delay

		"cooldown":
			if _timer <= 0.0 and get_tree().get_nodes_in_group("chest").size() == 0:
				_start_next_wave()

func _start_next_wave() -> void:
	_wave += 1
	_to_spawn = _count_for_wave(_wave)
	_spawned = 0
	_state = "spawning"
	_timer = 0.0  # primeira spawn imediata
	_notify_hud_wave()

func _count_for_wave(w: int) -> int:
	# Waves 1-3: cresce +2/wave (3, 5, 7)
	# Waves 4+: cresce +1/wave com teto em 14 (8, 9, 10 ... 14)
	if w <= 3:
		return 3 + (w - 1) * 2
	return mini(7 + (w - 3), 14)

func _is_blocked(pos: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("block_spawn"):
		if node.global_position.distance_to(pos) < 3.5:
			return true
	return false

func _spawn_one() -> void:
	if _player == null or goblin_scene == null:
		return

	var angle: float
	if _spawned < 2:
		var behind := atan2(-_player.global_transform.basis.z.x,
							-_player.global_transform.basis.z.z) + PI
		angle = behind + randf_range(-0.4, 0.4)
	else:
		angle = randf() * TAU

	var radius := randf_range(13.0, 17.0)
	var pos := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	pos.y = _player.global_position.y + 0.1

	var attempts := 0
	while _is_blocked(pos) and attempts < 8:
		angle = randf() * TAU
		radius = randf_range(13.0, 17.0)
		pos = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		pos.y = _player.global_position.y + 0.1
		attempts += 1

	var enemy := goblin_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos

	enemy.speed *= randf_range(0.85, 1.15)
	var s := randf_range(0.88, 1.12)
	if enemy.goblin_mesh != null:
		enemy.goblin_mesh.scale = enemy.goblin_mesh.scale * s
	enemy.run_time = randf() * TAU
	enemy.apply_wave_scaling(_wave)
	# Tipos especiais desbloqueados por wave — mutuamente exclusivos
	# Wave 3+: ranged 15%  | Wave 4+: bomber 8%  | Wave 5+: trapper 6%
	var type_roll := randf()
	if _wave >= 3 and type_roll < 0.15:
		enemy.is_ranged = true
		enemy.speed *= 0.85
	elif _wave >= 4 and type_roll < 0.23:
		enemy.is_bomber = true
		enemy.speed *= 0.80
	elif _wave >= 5 and type_roll < 0.29:
		enemy.setup_trapper()
		enemy.speed *= 0.70
	# First spawn of this wave becomes leader (wave 2+)
	if _wave >= 2 and _spawned == 0 and not EnemyController._wave_has_leader:
		enemy.promote_to_leader()

func _notify_hud_wave() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_wave"):
		hud.set_wave(_wave, _to_spawn)

func _notify_hud_wave_clear() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_wave_clear"):
		hud.show_wave_clear()
	_spawn_chest()

func _spawn_chest() -> void:
	# Remove old chest if any
	for c in get_tree().get_nodes_in_group("chest"):
		c.queue_free()
	var c_scene := chest_scene
	if c_scene == null:
		c_scene = load("res://scenes/economy/chest.tscn") as PackedScene
	if c_scene == null:
		return
	var chest := c_scene.instantiate()
	get_tree().current_scene.add_child(chest)
	chest.global_position = Vector3(0.0, 0.1, 0.0)
