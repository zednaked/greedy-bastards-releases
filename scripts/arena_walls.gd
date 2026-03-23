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
