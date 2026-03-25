extends Area3D

@export var damage: int = 1
@export var push_force: float = 8.0
@export var hit_interval: float = 1.5

var _bodies: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	var stale: Array = []
	for body in _bodies.keys():
		if not is_instance_valid(body):
			stale.append(body)
			continue
		_bodies[body] -= delta
		if _bodies[body] <= 0.0:
			_hit(body)
			_bodies[body] = hit_interval
	for body in stale:
		_bodies.erase(body)

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		_bodies[body] = 0.0

func _on_body_exited(body: Node) -> void:
	_bodies.erase(body)

func _hit(body: Node) -> void:
	if NetworkManager.is_multiplayer_session and not multiplayer.is_server():
		return
	var b3d := body as Node3D
	if b3d == null:
		return
	var dir: Vector3 = b3d.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	var push: Vector3 = dir.normalized() * push_force
	push.y = 3.5
	if body.is_in_group("player") and NetworkManager.is_multiplayer_session:
		body.rpc_id(body.get_multiplayer_authority(), "rpc_take_damage", damage, push)
	else:
		body.take_damage(damage, push)
