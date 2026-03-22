extends Node3D

@export var weapon_name: String = "Sword"
@export var weapon_scene: PackedScene  ## Cena da arma na mão — abra e ajuste posição/rotação do mesh
@export var interact_distance: float = 2.0

@onready var prompt_label: Label3D = $PromptLabel
@onready var mesh: Node3D = get_node_or_null("WeaponMesh")

var player: Node3D
var is_picked_up := false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if prompt_label:
		prompt_label.text = "[ E ] Pegar %s" % weapon_name
		prompt_label.visible = false

func _process(_delta: float) -> void:
	if is_picked_up or not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)
	var in_range := dist <= interact_distance

	if prompt_label:
		prompt_label.visible = in_range

	if in_range and Input.is_action_just_pressed("interact"):
		_pickup()

func _pickup() -> void:
	is_picked_up = true
	if prompt_label:
		prompt_label.visible = false
	if player.has_method("equip_weapon"):
		if weapon_scene:
			player.equip_weapon(weapon_name, weapon_scene.instantiate())
		elif mesh:
			player.equip_weapon(weapon_name, mesh)
		else:
			player.equip_weapon(weapon_name, null)
	queue_free()
