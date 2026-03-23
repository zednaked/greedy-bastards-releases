extends Node3D

var _velocity: Vector3 = Vector3.ZERO
var _lifetime: float = 8.0
var _landed: bool = false
const GRAVITY: float = 9.8

func launch(origin: Vector3, target_pos: Vector3, speed: float) -> void:
	global_position = origin
	var to_target := target_pos - origin
	var horiz_dist := Vector2(to_target.x, to_target.z).length()
	var time_of_flight := horiz_dist / speed
	var dir_h := Vector3(to_target.x, 0.0, to_target.z).normalized()
	_velocity = dir_h * speed
	_velocity.y = (to_target.y + 0.5 * GRAVITY * time_of_flight * time_of_flight) / time_of_flight

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		if not _landed:
			global_position.y = 0.1
		_burst()
		return

	if not _landed:
		_velocity.y -= GRAVITY * delta
		global_position += _velocity * delta
		rotation += Vector3(4.0, 1.5, 2.0) * delta
		if global_position.y <= 0.1:
			global_position.y = 0.1
			_landed = true
			_velocity = Vector3.ZERO
			var tw := create_tween().set_parallel(true)
			tw.tween_property(self, "scale", Vector3(1.5, 0.5, 1.5), 0.10).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(self, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(self): _burst())

func _burst() -> void:
	set_process(false)
	visible = false
	var origin := global_position
	_spawn_burst_fx(origin)
	_spawn_cloud(origin)
	queue_free()

func _spawn_cloud(origin: Vector3) -> void:
	var cloud_scene := load("res://scenes/enemies/poison_cloud.tscn") as PackedScene
	if cloud_scene == null:
		return
	var cloud := cloud_scene.instantiate()
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = origin

func _spawn_burst_fx(origin: Vector3) -> void:
	var scene := get_tree().current_scene

	var light := OmniLight3D.new()
	light.light_color  = Color(0.1, 1.0, 0.05)
	light.light_energy = 6.0
	light.omni_range   = 5.0
	light.shadow_enabled = false
	scene.add_child(light)
	light.global_position = origin + Vector3(0.0, 0.5, 0.0)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	lt.tween_callback(func(): if is_instance_valid(light): light.queue_free())

	var ps := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction            = Vector3.UP
	pm.spread               = 90.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 12.0
	pm.gravity              = Vector3(0.0, -4.0, 0.0)
	pm.scale_min            = 0.15
	pm.scale_max            = 0.55
	pm.color                = Color(0.15, 1.0, 0.05, 0.9)
	pm.collision_mode       = ParticleProcessMaterial.COLLISION_DISABLED
	ps.process_material = pm
	ps.amount        = 35
	ps.lifetime      = 0.7
	ps.one_shot      = true
	ps.explosiveness = 0.96
	ps.emitting      = true
	scene.add_child(ps)
	ps.global_position = origin + Vector3(0.0, 0.15, 0.0)
	ps.finished.connect(func(): if is_instance_valid(ps): ps.queue_free())
