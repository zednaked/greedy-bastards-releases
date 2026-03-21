extends Area3D

var damage: int = 1
var push_force: float = 6.0
var _triggered: bool = false
var trapper = null  # reference to trapper goblin

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Start nearly invisible — hard to see on ground
	_set_alpha(0.15)

func _set_alpha(a: float) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.5, 0.4, 0.2, a)
			mat.roughness = 0.85
			child.material_override = mat

func _on_body_entered(body: Node) -> void:
	if _triggered: return
	if not body.has_method("take_damage") and not body.has_method("take_hit"):
		return
	_triggered = true
	# Deal damage + push up
	var b3d := body as Node3D
	if b3d:
		var dir := (b3d.global_position - global_position)
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			dir = Vector3.FORWARD
		var push := dir.normalized() * push_force
		push.y = 4.0
		if body.has_method("take_damage"):
			body.take_damage(damage, push)
		elif body.has_method("take_hit"):
			body.take_hit(push)
	# Reveal briefly
	_set_alpha(1.0)
	if trapper and is_instance_valid(trapper) and trapper.has_method("notify_trap_triggered"):
		trapper.notify_trap_triggered()
	# Fade out and disappear after showing
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self):
		queue_free()
