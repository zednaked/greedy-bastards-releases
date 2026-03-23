extends Node3D

@export var duration: float = 8.0
@export var tick_damage: int = 1
@export var tick_interval: float = 2.0
@export var radius: float = 3.5

var _timer: float = 0.0
var _tick_timer: float = 0.0
var _player_inside: bool = false
var _player: Node = null
var _light: OmniLight3D = null
var _particles: GPUParticles3D = null

func _ready() -> void:
	_timer = duration
	_tick_timer = tick_interval
	_setup_area()
	_spawn_visuals()

func _setup_area() -> void:
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.2
	col.shape = cyl
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player"):
			_player_inside = true
			_player = b
			_tick_timer = 1.0  # primeiro tick logo após entrar
	)
	area.body_exited.connect(func(b: Node3D):
		if b.is_in_group("player"):
			_player_inside = false
	)

func _process(delta: float) -> void:
	_timer -= delta

	if _player_inside and is_instance_valid(_player):
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = tick_interval
			if _player.has_method("take_damage"):
				_player.take_damage(tick_damage)
			_flash_poison_screen()

	# Começa a sumir nos últimos 2s
	if _timer <= 2.0 and _particles != null and is_instance_valid(_particles):
		_particles.emitting = false

	if _timer <= 0.0:
		set_process(false)
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(self): queue_free()
		, CONNECT_ONE_SHOT)

func _spawn_visuals() -> void:
	# Luz verde ambiente
	_light = OmniLight3D.new()
	_light.light_color   = Color(0.1, 1.0, 0.05)
	_light.light_energy  = 2.2
	_light.omni_range    = radius * 2.5
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3(0.0, 1.0, 0.0)

	# Nuvem de gás contínua
	_particles = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape        = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.75
	pm.direction             = Vector3.UP
	pm.spread                = 25.0
	pm.initial_velocity_min  = 0.2
	pm.initial_velocity_max  = 0.9
	pm.gravity               = Vector3(0.0, 0.15, 0.0)
	pm.scale_min             = 0.6
	pm.scale_max             = 2.2
	pm.color                 = Color(0.12, 0.85, 0.05, 0.45)
	pm.collision_mode        = ParticleProcessMaterial.COLLISION_DISABLED
	_particles.process_material = pm
	_particles.amount        = 50
	_particles.lifetime      = 2.5
	_particles.one_shot      = false
	_particles.explosiveness = 0.0
	_particles.emitting      = true
	add_child(_particles)
	_particles.position = Vector3(0.0, 0.1, 0.0)

	# Fade da luz no final
	var tw := create_tween()
	tw.tween_interval(duration - 2.0)
	tw.tween_property(_light, "light_energy", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): if is_instance_valid(_light): _light.queue_free())

func _flash_poison_screen() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_vignette"):
		hud.flash_vignette(Color(0.05, 0.55, 0.0, 0.45))
	elif hud and hud.has_method("flash_explosion"):
		# fallback — usa o flash genérico com intensidade baixa
		pass
