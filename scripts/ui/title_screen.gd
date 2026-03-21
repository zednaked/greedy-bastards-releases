extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$VBox/StartBtn.pressed.connect(_on_start)
	$VBox/QuitBtn.pressed.connect(get_tree().quit)
	$VBox/StartBtn.grab_focus()

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
