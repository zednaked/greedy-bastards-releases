extends CanvasLayer

var chest: Node = null  # set by chest before adding to scene

const UPGRADES: Array[Dictionary] = [
	{"id": "heal",       "name": "Pocao de Vida",   "desc": "Recupera 2 HP",                    "cost": 3,  "icon": "[HP]"},
	{"id": "max_hp",     "name": "Vida Extra",       "desc": "+1 HP maximo, cura total",          "cost": 8,  "icon": "[HP+]"},
	{"id": "atk_speed",  "name": "Furia",            "desc": "Ataque 15% mais rapido",            "cost": 5,  "icon": "[ATK]"},
	{"id": "knockback",  "name": "Forca Bruta",      "desc": "Knockback +25%",                   "cost": 5,  "icon": "[KB]"},
	{"id": "dash_cd",    "name": "Agilidade",        "desc": "Dash 0.12s mais rapido",            "cost": 4,  "icon": "[DASH]"},
	{"id": "iframes",    "name": "Reflexos",         "desc": "+0.3s de invencibilidade",          "cost": 4,  "icon": "[DEF]"},
	{"id": "lunge",      "name": "Investida",        "desc": "Avanco do ataque mais forte",       "cost": 3,  "icon": "[RUN]"},
	{"id": "bloodlust",  "name": "Vampirismo",       "desc": "Kill com combo 2+ cura 1 HP",       "cost": 6,  "icon": "[VMP]"},
	{"id": "magnet",     "name": "Ganancia",         "desc": "Raio de coleta de moedas 3x",       "cost": 2,  "icon": "[COIN]"},
	{"id": "armor",      "name": "Armadura",         "desc": "Sem arma: dano recebido 1.5x",     "cost": 7,  "icon": "[ARM]"},
]

var _player: Node
var _selected_upgrades: Array[Dictionary] = []
var _buy_buttons: Array[Button] = []

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = get_tree().get_first_node_in_group("player")

	# Pick 3 upgrades — guarantee "heal" if player at 1 HP
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	var player_hp = _player.get("health") if _player else 999
	# Ensure heal is in list when low HP
	if player_hp != null and player_hp <= 1:
		var heal_upg = UPGRADES[0]  # heal is index 0
		if not pool.slice(0, 3).any(func(u): return u.id == "heal"):
			pool.erase(heal_upg)
			pool.push_front(heal_upg)
	_selected_upgrades = pool.slice(0, 3)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()

func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Main container — centered
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "* BAU DA WAVE *"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	# Coins display
	var coins_lbl := Label.new()
	var current_coins: int = _player.get("coins") if _player else 0
	coins_lbl.text = "[COIN] %d moedas" % current_coins
	coins_lbl.name = "CoinsLabel"
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 22)
	coins_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(coins_lbl)

	# Cards row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for upg in _selected_upgrades:
		hbox.add_child(_make_card(upg))

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Fechar  ->  Proxima Wave"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

func _make_card(upg: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 240)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	# Add margin
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	vb.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	margin.add_child(inner)

	var icon_lbl := Label.new()
	icon_lbl.text = upg.get("icon", "*")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	inner.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = upg.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upg.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	inner.add_child(desc_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	var cost: int = upg.cost
	var btn := Button.new()
	btn.text = ("GRATIS" if cost == 0 else "[COIN] %d" % cost)
	btn.add_theme_font_size_override("font_size", 18)
	var current_coins: int = _player.get("coins") if _player else 0
	btn.disabled = current_coins < cost
	btn.pressed.connect(_buy.bind(upg, btn))
	inner.add_child(btn)
	_buy_buttons.append(btn)

	return panel

func _buy(upg: Dictionary, btn: Button) -> void:
	var cost: int = upg.cost
	var current_coins: int = _player.get("coins") if _player else 0
	if current_coins < cost:
		return
	if _player and _player.has_method("apply_upgrade"):
		_player.apply_upgrade(upg.id)
	# Deduct coins
	if _player:
		_player.set("coins", current_coins - cost)
	btn.text = "V Comprado"
	btn.disabled = true
	# Refresh all button states + coin label
	_refresh_coins_display()

func _refresh_coins_display() -> void:
	var current_coins: int = _player.get("coins") if _player else 0
	# Update coins label
	var coins_lbl := find_child("CoinsLabel", true, false) as Label
	if coins_lbl:
		coins_lbl.text = "[COIN] %d moedas" % current_coins
	# Re-enable/disable buy buttons
	for i in _buy_buttons.size():
		if _buy_buttons[i].disabled:
			continue
		var cost: int = _selected_upgrades[i].cost
		_buy_buttons[i].disabled = current_coins < cost
	# Notify hud
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_coins"):
		hud.set_coins(current_coins)

func _close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if chest and is_instance_valid(chest):
		chest.close_chest()
	else:
		get_tree().paused = false
	queue_free()
