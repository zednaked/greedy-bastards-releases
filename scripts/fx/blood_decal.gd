extends Node3D

# Spawned at hit position, projects a blood splat decal onto the floor.
# Parent node should be a Decal node.

@export var lifetime: float = 30.0

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()
