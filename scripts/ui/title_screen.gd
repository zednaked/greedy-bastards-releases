extends Control

var _ip_field: LineEdit
var _status_label: Label
var _start_btn: Button   # só visível no host quando há peers

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)

func _build_ui() -> void:
	var vbox := $VBox

	# Esconde o botão original "ENTRAR NA ARENA"
	var old_start := vbox.get_node_or_null("StartBtn")
	if old_start:
		old_start.visible = false

	# ── Botão single player ──────────────────────────────────────────────
	var solo_btn := Button.new()
	solo_btn.text = "[ JOGAR SOZINHO ]"
	solo_btn.add_theme_font_size_override("font_size", 28)
	solo_btn.pressed.connect(_on_solo)
	vbox.add_child(solo_btn)
	vbox.move_child(solo_btn, vbox.get_child_count() - 2)  # acima do QuitBtn

	# ── Separador visual ─────────────────────────────────────────────────
	var sep_label := Label.new()
	sep_label.text = "── MULTIJOGADOR ──"
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_label.add_theme_font_size_override("font_size", 14)
	sep_label.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(sep_label)
	vbox.move_child(sep_label, vbox.get_child_count() - 2)

	# ── Botão Hospedar ───────────────────────────────────────────────────
	var host_btn := Button.new()
	host_btn.text = "[ HOSPEDAR JOGO ]"
	host_btn.add_theme_font_size_override("font_size", 22)
	host_btn.pressed.connect(_on_host)
	vbox.add_child(host_btn)
	vbox.move_child(host_btn, vbox.get_child_count() - 2)

	# ── Campo de IP ──────────────────────────────────────────────────────
	_ip_field = LineEdit.new()
	_ip_field.placeholder_text = "IP do host (ex: 192.168.1.10)"
	_ip_field.text = "127.0.0.1"
	_ip_field.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ip_field.add_theme_font_size_override("font_size", 18)
	_ip_field.custom_minimum_size = Vector2(320, 0)
	vbox.add_child(_ip_field)
	vbox.move_child(_ip_field, vbox.get_child_count() - 2)

	# ── Botão Entrar ─────────────────────────────────────────────────────
	var join_btn := Button.new()
	join_btn.text = "[ ENTRAR EM JOGO ]"
	join_btn.add_theme_font_size_override("font_size", 22)
	join_btn.pressed.connect(_on_join)
	vbox.add_child(join_btn)
	vbox.move_child(join_btn, vbox.get_child_count() - 2)

	# ── Status / lobby ───────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.modulate = Color(0.85, 0.75, 0.3)
	vbox.add_child(_status_label)
	vbox.move_child(_status_label, vbox.get_child_count() - 2)

	# ── Botão Iniciar (só para o host) ───────────────────────────────────
	_start_btn = Button.new()
	_start_btn.text = "[ INICIAR PARTIDA ]"
	_start_btn.add_theme_font_size_override("font_size", 22)
	_start_btn.visible = false
	_start_btn.pressed.connect(_on_start_mp)
	vbox.add_child(_start_btn)
	vbox.move_child(_start_btn, vbox.get_child_count() - 2)

	solo_btn.grab_focus()

# ─── Ações ────────────────────────────────────────────────────────────────────

func _on_solo() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_host() -> void:
	NetworkManager.host_game()
	_status_label.text = "Aguardando jogadores na porta %d…\nSeu IP local: %s" % [
		NetworkManager.PORT,
		_get_local_ip()
	]

func _on_join() -> void:
	var ip := _ip_field.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	_status_label.text = "Conectando em %s…" % ip
	NetworkManager.join_game(ip)

func _on_start_mp() -> void:
	NetworkManager.start_game()

# ─── Callbacks de rede ────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	var count := NetworkManager.connected_peers.size()
	_status_label.text = "Jogadores conectados: %d\nAguardando mais ou clique Iniciar." % (count + 1)
	_start_btn.visible = multiplayer.is_server()

func _on_peer_disconnected(_id: int) -> void:
	var count := NetworkManager.connected_peers.size()
	_status_label.text = "Jogadores conectados: %d" % (count + 1)
	if count == 0:
		_start_btn.visible = false

func _on_connected() -> void:
	_status_label.text = "Conectado! Aguardando o host iniciar…"

func _on_connection_failed() -> void:
	_status_label.text = "Falha na conexão. Verifique o IP e tente novamente."

# ─── Utilidade ────────────────────────────────────────────────────────────────

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func _exit_tree() -> void:
	if NetworkManager.peer_connected.is_connected(_on_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_peer_disconnected)
	if NetworkManager.connection_succeeded.is_connected(_on_connected):
		NetworkManager.connection_succeeded.disconnect(_on_connected)
	if NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)
