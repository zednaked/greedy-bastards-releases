extends CanvasLayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_ui()
	$Panel/StartBtn.pressed.connect(_start)
	$Panel/QuitBtn.pressed.connect(get_tree().quit)
	$Panel/StartBtn.grab_focus()

func _style_ui() -> void:
	# Title — heavy outline for weight
	$Panel/Title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.85))
	$Panel/Title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01))
	$Panel/Title.add_theme_constant_override("outline_size", 8)

	# Subtitle — pulse alpha loop
	var sub := $Panel/Subtitle
	sub.add_theme_color_override("font_color", Color(0.88, 0.50, 0.25))
	sub.modulate.a = 0.7
	var tp := create_tween().set_loops()
	tp.tween_property(sub, "modulate:a", 1.0, 1.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tp.tween_property(sub, "modulate:a", 0.7, 1.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Move "By ZeD" out of the VBox and place in bottom-right corner
	$Panel/Subtitle2.visible = false
	var credit := Label.new()
	credit.text = "by ZeD"
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.55))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Position bottom-right via a Control wrapper inside the CanvasLayer
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

	# Style Start button — red border, gold on hover
	_style_start_btn($Panel/StartBtn)

	# Style Quit button — subtle
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_start()

func _start() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var t := create_tween()
	t.tween_property($Dim, "color:a", 0.0, 0.4)
	t.parallel().tween_property($Panel, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)
