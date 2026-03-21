extends Node3D

@export var chest_scene: PackedScene  # self-reference, unused — left for inspector compat

var _player_nearby: bool = false
var _opened: bool = false
var _prompt: Label3D
var _lid: Node3D
var _player: Node3D

func _ready() -> void:
	add_to_group("chest")
	_player = get_tree().get_first_node_in_group("player")

	# Prompt label
	_prompt = Label3D.new()
	_prompt.text = "[E] Abrir bau"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 36
	_prompt.outline_size = 6
	_prompt.outline_modulate = Color(0, 0, 0, 1)
	_prompt.position = Vector3(0, 1.6, 0)
	_prompt.visible = false
	add_child(_prompt)

	# Proximity area
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.5, 3.0)
	col.shape = box
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(b): if b.is_in_group("player"): _player_nearby = true; _prompt.visible = not _opened)
	area.body_exited.connect(func(b): if b.is_in_group("player"): _player_nearby = false; _prompt.visible = false)

	_lid = get_node_or_null("Lid")

	# Spawn pop
	scale = Vector3.ZERO
	var st := create_tween()
	st.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	st.tween_property(self, "scale", Vector3.ONE, 0.55)

func _unhandled_input(event: InputEvent) -> void:
	if _opened or not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		_open()

func _open() -> void:
	_opened = true
	_prompt.visible = false
	# Lid tween
	if _lid:
		var lt := create_tween()
		lt.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		lt.tween_property(_lid, "rotation:x", -deg_to_rad(110.0), 0.4)
	# Show upgrade panel after lid opens
	get_tree().create_timer(0.35).timeout.connect(_show_upgrades)

func _show_upgrades() -> void:
	var panel_scene := load("res://scenes/ui/upgrade_panel.tscn") as PackedScene
	if panel_scene == null:
		return
	var panel := panel_scene.instantiate()
	panel.chest = self
	get_tree().current_scene.add_child(panel)
	get_tree().paused = true

func close_chest() -> void:
	# Called by upgrade panel when closed
	get_tree().paused = false
	# Lid close
	if _lid:
		var lt := create_tween()
		lt.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		lt.tween_property(_lid, "rotation:x", 0.0, 0.3)
	# Shrink and remove
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(self):
			var dt := create_tween()
			dt.tween_property(self, "scale", Vector3.ZERO, 0.25)
			dt.tween_callback(queue_free)
	)
