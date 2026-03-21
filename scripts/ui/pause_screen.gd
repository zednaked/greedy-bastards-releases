extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$Panel/ResumeBtn.pressed.connect(_resume)
	$Panel/MenuBtn.pressed.connect(_menu)
	$Panel/ResumeBtn.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()

func _resume() -> void:
	get_tree().paused = false
	queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
