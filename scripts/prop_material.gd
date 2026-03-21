@tool
extends Node3D

@export var texture: Texture2D:
	set(v):
		texture = v
		if is_inside_tree():
			_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if texture == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	_set_on_meshes(self, mat)

func _set_on_meshes(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_set_on_meshes(child, mat)
