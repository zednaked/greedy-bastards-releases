extends CanvasLayer

@onready var kill_label: Label = $KillCount
@onready var health_label: Label = get_node_or_null("HealthLabel")
@onready var wave_label: Label = get_node_or_null("WaveLabel")
@onready var announce_label: Label = get_node_or_null("AnnounceLabel")
@onready var combo_label: Label = get_node_or_null("ComboLabel")
@onready var vignette: ColorRect = get_node_or_null("Vignette")
@onready var parry_flash: ColorRect = get_node_or_null("ParryFlash")
@onready var coin_label: Label = get_node_or_null("CoinLabel")

var kills := 0
var _near_death_tween: Tween = null
var _near_death_active: bool = false
var _combo_pop_tween: Tween = null

func _ready() -> void:
	add_to_group("hud")
	update_hud()
	if announce_label:
		announce_label.visible = false
	if combo_label:
		await get_tree().process_frame
		combo_label.pivot_offset = combo_label.size / 2.0
	# Create coin label dynamically if not present in scene
	if coin_label == null:
		coin_label = Label.new()
		coin_label.name = "CoinLabel"
		coin_label.text = "[COIN] 0"
		coin_label.add_theme_font_size_override("font_size", 22)
		coin_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		coin_label.position = Vector2(16, 120)
		add_child(coin_label)
	set_coins(0)

func register_kill() -> void:
	kills += 1
	update_hud()
	if kill_label:
		kill_label.pivot_offset = kill_label.size / 2.0
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		t.tween_property(kill_label, "scale", Vector2(1.5, 1.5), 0.0)
		t.tween_property(kill_label, "scale", Vector2.ONE, 0.5)

func set_health(current: int, maximum: int, flash: bool = true) -> void:
	if health_label:
		health_label.text = "HP: %d/%d" % [current, maximum]
	if flash:
		_flash_vignette(Color(1, 0, 0, 0.55))
	var should_pulse := current <= 1 and current > 0
	if should_pulse and not _near_death_active:
		_start_near_death_pulse()
	elif not should_pulse and _near_death_active:
		_stop_near_death_pulse()

func _flash_vignette(color: Color) -> void:
	if vignette == null:
		return
	vignette.color = color
	if _near_death_active:
		return  # pulse loop controla o alpha
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
		wave_label.text = "Wave %d" % wave
	_announce("WAVE %d\n%d inimigos" % [wave, count])

func show_wave_clear() -> void:
	_announce("WAVE COMPLETA!")

func set_combo(n: int) -> void:
	if combo_label == null:
		return
	if n <= 1:
		combo_label.visible = false
		combo_label.scale = Vector2.ONE
		return
	combo_label.text = "x%d COMBO" % n
	combo_label.visible = true
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
	# Flash branco/laranja curtíssimo — confirma o impacto de forma cartoonística
	parry_flash.color = Color(1.0, 0.88, 0.5, 0.55) if is_kill else Color(1.0, 1.0, 1.0, 0.35)
	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(parry_flash, "color:a", 0.0, 0.06)

func flash_parry() -> void:
	if parry_flash == null:
		return
	parry_flash.color = Color(0.4, 0.85, 1.0, 1.0)
	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(parry_flash, "color:a", 0.0, 0.09)

func _announce(text: String) -> void:
	if announce_label == null:
		return
	announce_label.text = text
	announce_label.visible = true
	await get_tree().create_timer(2.5).timeout
	announce_label.visible = false

func set_coins(amount: int) -> void:
	if coin_label:
		coin_label.text = "[COIN] %d" % amount

func update_hud() -> void:
	if kill_label:
		kill_label.text = "Kills: %d" % kills
