extends CanvasLayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Freeze time so enemies don't spawn yet but world renders
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/StartBtn.pressed.connect(_start)
	$Panel/QuitBtn.pressed.connect(get_tree().quit)
	$Panel/StartBtn.grab_focus()

func _start() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Fade out then remove
	var t := create_tween()
	t.tween_property($Dim, "color:a", 0.0, 0.4)
	t.parallel().tween_property($Panel, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)
