extends Node3D

# Spawned at hit position, projects a blood splat decal onto the floor.
# Parent node should be a Decal node.

@export var lifetime: float = 30.0

func _ready() -> void:
	var fade_duration := 2.0
	var visible_time := maxf(0.1, lifetime - fade_duration)
	await get_tree().create_timer(visible_time).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tw.finished
	queue_free()
