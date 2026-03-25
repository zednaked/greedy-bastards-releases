extends Node3D

@export var goblin_scene: PackedScene
@export var chest_scene: PackedScene
@export var spawn_radius: float = 15.0

@export_group("Waves")
@export var goblins_wave_1: int = 3
@export var goblins_per_wave_increase: int = 2
@export var spawn_interval: float = 0.8
@export var between_waves_delay: float = 5.5

@export_group("Tipos de Goblin")
@export var leader_unlock_wave: int = 2
@export var ranged_unlock_wave: int = 4
@export var ranged_chance: float = 0.12
@export var bomber_unlock_wave: int = 6
@export var bomber_chance: float = 0.06
@export var trapper_unlock_wave: int = 8
@export var trapper_chance: float = 0.04

@export_group("Escalagem de Dificuldade")
@export var wave_scale_cap: int = 15
@export var speed_per_wave: float = 0.07
@export var attack_cd_reduction_per_wave: float = 0.04
@export var attack_cd_min: float = 0.90
@export var hp4_wave: int = 8
@export var hp5_wave: int = 12
@export var damage2_wave: int = 9
@export var extra_attacker_wave: int = 4

var _wave: int = 0
var _to_spawn: int = 0
var _spawned: int = 0
var _player: Node3D
var _timer: float = 1.0  # delay inicial antes da wave 1

# Estados: idle | spawning | waiting | cooldown
var _state: String = "idle"

var _cages: Array = []
var _eid_counter: int = 0  # ID único por inimigo (para sincronizar com clientes)

func _ready() -> void:
	add_to_group("spawner")
	_player = get_tree().get_first_node_in_group("player")
	EnemyController.reset_token_pool()
	_cache_cages()
	# Multiplayer: cliente avisa servidor que terminou de carregar
	if NetworkManager.is_multiplayer_session and not multiplayer.is_server():
		NetworkManager.rpc_id(1, "_rpc_client_ready")

func _cache_cages() -> void:
	_cages.clear()
	var props := get_tree().current_scene.get_node_or_null("Props")
	if props == null:
		return
	for child in props.get_children():
		if child.name.begins_with("cage"):
			_cages.append(child)

func _process(delta: float) -> void:
	# Em multiplayer, apenas o servidor controla o spawner
	if NetworkManager.is_multiplayer_session and not multiplayer.is_server():
		return
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
	return goblins_wave_1 + (w - 1) * goblins_per_wave_increase

func _is_blocked(pos: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("block_spawn"):
		if node.global_position.distance_to(pos) < 3.5:
			return true
	return false

func _get_cage_spawn() -> Vector3:
	if _cages.is_empty():
		return Vector3.ZERO
	var cage := _cages[randi() % _cages.size()] as Node3D
	# Spawn na borda interna da cage (lado que dá para o centro da arena)
	var flat := Vector2(cage.global_position.x, cage.global_position.z)
	var inward := (-flat).normalized()
	var offset := Vector3(inward.x, 0.0, inward.y) * 1.6
	return cage.global_position + offset + Vector3(0, 0.1, 0)

func _spawn_one() -> void:
	if goblin_scene == null:
		return
	# Atualiza referência do jogador (pode haver múltiplos em CO-OP)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return

	var pos: Vector3
	var use_cage := _spawned >= 2 and not _cages.is_empty() and randf() < 0.60

	if use_cage:
		pos = _get_cage_spawn()
		# Sem _is_blocked — spawna intencionalmente na borda da cage
	else:
		var angle: float
		if _spawned < 2:
			var behind := atan2(-_player.global_transform.basis.z.x,
								-_player.global_transform.basis.z.z) + PI
			angle = behind + randf_range(-0.4, 0.4)
		else:
			angle = randf() * TAU
		var radius := randf_range(13.0, 17.0)
		pos = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		pos.y = _player.global_position.y + 0.1
		var attempts := 0
		while _is_blocked(pos) and attempts < 8:
			angle = randf() * TAU
			radius = randf_range(13.0, 17.0)
			pos = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
			pos.y = _player.global_position.y + 0.1
			attempts += 1
		# Se todas as posições aleatórias estão bloqueadas, usa cage como fallback
		if _is_blocked(pos) and not _cages.is_empty():
			pos = _get_cage_spawn()

	_eid_counter += 1
	var eid := _eid_counter
	var spd_mult := randf_range(0.85, 1.15)
	var scl_mult := randf_range(0.88, 1.12)
	var run_t := randf() * TAU
	var type_roll := randf()
	var is_ranged_type := _wave >= ranged_unlock_wave and type_roll < ranged_chance
	var is_bomber_type := not is_ranged_type and _wave >= bomber_unlock_wave and type_roll < bomber_chance
	var is_trapper_type := not is_ranged_type and not is_bomber_type and _wave >= trapper_unlock_wave and type_roll < trapper_chance
	var is_leader_type := _wave >= leader_unlock_wave and _spawned == 0 and not EnemyController._wave_has_leader

	var enemy := goblin_scene.instantiate()
	enemy.name = "Enemy_%d" % eid
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos

	enemy.speed *= spd_mult
	if enemy.goblin_mesh != null:
		enemy.goblin_mesh.scale = enemy.goblin_mesh.scale * scl_mult
	enemy.run_time = run_t
	enemy.apply_wave_scaling(_wave, _scaling_config())
	if is_ranged_type:
		enemy.is_ranged = true
		enemy.speed *= 0.85
	elif is_bomber_type:
		enemy.is_bomber = true
		enemy.speed *= 0.80
	elif is_trapper_type:
		enemy.setup_trapper()
		enemy.speed *= 0.70
	if is_leader_type:
		enemy.promote_to_leader()

	# Multiplayer: notifica clientes para criar puppet do mesmo inimigo
	if NetworkManager.is_multiplayer_session:
		var cfg := {
			"spd": spd_mult, "scl": scl_mult, "run_t": run_t,
			"wave": _wave, "ranged": is_ranged_type, "bomber": is_bomber_type,
			"trapper": is_trapper_type, "leader": is_leader_type,
			"cage": use_cage
		}
		rpc("_net_client_spawn", eid, pos, cfg)

	# Efeito de emergência da jaula — após todo o setup de escala/stats
	if use_cage:
		enemy.emerge_from_cage()

func _scaling_config() -> Dictionary:
	return {
		"scale_cap": wave_scale_cap,
		"speed_per_wave": speed_per_wave,
		"attack_cd_reduction": attack_cd_reduction_per_wave,
		"attack_cd_min": attack_cd_min,
		"hp4_wave": hp4_wave,
		"hp5_wave": hp5_wave,
		"damage2_wave": damage2_wave,
		"extra_attacker_wave": extra_attacker_wave,
	}

func _notify_hud_wave() -> void:
	if NetworkManager.is_multiplayer_session:
		rpc("_net_hud_set_wave", _wave, _to_spawn)
	else:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_wave"):
			hud.set_wave(_wave, _to_spawn)

func _notify_hud_wave_clear() -> void:
	if NetworkManager.is_multiplayer_session:
		rpc("_net_hud_wave_clear")
	else:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_wave_clear"):
			hud.show_wave_clear()
	_spawn_chest()

# ─── RPCs de Multiplayer ──────────────────────────────────────────────────────

# Servidor → clientes: spawn de puppet (cópia visual sem IA)
@rpc("authority", "call_remote", "reliable")
func _net_client_spawn(eid: int, pos: Vector3, cfg: Dictionary) -> void:
	if goblin_scene == null:
		return
	var enemy := goblin_scene.instantiate()
	enemy.name = "Enemy_%d" % eid
	enemy.set_meta("is_net_puppet", true)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos
	enemy.speed *= cfg.get("spd", 1.0)
	if enemy.goblin_mesh != null:
		enemy.goblin_mesh.scale = enemy.goblin_mesh.scale * cfg.get("scl", 1.0)
	enemy.run_time = cfg.get("run_t", 0.0)
	enemy.apply_wave_scaling(cfg.get("wave", 1), _scaling_config())
	if cfg.get("ranged", false):
		enemy.is_ranged = true
	elif cfg.get("bomber", false):
		enemy.is_bomber = true
	elif cfg.get("trapper", false):
		enemy.setup_trapper()
	if cfg.get("leader", false):
		enemy.promote_to_leader()
	if cfg.get("cage", false):
		enemy.emerge_from_cage()

# Servidor → todos: wave announcement
@rpc("authority", "call_local", "reliable")
func _net_hud_set_wave(wave: int, count: int) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_wave"):
		hud.set_wave(wave, count)

# Servidor → todos: wave clear
@rpc("authority", "call_local", "reliable")
func _net_hud_wave_clear() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_wave_clear"):
		hud.show_wave_clear()

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
