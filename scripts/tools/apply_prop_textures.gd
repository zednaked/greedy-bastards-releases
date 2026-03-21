@tool
extends EditorScript

## Abre este arquivo no editor e rode: Script > Run
## Cria arquivos .tscn em assets/models/props/ com texturas aplicadas.

const PROPS_PATH := "res://assets/models/props/"
const FALLBACK := "props_base_color.png"

const TEX_MAP: Dictionary = {
	"pillar01":          "pillarA.png",
	"pillar02":          "pillarA.png",
	"chestA":            "chestA.png",
	"chestB":            "chestB.png",
	"groundSpike01":     "groundSpikeA.png",
	"groundSpike02":     "groundSpikeB.png",
	"coin":              "coinA.png",
	"coinProcJam":       "coinA.png",
	"boxWooden":         "boxA.png",
	"boxCardboard":      "boxB.png",
	"boxGift1":          "boxGiftA.png",
	"bridgeWooden01":    "bridgeA.png",
	"bridgeWooden02":    "bridgeA.png",
	"bridgeWooden03":    "bridgeA.png",
	"bridgeWoodenRails": "bridgeA.png",
	"chair":             "chairA.png",
	"char01":            "char01.png",
	"char02":            "char02.png",
	"char03":            "char03.png",
	"char04":            "char04.png",
	"dice":              "diceA.png",
	"dice2":             "diceB.png",
	"doorA":             "doorA.png",
	"doorB":             "doorB.png",
	"egg01":             "eggA.png",
	"egg02":             "eggB.png",
	"egg03":             "eggC.png",
	"gem":               "gemA.png",
	"ground01":          "groundA.png",
	"ground01Cracked":   "groundACracked.png",
	"ground02":          "groundB.png",
	"ground02Cracked":   "groundBCracked.png",
	"ground03":          "groundC.png",
	"ground03Cracked":   "groundCCracked.png",
	"key":               "keyA.png",
	"lock":              "lockA.png",
	"map":               "map.png",
	"paintingA":         "paintingA.png",
	"paintingB":         "paintingB.png",
	"player1":           "player.png",
	"player2":           "player.png",
	"player3":           "player.png",
	"player4":           "player.png",
	"stool":             "stoolA.png",
	"trapdoorMetal":     "trapdoorMetal.png",
	"trapdoorWooden":    "trapdoorWooden.png",
	"wallEarth01":       "wallEarthA.png",
	"wallEarth02":       "wallEarthB.png",
	"wallStone01":       "wallStoneA.png",
	"wallStone03":       "wallStoneC.png",
	"water01":           "waterA.png",
}

func _run() -> void:
	var dir := DirAccess.open(PROPS_PATH)
	if dir == null:
		push_error("Pasta não encontrada: " + PROPS_PATH)
		return

	var mat_cache: Dictionary = {}

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".fbx"):
			var base := fname.get_basename()
			var tscn_path := PROPS_PATH + base + ".tscn"

			# Carrega a cena importada do FBX
			var fbx_res: PackedScene = load(PROPS_PATH + fname)
			if fbx_res == null:
				push_warning("Não carregou: " + fname)
				fname = dir.get_next()
				continue

			# Resolve textura
			var tex_name: String = TEX_MAP.get(base, FALLBACK)
			var tex_path := PROPS_PATH + tex_name

			if not mat_cache.has(tex_path):
				var mat := StandardMaterial3D.new()
				mat.roughness = 1.0
				mat.metallic_specular = 0.0
				var tex: Texture2D = load(tex_path)
				if tex:
					mat.albedo_texture = tex
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				else:
					push_warning("Textura não encontrada: " + tex_path)
				mat_cache[tex_path] = mat

			# Instancia, aplica material, empacota como .tscn
			var node := fbx_res.instantiate()
			_apply_mat(node, mat_cache[tex_path])
			var packed := PackedScene.new()
			packed.pack(node)
			node.queue_free()

			var err := ResourceSaver.save(packed, tscn_path)
			if err == OK:
				print("✓ %s → %s" % [base + ".tscn", tex_name])
			else:
				push_error("Erro ao salvar %s: %d" % [tscn_path, err])

		fname = dir.get_next()
	dir.list_dir_end()
	print("=== Concluído — use os .tscn em vez dos .fbx ===")

func _apply_mat(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		for i in (node as MeshInstance3D).get_surface_override_material_count():
			(node as MeshInstance3D).set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_mat(child, mat)
