extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Fill in stats passed via autoload (if GameManager exists)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		$VBox/KillsLabel.text = "Kills: %d" % gm.kills
		$VBox/WaveLabel.text = "Wave: %d" % gm.wave
	$VBox/RetryBtn.pressed.connect(_retry)
	$VBox/MenuBtn.pressed.connect(_menu)
	$VBox/RetryBtn.grab_focus()

func _retry() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
