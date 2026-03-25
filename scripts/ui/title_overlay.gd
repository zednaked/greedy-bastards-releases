extends CanvasLayer

var _status_label: Label
var _start_btn: Button   # "INICIAR PARTIDA" — só no host com peers

func _ready() -> void:
	# Servidor dedicado: sem UI, aguarda jogadores conectarem
	if NetworkManager.is_dedicated_server:
		get_tree().paused = false
		queue_free()
		return
	# Cliente entrando numa sessão já iniciada: pula o menu e vai direto para o jogo
	if NetworkManager.is_multiplayer_session and not multiplayer.is_server():
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		queue_free()
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_ui()
	_build_mp_buttons()
	$Panel/StartBtn.pressed.connect(_start_solo)
	$Panel/QuitBtn.pressed.connect(get_tree().quit)
	$Panel/StartBtn.grab_focus()
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)

func _build_mp_buttons() -> void:
	var panel := $Panel

	# Renomeia o botão original para "JOGAR SOZINHO"
	$Panel/StartBtn.text = "JOGAR SOZINHO"

	# ── Separador ────────────────────────────────────────────────────────
	var sep := Label.new()
	sep.text = "── MULTIJOGADOR ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 13)
	sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel.add_child(sep)
	panel.move_child(sep, $Panel/StartBtn.get_index() + 1)

	# ── Hospedar ─────────────────────────────────────────────────────────
	var host_btn := Button.new()
	host_btn.text = "HOSPEDAR JOGO"
	host_btn.add_theme_font_size_override("font_size", 22)
	host_btn.pressed.connect(_on_host)
	_style_start_btn(host_btn)
	panel.add_child(host_btn)
	panel.move_child(host_btn, sep.get_index() + 1)

	# ── Campo de IP ───────────────────────────────────────────────────────
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	panel.add_child(ip_row)
	panel.move_child(ip_row, host_btn.get_index() + 1)

	var ip_field := LineEdit.new()
	ip_field.name = "IPField"
	ip_field.placeholder_text = "IP do host"
	ip_field.text = "127.0.0.1"
	ip_field.add_theme_font_size_override("font_size", 18)
	ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(ip_field)

	var join_btn := Button.new()
	join_btn.text = "ENTRAR"
	join_btn.add_theme_font_size_override("font_size", 20)
	join_btn.pressed.connect(func(): _on_join(ip_field.text))
	_style_start_btn(join_btn)
	ip_row.add_child(join_btn)

	# ── Status ────────────────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.custom_minimum_size = Vector2(400, 0)
	panel.add_child(_status_label)
	panel.move_child(_status_label, ip_row.get_index() + 1)

	# ── Iniciar partida (host) ─────────────────────────────────────────────
	_start_btn = Button.new()
	_start_btn.text = "INICIAR PARTIDA"
	_start_btn.add_theme_font_size_override("font_size", 24)
	_start_btn.visible = false
	_start_btn.pressed.connect(_on_start_mp)
	_style_start_btn(_start_btn)
	panel.add_child(_start_btn)
	panel.move_child(_start_btn, _status_label.get_index() + 1)

# ─── Ações ────────────────────────────────────────────────────────────────────

func _start_solo() -> void:
	_dismiss()

func _on_host() -> void:
	NetworkManager.host_game()
	_status_label.text = "Porta %d • IP local: %s" % [NetworkManager.PORT, _get_local_ip()]

func _on_join(ip: String) -> void:
	var clean := ip.strip_edges()
	if clean.is_empty():
		clean = "127.0.0.1"
	_status_label.text = "Conectando em %s…" % clean
	NetworkManager.join_game(clean)

func _on_start_mp() -> void:
	NetworkManager.start_game()
	_dismiss()

# ─── Callbacks de rede ────────────────────────────────────────────────────────

func _on_peer_connected(_id: int) -> void:
	var n := NetworkManager.connected_peers.size() + 1  # host + clientes
	_status_label.text = "%d jogadores conectados" % n
	if multiplayer.is_server():
		_start_btn.visible = true

func _on_peer_disconnected(_id: int) -> void:
	var n := NetworkManager.connected_peers.size() + 1
	_status_label.text = "%d jogadores conectados" % n
	if NetworkManager.connected_peers.is_empty():
		_start_btn.visible = false

func _on_connected() -> void:
	_status_label.text = "Conectado! Aguardando o host iniciar…"

func _on_connection_failed() -> void:
	_status_label.text = "Falha na conexão. Verifique o IP."

# ─── Dismiss ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not NetworkManager.is_multiplayer_session:
		_start_solo()

func _dismiss() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var t := create_tween()
	t.tween_property($Dim, "color:a", 0.0, 0.4)
	t.parallel().tween_property($Panel, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)

func _exit_tree() -> void:
	if NetworkManager.peer_connected.is_connected(_on_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_peer_disconnected)
	if NetworkManager.connection_succeeded.is_connected(_on_connected):
		NetworkManager.connection_succeeded.disconnect(_on_connected)
	if NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)

# ─── Utilitário ───────────────────────────────────────────────────────────────

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func _style_ui() -> void:
	$Panel/Title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.85))
	$Panel/Title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01))
	$Panel/Title.add_theme_constant_override("outline_size", 8)

	var sub := $Panel/Subtitle
	sub.add_theme_color_override("font_color", Color(0.88, 0.50, 0.25))
	sub.modulate.a = 0.7
	var tp := create_tween().set_loops()
	tp.tween_property(sub, "modulate:a", 1.0, 1.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tp.tween_property(sub, "modulate:a", 0.7, 1.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	$Panel/Subtitle2.visible = false
	var credit := Label.new()
	credit.text = "by ZeD"
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.55))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.offset_left   = -110.0
	credit.offset_top    = -30.0
	credit.offset_right  = -14.0
	credit.offset_bottom = -12.0
	anchor.add_child(credit)

	_style_start_btn($Panel/StartBtn)
	$Panel/QuitBtn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))

func _style_start_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.04, 0.04)
	n.border_color = Color(0.72, 0.14, 0.1)
	n.set_border_width_all(2)
	n.set_corner_radius_all(3)
	n.content_margin_left = 28; n.content_margin_right = 28
	n.content_margin_top = 13;  n.content_margin_bottom = 13
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.14, 0.07, 0.03)
	h.border_color = Color(1.0, 0.80, 0.18)
	h.set_border_width_all(2)
	h.set_corner_radius_all(3)
	h.content_margin_left = 28; h.content_margin_right = 28
	h.content_margin_top = 13;  h.content_margin_bottom = 13
	btn.add_theme_stylebox_override("hover", h)

	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.05, 0.02, 0.02)
	p.border_color = Color(0.72, 0.14, 0.1)
	p.set_border_width_all(2)
	p.set_corner_radius_all(3)
	p.content_margin_left = 28; p.content_margin_right = 28
	p.content_margin_top = 13;  p.content_margin_bottom = 13
	btn.add_theme_stylebox_override("pressed", p)
