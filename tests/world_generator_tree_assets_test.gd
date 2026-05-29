extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var terrain_root = Node2D.new()
	var object_root = Node2D.new()
	object_root.y_sort_enabled = true
	root.add_child(terrain_root)
	root.add_child(object_root)

	var configs: Array[Dictionary] = []
	for biome_id in WorldGenerator.BIOME_IDS:
		configs.append({"id": biome_id, "atlas_path": "", "variant_count": 1})
	generator.set_biome_configs(configs)

	var tree_textures: Array[Texture2D] = [
		load("res://assets/vegetation/trees/tree_01.png"),
		load("res://assets/vegetation/trees/tree_02.png"),
	]
	generator.set_resource_defs([{
		"id": "tree",
		"item": "wood",
		"qty": 3,
		"name": "树",
		"biomes": WorldGenerator.BIOME_IDS,
		"density": 1.0,
		"z_index": 2,
		"scale": 0.5,
		"textures": tree_textures,
		"anchor": "bottom",
		"collision_radius": 18.0,
		"collision_offset": Vector2(0, -12),
	}])
	generator.init_chunks(terrain_root, object_root)
	generator.generate_chunk(0, 0)

	if not _check(generator.resource_sprites.size() > 0, "tree resources should spawn"):
		return
	var first_id = generator.resource_sprites.keys()[0]
	var tree = generator.resource_sprites[first_id] as Sprite2D
	_check(tree != null, "tree resource should be a Sprite2D")
	_check(tree.texture in tree_textures, "tree should use one of the imported tree textures")
	_check(not tree.centered, "tree sprite should be anchored at the tree root")
	_check(absf(tree.offset.y + tree.texture.get_height()) < 0.01, "tree visual bottom should sit on its world position")

	var body = tree.get_node_or_null("TrunkBody")
	_check(body is StaticBody2D, "tree should have trunk collision body")
	var collision = body.get_node_or_null("CollisionShape2D") if body else null
	_check(collision is CollisionShape2D, "tree should have a trunk collision shape")
	_check((collision as CollisionShape2D).shape is CircleShape2D, "tree collision should be limited to the trunk/root")

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
