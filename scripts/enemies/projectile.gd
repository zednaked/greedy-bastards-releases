extends Node3D

var _velocity: Vector3 = Vector3.ZERO
var damage: int = 1
var _lifetime: float = 5.0
const GRAVITY: float = 9.8

func _ready() -> void:
	$HitArea.body_entered.connect(_on_body_entered)
	get_tree().create_timer(_lifetime).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	)

func launch(origin: Vector3, target_pos: Vector3, speed: float) -> void:
	global_position = origin
	var flat: Vector3 = target_pos - origin
	flat.y = 0.0
	var dist: float = flat.length()
	if dist < 0.5:
		queue_free()
		return
	var time_of_flight: float = dist / speed
	var dir_h: Vector3 = flat.normalized()
	var vy: float = (target_pos.y - origin.y) / time_of_flight + GRAVITY * time_of_flight * 0.5
	_velocity = Vector3(dir_h.x * speed, vy, dir_h.z * speed)

func _process(delta: float) -> void:
	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta
	if _velocity.length_squared() > 0.01:
		look_at(global_position + _velocity)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		return
	if body.has_method("take_damage"):
		var push: Vector3 = (_velocity.normalized() if _velocity.length_squared() > 0.01 else Vector3.FORWARD) * 12.0
		push.y = 2.5
		body.take_damage(damage, push)
	queue_free()
