extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var terrain_root = Node2D.new()
	var object_root = Node2D.new()
	root.add_child(terrain_root)
	root.add_child(object_root)

	var configs: Array[Dictionary] = []
	for biome_id in WorldGenerator.BIOME_IDS:
		configs.append({"id": biome_id, "atlas_path": "", "variant_count": 1})
	generator.set_biome_configs(configs)

	var decoration_textures: Array[Texture2D] = [
		load("res://assets/vegetation/trees/tree_01.png"),
		load("res://assets/vegetation/trees/tree_02.png"),
	]
	generator.set_decoration_defs([{
		"id": "grass_tuft",
		"biomes": WorldGenerator.BIOME_IDS,
		"density": 1.0,
		"z_index": 0,
		"scale": 0.5,
		"textures": decoration_textures,
	}])
	generator.init_chunks(terrain_root, object_root)
	generator.generate_chunk(0, 0)

	if not _check(object_root.get_child_count() > 0, "decoration variants should spawn"):
		return
	var sprite = object_root.get_child(0) as Sprite2D
	_check(sprite.texture in decoration_textures, "decoration should use one of the texture variants")

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
