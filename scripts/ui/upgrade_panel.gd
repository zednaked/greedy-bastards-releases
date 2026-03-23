extends CanvasLayer

var chest: Node = null  # set by chest before adding to scene

const UPGRADES: Array[Dictionary] = [
	{"id": "heal",       "name": "Pocao de Vida",   "desc": "Recupera 2 HP",                    "cost": 3},
	{"id": "max_hp",     "name": "Vida Extra",       "desc": "+1 HP maximo, cura total",          "cost": 8},
	{"id": "atk_speed",  "name": "Furia",            "desc": "Ataque 15% mais rapido",            "cost": 5},
	{"id": "knockback",  "name": "Forca Bruta",      "desc": "Knockback +25%",                   "cost": 5},
	{"id": "dash_cd",    "name": "Agilidade",        "desc": "Dash 0.12s mais rapido",            "cost": 4},
	{"id": "iframes",    "name": "Reflexos",         "desc": "+0.3s de invencibilidade",          "cost": 4},
	{"id": "lunge",      "name": "Investida",        "desc": "Avanco do ataque mais forte",       "cost": 3},
	{"id": "bloodlust",  "name": "Vampirismo",       "desc": "Kill com combo 2+ cura 1 HP",       "cost": 6},
	{"id": "magnet",     "name": "Ganancia",         "desc": "Raio de coleta de moedas 3x",       "cost": 2},
	{"id": "armor",      "name": "Armadura",         "desc": "Sem arma: dano recebido 1.5x",     "cost": 7},
]

const UPGRADE_CATEGORY: Dictionary = {
	"heal":      {"color": Color(0.2, 0.8, 0.3),  "icon": "\u271a"},
	"max_hp":    {"color": Color(0.2, 0.8, 0.3),  "icon": "\u2665"},
	"atk_speed": {"color": Color(0.9, 0.3, 0.1),  "icon": "\u26a1"},
	"knockback": {"color": Color(0.9, 0.3, 0.1),  "icon": "\u2694"},
	"dash_cd":   {"color": Color(0.3, 0.6, 1.0),  "icon": "\u226b"},
	"iframes":   {"color": Color(0.3, 0.6, 1.0),  "icon": "\u25c8"},
	"lunge":     {"color": Color(0.9, 0.3, 0.1),  "icon": "\u2197"},
	"bloodlust": {"color": Color(0.7, 0.1, 0.1),  "icon": "\u2666"},
	"magnet":    {"color": Color(1.0, 0.85, 0.2), "icon": "\u25cf"},
	"armor":     {"color": Color(0.5, 0.5, 0.7),  "icon": "\u25a3"},
}

var _player: Node
var _selected_upgrades: Array[Dictionary] = []
var _buy_buttons: Array[Button] = []

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = get_tree().get_first_node_in_group("player")

	var pool := UPGRADES.duplicate()
	pool.shuffle()
	var player_hp = _player.get("health") if _player else 999
	if player_hp != null and player_hp <= 1:
		var heal_candidates := UPGRADES.filter(func(u): return u.id == "heal")
		if not heal_candidates.is_empty():
			var heal_upg = heal_candidates[0]
			if not pool.slice(0, 3).any(func(u): return u.id == "heal"):
				pool.erase(heal_upg)
				pool.push_front(heal_upg)
	_selected_upgrades = pool.slice(0, 3)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var ot := create_tween()
	ot.tween_property(overlay, "color:a", 0.72, 0.2)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "\u2726  BAU DA WAVE  \u2726"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.0))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	# Gold separator
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(560, 1)
	sep.color = Color(1.0, 0.78, 0.15, 0.55)
	vbox.add_child(sep)

	# Coins
	var current_coins: int = _player.get("coins") if _player else 0
	var coins_lbl := Label.new()
	coins_lbl.text = "\u25cf  %d moedas" % current_coins
	coins_lbl.name = "CoinsLabel"
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 20)
	coins_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(coins_lbl)

	# Cards row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for i in _selected_upgrades.size():
		var card := _make_card(_selected_upgrades[i])
		card.modulate.a = 0.0
		card.scale = Vector2(0.82, 0.82)
		card.pivot_offset = Vector2(110, 130)
		hbox.add_child(card)
		var delay := i * 0.1
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "scale", Vector2(1.04, 1.04), 0.20)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "scale", Vector2.ONE, 0.08)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Fechar  \u2192  Proxima Wave"
	close_btn.add_theme_font_size_override("font_size", 20)
	_style_button(close_btn, Color(0.45, 0.12, 0.1))
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

func _style_button(btn: Button, accent: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.05, 0.05)
	n.border_color = accent
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.content_margin_left = 16; n.content_margin_right = 16
	n.content_margin_top = 8;   n.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.18, 0.08, 0.06)
	h.border_color = accent.lightened(0.3)
	h.set_border_width_all(1)
	h.set_corner_radius_all(3)
	h.content_margin_left = 16; h.content_margin_right = 16
	h.content_margin_top = 8;   h.content_margin_bottom = 8
	btn.add_theme_stylebox_override("hover", h)

	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.07, 0.03, 0.03)
	p.border_color = accent
	p.set_border_width_all(1)
	p.set_corner_radius_all(3)
	p.content_margin_left = 16; p.content_margin_right = 16
	p.content_margin_top = 8;   p.content_margin_bottom = 8
	btn.add_theme_stylebox_override("pressed", p)

func _make_card(upg: Dictionary) -> PanelContainer:
	var cat: Dictionary = UPGRADE_CATEGORY.get(upg.id, {"color": Color(0.5, 0.5, 0.5), "icon": "?"})
	var cat_color: Color = cat.color
	var cat_icon: String = cat.icon

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 260)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.04)
	sb.border_color = cat_color
	sb.set_border_width_all(0)
	sb.border_width_top = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 14;  sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	var icon_lbl := Label.new()
	icon_lbl.text = cat_icon
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.add_theme_color_override("font_color", cat_color)
	inner.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = upg.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upg.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	inner.add_child(desc_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	var cost: int = upg.cost
	var btn := Button.new()
	btn.text = ("\u25cf GRATIS" if cost == 0 else "\u25cf %d" % cost)
	btn.add_theme_font_size_override("font_size", 18)
	var coins: int = _player.get("coins") if _player else 0
	btn.disabled = coins < cost
	_style_button(btn, cat_color)
	btn.pressed.connect(_buy.bind(upg, btn))
	inner.add_child(btn)
	_buy_buttons.append(btn)

	return panel

func _buy(upg: Dictionary, btn: Button) -> void:
	btn.disabled = true
	var cost: int = upg.cost
	var current_coins: int = _player.get("coins") if _player else 0
	if current_coins < cost:
		btn.disabled = current_coins < cost
		return
	if _player and _player.has_method("apply_upgrade"):
		_player.apply_upgrade(upg.id)
	if _player:
		_player.set("coins", current_coins - cost)
	btn.text = "\u2713 Comprado"
	btn.disabled = true
	_refresh_coins_display()

func _refresh_coins_display() -> void:
	var current_coins: int = _player.get("coins") if _player else 0
	var coins_lbl := find_child("CoinsLabel", true, false) as Label
	if coins_lbl:
		coins_lbl.text = "\u25cf  %d moedas" % current_coins
	for i in _buy_buttons.size():
		if _buy_buttons[i].disabled:
			continue
		var cost: int = _selected_upgrades[i].cost
		_buy_buttons[i].disabled = current_coins < cost
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_coins"):
		hud.set_coins(current_coins)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()

func _close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if chest and is_instance_valid(chest):
		chest.close_chest()
	else:
		get_tree().paused = false
	queue_free()
