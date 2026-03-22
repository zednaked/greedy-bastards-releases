extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_style_ui()
	_play_entrance()

func _style_ui() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		$VBox/KillsLabel.text = "\u2694  %d INIMIGOS ABATIDOS" % gm.kills
		$VBox/WaveLabel.text  = "\u25c8  WAVE %d ALCANCADA" % gm.wave
	else:
		$VBox/KillsLabel.text = "\u2694  0 INIMIGOS ABATIDOS"
		$VBox/WaveLabel.text  = "\u25c8  WAVE 1 ALCANCADA"

	# Title
	$VBox/Title.add_theme_font_size_override("font_size", 64)
	$VBox/Title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.1))
	$VBox/Title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	$VBox/Title.add_theme_constant_override("outline_size", 8)
	$VBox/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Stats
	$VBox/KillsLabel.add_theme_font_size_override("font_size", 26)
	$VBox/KillsLabel.add_theme_color_override("font_color", Color(0.92, 0.88, 0.85))
	$VBox/KillsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	$VBox/WaveLabel.add_theme_font_size_override("font_size", 22)
	$VBox/WaveLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	$VBox/WaveLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Buttons
	_style_button($VBox/RetryBtn, Color(0.7, 0.15, 0.1))
	_style_button($VBox/MenuBtn,  Color(0.28, 0.1, 0.1))
	$VBox/RetryBtn.pressed.connect(_retry)
	$VBox/MenuBtn.pressed.connect(_menu)

func _style_button(btn: Button, accent: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.05, 0.05)
	n.border_color = accent
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.content_margin_left = 20; n.content_margin_right = 20
	n.content_margin_top = 10;  n.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.18, 0.08, 0.06)
	h.border_color = accent.lightened(0.3)
	h.set_border_width_all(1)
	h.set_corner_radius_all(3)
	h.content_margin_left = 20; h.content_margin_right = 20
	h.content_margin_top = 10;  h.content_margin_bottom = 10
	btn.add_theme_stylebox_override("hover", h)

	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.07, 0.03, 0.03)
	p.border_color = accent
	p.set_border_width_all(1)
	p.set_corner_radius_all(3)
	p.content_margin_left = 20; p.content_margin_right = 20
	p.content_margin_top = 10;  p.content_margin_bottom = 10
	btn.add_theme_stylebox_override("pressed", p)

func _play_entrance() -> void:
	$BG.modulate.a = 0.0
	$VBox/Title.modulate.a      = 0.0
	$VBox/KillsLabel.modulate.a = 0.0
	$VBox/WaveLabel.modulate.a  = 0.0
	$VBox/RetryBtn.modulate.a   = 0.0
	$VBox/MenuBtn.modulate.a    = 0.0

	# BG
	var t := create_tween()
	t.tween_property($BG, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

	# Title at t=0.5
	t = create_tween()
	t.tween_interval(0.5)
	t.tween_property($VBox/Title, "modulate:a", 1.0, 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	# Kills at t=1.1
	t = create_tween()
	t.tween_interval(1.1)
	t.tween_property($VBox/KillsLabel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)

	# Wave at t=1.25
	t = create_tween()
	t.tween_interval(1.25)
	t.tween_property($VBox/WaveLabel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)

	# Retry button at t=1.9
	t = create_tween()
	t.tween_interval(1.9)
	t.tween_property($VBox/RetryBtn, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# Menu button at t=2.0
	t = create_tween()
	t.tween_interval(2.0)
	t.tween_property($VBox/MenuBtn, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# Grab focus after buttons appear
	get_tree().create_timer(2.2, true).timeout.connect(func():
		if is_instance_valid($VBox/RetryBtn): $VBox/RetryBtn.grab_focus())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_retry()

func _retry() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
