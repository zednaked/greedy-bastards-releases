extends Node
# Autoload — add to Project > Autoload as "NetworkManager"

const PORT := 7777
const MAX_CLIENTS := 3  # host + 3 = 4 jogadores

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed
signal connection_succeeded

# true apenas em sessões de rede ativas (false em single player)
var is_multiplayer_session := false

# Peers conectados (sem contar o host)
var connected_peers: Array[int] = []

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkManager: falha ao hospedar na porta %d (erro %d)" % [PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	is_multiplayer_session = true
	connected_peers.clear()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("NetworkManager: hospedando na porta %d" % PORT)

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("NetworkManager: falha ao conectar em %s:%d (erro %d)" % [ip, PORT, err])
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_multiplayer_session = true
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("NetworkManager: conectando em %s:%d" % [ip, PORT])

func close() -> void:
	is_multiplayer_session = false
	connected_peers.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	# Desconecta sinais para evitar erros em reconexão
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)

func start_game() -> void:
	if not multiplayer.is_server():
		return
	# Clientes carregam a cena; o host já está nela (só descarta o overlay)
	rpc("_rpc_load_game")

# ─── RPCs ──────────────────────────────────────────────────────────────────────

@rpc("authority", "call_remote", "reliable")
func _rpc_load_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Cliente avisa o servidor que terminou de carregar a cena
@rpc("any_peer", "reliable")
func _rpc_client_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	print("NetworkManager: peer %d pronto, spawnando jogador" % peer_id)
	# Spawn do jogador para todos os peers (call_local: servidor também cria)
	var angle := randf() * TAU
	var r := 8.0
	rpc("_rpc_spawn_player", peer_id, cos(angle) * r, sin(angle) * r)

# Spawna um jogador em todos os peers com a autoridade correta
@rpc("authority", "call_local", "reliable")
func _rpc_spawn_player(peer_id: int, pos_x: float, pos_z: float) -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	if scene == null:
		return
	var p := scene.instantiate()
	p.name = "Player_%d" % peer_id
	p.set_multiplayer_authority(peer_id)
	get_tree().current_scene.add_child(p)
	p.global_position = Vector3(pos_x, 0.5, pos_z)
	print("NetworkManager: jogador %d spawnado" % peer_id)

# ─── Callbacks internos ────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	connected_peers.append(id)
	print("NetworkManager: peer %d conectou" % id)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	print("NetworkManager: peer %d desconectou" % id)
	peer_disconnected.emit(id)
	# Remove o nó do jogador desconectado (em todos os peers)
	if is_instance_valid(get_tree().current_scene):
		var player_node := get_tree().current_scene.get_node_or_null("Player_%d" % id)
		if player_node:
			player_node.queue_free()

func _on_connected_to_server() -> void:
	print("NetworkManager: conectado ao servidor!")
	connection_succeeded.emit()
	# Não spawna o player ainda — aguarda "INICIAR PARTIDA" → cena recarregar → enemy_spawner._ready

func _on_connection_failed() -> void:
	print("NetworkManager: falha na conexão")
	is_multiplayer_session = false
	multiplayer.multiplayer_peer = null
	connection_failed.emit()
