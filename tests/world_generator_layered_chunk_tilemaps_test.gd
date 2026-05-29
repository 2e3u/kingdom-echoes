extends SceneTree

var _failed := false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)
	var configs: Array[Dictionary] = []
	for biome_id in WorldGenerator.BIOME_IDS:
		configs.append({"id": biome_id, "atlas_path": "", "variant_count": 1})
	generator.set_biome_configs(configs)

	var tile_set = load("res://assets/tilesets/world_terrain_tileset.tres") as TileSet
	_check(tile_set != null, "world terrain TileSet should load")
	generator.set_layered_terrain_tileset(tile_set, 0, 0, {
		WorldGenerator.BIOME_DIRT: 1,
		WorldGenerator.BIOME_SAND: 2,
		WorldGenerator.BIOME_SNOW: 3,
		WorldGenerator.BIOME_SWAMP: 1,
		WorldGenerator.BIOME_STONE: 1,
		WorldGenerator.BIOME_WATER: 4,
	}, true)
	generator.set_terrain_paint_mode(WorldGenerator.TERRAIN_PAINT_GLOBAL_NEIGHBORS)

	var terrain_root = Node2D.new()
	var object_root = Node2D.new()
	root.add_child(terrain_root)
	root.add_child(object_root)
	generator.init_chunks(terrain_root, object_root)

	generator.generate_chunk(1, 0, false)
	generator.generate_chunk(2, 0, false)

	_check(terrain_root.has_node("Chunk_1_0"), "layered terrain should create a node for chunk 1,0")
	_check(terrain_root.has_node("Chunk_2_0"), "layered terrain should create a node for chunk 2,0")
	var chunk = terrain_root.get_node("Chunk_1_0") as Node2D
	if _check(chunk != null, "chunk terrain node should be a Node2D"):
		var base_layer = chunk.get_node("BaseGrass") as TileMapLayer
		var overlay_layer = chunk.get_node("TerrainOverlay") as TileMapLayer
		_check(base_layer != null, "chunk should own its BaseGrass layer")
		_check(overlay_layer != null, "chunk should own its TerrainOverlay layer")
		if base_layer != null:
			_check(base_layer.get_used_cells().size() == WorldGenerator.CHUNK_SIZE * WorldGenerator.CHUNK_SIZE, "chunk base layer should fill exactly one chunk")
			_check(base_layer.get_cell_source_id(Vector2i(0, 0)) >= 0, "chunk local origin should have base terrain")
			_check(base_layer.get_cell_source_id(Vector2i(WorldGenerator.CHUNK_SIZE - 1, WorldGenerator.CHUNK_SIZE - 1)) >= 0, "chunk far corner should have base terrain")

	generator.unload_chunk(1, 0)
	_check(not terrain_root.has_node("Chunk_1_0"), "unloading a chunk should remove only that chunk terrain node")
	_check(terrain_root.has_node("Chunk_2_0"), "unloading one chunk should leave neighboring chunk terrain intact")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
