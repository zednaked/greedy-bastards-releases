extends Area3D

@export var heal_amount: int = 2
@export var respawn_time: float = 20.0

var _active: bool = true
var _model: Node3D

func _ready() -> void:
	_model = get_parent().get_node_or_null("Model")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not _active or not body.is_in_group("player"):
		return
	if body.has_method("heal"):
		body.heal(heal_amount)
		_pickup()

func _pickup() -> void:
	_active = false
	if _model:
		_model.visible = false
	monitoring = false
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)

func _respawn() -> void:
	_active = true
	if _model:
		_model.visible = true
	monitoring = true
