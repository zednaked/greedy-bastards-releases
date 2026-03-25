extends RigidBody3D

var value: int = 1
var _collect_area: Area3D
var _collected: bool = false
var _lifetime: float = 25.0

func _ready() -> void:
	add_to_group("coins")
	angular_velocity = Vector3(0.0, 2.8, 0.0)
	# Collect area
	_collect_area = Area3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	col.shape = sphere
	_collect_area.add_child(col)
	add_child(_collect_area)
	_collect_area.body_entered.connect(_on_body_entered)
	get_tree().create_timer(_lifetime).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	_collect_area.body_entered.disconnect(_on_body_entered)
	_collect_area.set_deferred("monitoring", false)
	if body.has_method("add_coins"):
		body.add_coins(value)
	# Pop tween before freeing
	var t := create_tween()
	freeze = true
	t.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.06)
	t.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.08)
	t.tween_callback(queue_free)

func set_collect_radius(r: float) -> void:
	var col := _collect_area.get_child(0) as CollisionShape3D
	if col and col.shape is SphereShape3D:
		(col.shape as SphereShape3D).radius = r
