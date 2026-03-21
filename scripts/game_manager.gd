extends Node

# Autoload singleton — add to Project > Autoload as "GameManager"
signal game_started
signal game_paused(is_paused: bool)

var kills: int = 0
var wave: int = 0
var coins: int = 0

func start_game() -> void:
	kills = 0
	wave = 0
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func pause(paused: bool) -> void:
	get_tree().paused = paused
	game_paused.emit(paused)

func show_defeat(kill_count: int, reached_wave: int) -> void:
	kills = kill_count
	wave = reached_wave
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/defeat.tscn")
