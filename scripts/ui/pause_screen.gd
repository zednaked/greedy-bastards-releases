extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Hide the scene-built panel; we build our own styled version
	$Panel.visible = false
	$Dim.color = Color(0, 0, 0, 0.0)
	_build_ui()

func _build_ui() -> void:
	# Styled panel container
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.03)
	sb.border_color = Color(0.35, 0.08, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 36; sb.content_margin_right = 36
	sb.content_margin_top = 28;  sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)

	# Wrap in CenterContainer for easy centering + slide animation
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	# Red accent line at top
	var accent := ColorRect.new()
	accent.color = Color(0.8, 0.15, 0.1)
	accent.custom_minimum_size = Vector2(0, 2)
	accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(accent)

	# Title
	var title := Label.new()
	title.text = "// PAUSA //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.85))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.04))
	title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title)

	# Resume button
	var resume_btn := Button.new()
	resume_btn.text = "Continuar"
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_style_button(resume_btn, Color(0.7, 0.2, 0.1))
	resume_btn.pressed.connect(_resume)
	vbox.add_child(resume_btn)
	resume_btn.grab_focus()

	# Menu button
	var menu_btn := Button.new()
	menu_btn.text = "Menu Principal"
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_style_button(menu_btn, Color(0.3, 0.1, 0.1))
	menu_btn.pressed.connect(_menu)
	vbox.add_child(menu_btn)

	# Animate: overlay fades in, panel slides in from below
	var t_dim := create_tween()
	t_dim.tween_property($Dim, "color:a", 0.75, 0.15).set_ease(Tween.EASE_OUT)

	center.position.y = 60.0
	var t_panel := create_tween()
	t_panel.tween_property(center, "position:y", 0.0, 0.22)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _style_button(btn: Button, accent: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.05, 0.05)
	n.border_color = accent
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.content_margin_left = 18; n.content_margin_right = 18
	n.content_margin_top = 10;  n.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.18, 0.08, 0.08)
	h.border_color = accent.lightened(0.3)
	h.set_border_width_all(1)
	h.set_corner_radius_all(3)
	h.content_margin_left = 18; h.content_margin_right = 18
	h.content_margin_top = 10;  h.content_margin_bottom = 10
	btn.add_theme_stylebox_override("hover", h)

	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.07, 0.03, 0.03)
	p.border_color = accent
	p.set_border_width_all(1)
	p.set_corner_radius_all(3)
	p.content_margin_left = 18; p.content_margin_right = 18
	p.content_margin_top = 10;  p.content_margin_bottom = 10
	btn.add_theme_stylebox_override("pressed", p)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()

func _resume() -> void:
	get_tree().paused = false
	queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
