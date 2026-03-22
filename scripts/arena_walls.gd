extends Node3D

@export var wall_radius: float = 21.0
@export var wall_height: float = 8.0
@export var segments: int = 32  # mais segmentos = cilindro mais suave

func _ready() -> void:
	var sb := StaticBody3D.new()
	sb.name = "ArenaCollision"
	add_child(sb)

	var cs := CollisionShape3D.new()
	cs.shape = _make_cylinder_wall(wall_radius, wall_height, segments)
	sb.add_child(cs)

	_apply_floor_shader()

func _apply_floor_shader() -> void:
	var model := get_parent().get_node_or_null("ArenaModel")
	if model == null:
		return
	# O mesh "Arena" dentro do GLB importado é o chão principal
	var floor_node := model.find_child("Arena", true, false) as MeshInstance3D
	if floor_node == null:
		return
	# Preserva a textura/cor original — só deixa o chão úmido (baixo roughness, alto specular)
	for s in floor_node.mesh.get_surface_count():
		var orig := floor_node.get_active_material(s)
		if orig == null:
			continue
		var mat := orig.duplicate() as Material
		if mat is StandardMaterial3D:
			var std := mat as StandardMaterial3D
			std.roughness = 0.06
			std.metallic_specular = 0.9
		floor_node.set_surface_override_material(s, mat)

func _make_cylinder_wall(radius: float, height: float, segs: int) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	var step := TAU / segs

	for i in segs:
		var a0 := i * step
		var a1 := (i + 1) * step
		var v00 := Vector3(cos(a0) * radius, 0.0,    sin(a0) * radius)
		var v01 := Vector3(cos(a0) * radius, height, sin(a0) * radius)
		var v10 := Vector3(cos(a1) * radius, 0.0,    sin(a1) * radius)
		var v11 := Vector3(cos(a1) * radius, height, sin(a1) * radius)
		# Dois triângulos por segmento, normais apontando para dentro
		faces.append_array([v00, v01, v10, v01, v11, v10])

	shape.set_faces(faces)
	return shape
