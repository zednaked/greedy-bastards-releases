extends CanvasLayer

@onready var kill_label: Label = $KillCount
@onready var health_label: Label = get_node_or_null("HealthLabel")
@onready var wave_label: Label = get_node_or_null("WaveLabel")
@onready var announce_label: Label = get_node_or_null("AnnounceLabel")
@onready var combo_label: Label = get_node_or_null("ComboLabel")
@onready var vignette: ColorRect = get_node_or_null("Vignette")
@onready var parry_flash: ColorRect = get_node_or_null("ParryFlash")
@onready var coin_label: Label = get_node_or_null("CoinLabel")
@onready var _crosshair: Label = get_node_or_null("Crosshair")

var kills := 0
var _near_death_tween: Tween = null
var _near_death_active: bool = false
var _combo_pop_tween: Tween = null
var _announce_tween: Tween = null
var _combo_decay_bar: ColorRect = null
var _combo_decay_timer: float = 0.0
var _pip_container: HBoxContainer = null
var _pips: Array[PanelContainer] = []
var _pip_style_full: StyleBoxFlat = null
var _pip_style_empty: StyleBoxFlat = null
var _max_health: int = 0
var _prev_health: int = -1

const COMBO_DECAY_TIME: float = 3.5

func _ready() -> void:
	add_to_group("hud")

	# Hide the old text HP label — replaced by pips
	if health_label:
		health_label.visible = false

	# Reposition kill counter to top-right
	if kill_label:
		kill_label.anchor_left   = 1.0
		kill_label.anchor_top    = 0.0
		kill_label.anchor_right  = 1.0
		kill_label.anchor_bottom = 0.0
		kill_label.offset_left   = -170.0
		kill_label.offset_top    = 28.0
		kill_label.offset_right  = -16.0
		kill_label.offset_bottom = 82.0
		kill_label.add_theme_font_size_override("font_size", 44)
		kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kill_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		kill_label.add_theme_color_override("font_outline_color", Color(0.4, 0.05, 0.05))
		kill_label.add_theme_constant_override("outline_size", 4)

	# "K I L L S" subtitle above kill number
	var kills_title := Label.new()
	kills_title.text = "K I L L S"
	kills_title.anchor_left   = 1.0
	kills_title.anchor_top    = 0.0
	kills_title.anchor_right  = 1.0
	kills_title.anchor_bottom = 0.0
	kills_title.offset_left   = -170.0
	kills_title.offset_top    = 10.0
	kills_title.offset_right  = -16.0
	kills_title.offset_bottom = 30.0
	kills_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills_title.add_theme_font_size_override("font_size", 13)
	kills_title.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(kills_title)

	# Wave label — reposition below where HP pips will be
	if wave_label:
		wave_label.anchor_left   = 0.0
		wave_label.anchor_top    = 0.0
		wave_label.anchor_right  = 0.0
		wave_label.anchor_bottom = 0.0
		wave_label.offset_left   = 16.0
		wave_label.offset_top    = 46.0
		wave_label.offset_right  = 240.0
		wave_label.offset_bottom = 70.0
		wave_label.add_theme_font_size_override("font_size", 18)
		wave_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

	# Coin label
	if coin_label == null:
		coin_label = Label.new()
		coin_label.name = "CoinLabel"
		add_child(coin_label)
	coin_label.anchor_left   = 0.0
	coin_label.anchor_top    = 0.0
	coin_label.anchor_right  = 0.0
	coin_label.anchor_bottom = 0.0
	coin_label.offset_left   = 16.0
	coin_label.offset_top    = 72.0
	coin_label.offset_right  = 200.0
	coin_label.offset_bottom = 94.0
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	set_coins(0)

	# Style combo label
	if combo_label:
		combo_label.add_theme_font_size_override("font_size", 42)
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		combo_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.0))
		combo_label.add_theme_constant_override("outline_size", 4)
		await get_tree().process_frame
		combo_label.pivot_offset = combo_label.size / 2.0

	# Combo decay bar (below combo label, bottom-right)
	_combo_decay_bar = ColorRect.new()
	_combo_decay_bar.anchor_left   = 1.0
	_combo_decay_bar.anchor_top    = 1.0
	_combo_decay_bar.anchor_right  = 1.0
	_combo_decay_bar.anchor_bottom = 1.0
	_combo_decay_bar.offset_left   = -220.0
	_combo_decay_bar.offset_top    = -36.0
	_combo_decay_bar.offset_right  = -20.0
	_combo_decay_bar.offset_bottom = -32.0
	_combo_decay_bar.color = Color(1.0, 0.82, 0.2, 0.85)
	_combo_decay_bar.visible = false
	add_child(_combo_decay_bar)

	# Style announce label
	if announce_label:
		announce_label.visible = false
		announce_label.add_theme_font_size_override("font_size", 48)
		announce_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		announce_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.0))
		announce_label.add_theme_constant_override("outline_size", 6)

	# Style wave label — subtle outline for presence
	if wave_label:
		wave_label.add_theme_color_override("font_outline_color", Color(0.35, 0.25, 0.05, 0.7))
		wave_label.add_theme_constant_override("outline_size", 2)

	# Style crosshair — small, discreet, behind all other HUD nodes
	if _crosshair:
		_crosshair.text = "+"
		_crosshair.add_theme_font_size_override("font_size", 13)
		_crosshair.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
		_crosshair.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
		_crosshair.add_theme_constant_override("outline_size", 2)
		_crosshair.pivot_offset = Vector2(6, 6)
		move_child(_crosshair, 0)  # render behind every other HUD element

	update_hud()

func _process(delta: float) -> void:
	if _combo_decay_timer > 0.0:
		_combo_decay_timer -= delta
		if _combo_decay_bar:
			var ratio := maxf(0.0, _combo_decay_timer / COMBO_DECAY_TIME)
			_combo_decay_bar.offset_right = _combo_decay_bar.offset_left + 200.0 * ratio
			if ratio <= 0.0:
				_combo_decay_bar.visible = false

func register_kill() -> void:
	kills += 1
	update_hud()
	if kill_label:
		kill_label.pivot_offset = kill_label.size / 2.0
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		t.tween_property(kill_label, "scale", Vector2(1.6, 1.6), 0.0)
		t.tween_property(kill_label, "scale", Vector2.ONE, 0.5)

func set_health(current: int, maximum: int, flash: bool = true) -> void:
	if health_label:
		health_label.visible = false
	if maximum != _max_health:
		_build_hp_pips(maximum)
	_update_hp_pips(current)
	_prev_health = current
	if flash:
		_flash_vignette(Color(1, 0, 0, 0.55))
	var should_pulse := current <= 1 and current > 0
	if should_pulse and not _near_death_active:
		_start_near_death_pulse()
	elif not should_pulse and _near_death_active:
		_stop_near_death_pulse()

func _build_hp_pips(max_health: int) -> void:
	_max_health = max_health
	if _pip_container:
		_pip_container.queue_free()
		_pip_container = null
	_pips.clear()

	_pip_style_full = StyleBoxFlat.new()
	_pip_style_full.bg_color = Color(0.85, 0.15, 0.12)
	_pip_style_full.border_color = Color(1.0, 0.3, 0.2, 0.6)
	_pip_style_full.set_border_width_all(1)
	_pip_style_full.set_corner_radius_all(2)

	_pip_style_empty = StyleBoxFlat.new()
	_pip_style_empty.bg_color = Color(0.18, 0.05, 0.05)
	_pip_style_empty.border_color = Color(0.4, 0.1, 0.1)
	_pip_style_empty.set_border_width_all(1)
	_pip_style_empty.set_corner_radius_all(2)

	_pip_container = HBoxContainer.new()
	_pip_container.position = Vector2(16, 14)
	_pip_container.add_theme_constant_override("separation", 4)
	add_child(_pip_container)

	for _i in max_health:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(18, 18)
		pip.add_theme_stylebox_override("panel", _pip_style_full)
		_pip_container.add_child(pip)
		_pips.append(pip)

func _update_hp_pips(current: int) -> void:
	for i in _pips.size():
		var pip := _pips[i]
		var is_full := i < current
		pip.add_theme_stylebox_override("panel", _pip_style_full if is_full else _pip_style_empty)
		# Bounce if this pip just changed
		var was_full := _prev_health < 0 or i < _prev_health
		if is_full != was_full:
			pip.scale = Vector2(1.5, 1.5)
			pip.pivot_offset = Vector2(9, 9)
			var t := pip.create_tween()
			t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			t.tween_property(pip, "scale", Vector2.ONE, 0.25)

func _flash_vignette(color: Color) -> void:
	if vignette == null:
		return
	vignette.color = color
	if _near_death_active:
		return
	var t := create_tween()
	t.tween_property(vignette, "color:a", 0.0, 0.7)

func _start_near_death_pulse() -> void:
	_near_death_active = true
	if _near_death_tween:
		_near_death_tween.kill()
	if vignette == null:
		return
	vignette.color = Color(1, 0, 0, 0.0)
	_near_death_tween = create_tween().set_loops()
	_near_death_tween.tween_property(vignette, "color:a", 0.45, 0.6)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_near_death_tween.tween_property(vignette, "color:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_near_death_pulse() -> void:
	_near_death_active = false
	if _near_death_tween:
		_near_death_tween.kill()
		_near_death_tween = null
	if vignette:
		vignette.color.a = 0.0

func set_wave(wave: int, count: int) -> void:
	if wave_label:
		wave_label.text = "WAVE  %d" % wave
		wave_label.scale = Vector2(1.6, 1.6)
		wave_label.pivot_offset = Vector2(55, 11)
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(wave_label, "scale", Vector2.ONE, 0.38)
	_announce(" WAVE %d  \n%d inimigos" % [wave, count])

func show_wave_clear() -> void:
	if wave_label:
		# Briefly flash the static label gold, then back
		var tw := create_tween()
		tw.tween_property(wave_label, "modulate", Color(1.0, 0.9, 0.2), 0.12)
		tw.tween_property(wave_label, "modulate", Color(1, 1, 1), 0.7).set_ease(Tween.EASE_IN)
	_announce("\u2726 WAVE CONCLUIDA \u2726")

func set_combo(n: int) -> void:
	if combo_label == null:
		return
	if n <= 1:
		combo_label.visible = false
		combo_label.scale = Vector2.ONE
		_combo_decay_timer = 0.0
		if _combo_decay_bar:
			_combo_decay_bar.visible = false
		return
	combo_label.text = "x%d COMBO" % n
	combo_label.visible = true
	_combo_decay_timer = COMBO_DECAY_TIME
	if _combo_decay_bar:
		_combo_decay_bar.offset_right = _combo_decay_bar.offset_left + 200.0
		_combo_decay_bar.visible = true
	if _combo_pop_tween:
		_combo_pop_tween.kill()
	combo_label.scale = Vector2(1.4, 1.4)
	_combo_pop_tween = create_tween()
	_combo_pop_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_combo_pop_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.35)

func flash_gold_vignette() -> void:
	_flash_vignette(Color(1.0, 0.85, 0.0, 0.55))

func flash_explosion(intensity: float) -> void:
	if parry_flash == null:
		return
	parry_flash.color = Color(1.0, 0.55, 0.1, intensity)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(parry_flash, "color:a", 0.0, 0.28)

func flash_dash() -> void:
	if vignette == null:
		return
	if _near_death_active:
		return
	vignette.color = Color(0.0, 0.02, 0.08, 0.62)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(vignette, "color:a", 0.0, 0.38)

func flash_hit(is_kill: bool = false) -> void:
	if parry_flash == null:
		return
	parry_flash.color = Color(1.0, 0.88, 0.5, 0.55) if is_kill else Color(1.0, 1.0, 1.0, 0.35)
	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(parry_flash, "color:a", 0.0, 0.06)
	pulse_crosshair()

func flash_parry() -> void:
	if parry_flash == null:
		return
	parry_flash.color = Color(0.4, 0.85, 1.0, 1.0)
	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(parry_flash, "color:a", 0.0, 0.09)

func pulse_crosshair() -> void:
	if _crosshair == null:
		return
	_crosshair.scale = Vector2(1.4, 1.4)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_crosshair, "scale", Vector2.ONE, 0.15)

func _announce(text: String) -> void:
	if announce_label == null:
		return
	if _announce_tween:
		_announce_tween.kill()
	announce_label.text = text
	announce_label.modulate.a = 0.0
	announce_label.scale = Vector2(0.6, 0.6)
	announce_label.pivot_offset = Vector2(200, 35)
	announce_label.visible = true
	_announce_tween = create_tween()
	_announce_tween.tween_property(announce_label, "modulate:a", 1.0, 0.35)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_announce_tween.parallel().tween_property(announce_label, "scale", Vector2(1.08, 1.08), 0.28)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_announce_tween.tween_property(announce_label, "scale", Vector2.ONE, 0.1)
	_announce_tween.tween_interval(2.0)
	_announce_tween.tween_property(announce_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	_announce_tween.tween_callback(func():
		if is_instance_valid(announce_label): announce_label.visible = false)

func set_coins(amount: int) -> void:
	if coin_label:
		coin_label.text = "\u25cf  %d" % amount

func update_hud() -> void:
	if kill_label:
		kill_label.text = "%d" % kills
