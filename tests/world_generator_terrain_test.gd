extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	tile_set.add_terrain(0)
	tile_set.add_terrain(0)

	assert(generator.has_method("set_layered_terrain_tileset"))
	generator.set_layered_terrain_tileset(tile_set, 0, 0, {
		WorldGenerator.BIOME_DIRT: 1,
	}, true)
	assert(tile_set.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	assert(generator.has_method("set_terrain_paint_mode"))
	generator.set_terrain_paint_mode(WorldGenerator.TERRAIN_PAINT_GLOBAL_NEIGHBORS)
	var overlay_value = generator._get_overlay_terrain_at(32, 32)
	for y in range(32, 34):
		for x in range(32, 34):
			assert(generator._get_overlay_terrain_at(x, y) == overlay_value)
	var found_overlay_cell = false
	for y in range(-512, 513, 4):
		for x in range(-512, 513, 4):
			var terrain = generator._get_overlay_terrain_at(x, y)
			if terrain < 0:
				continue
			if generator._get_overlay_terrain_at(x + 1, y) != terrain:
				continue
			if generator._get_overlay_terrain_at(x, y + 1) != terrain:
				continue
			if generator._get_overlay_terrain_at(x + 1, y + 1) != terrain:
				continue
			var mask = generator._get_global_terrain_neighbor_mask(terrain, x, y)
			assert(mask & WorldGenerator.TERRAIN_MASK_RIGHT != 0)
			assert(mask & WorldGenerator.TERRAIN_MASK_BOTTOM != 0)
			assert(mask & WorldGenerator.TERRAIN_MASK_BOTTOM_RIGHT != 0)
			found_overlay_cell = true
			break
		if found_overlay_cell:
			break
	assert(found_overlay_cell)

	var terrain_root = Node2D.new()
	var object_root = Node2D.new()
	root.add_child(terrain_root)
	root.add_child(object_root)
	generator.init_chunks(terrain_root, object_root)

	var configs: Array[Dictionary] = []
	for biome_id in WorldGenerator.BIOME_IDS:
		configs.append({"id": biome_id, "atlas_path": "", "variant_count": 1})
	generator.set_biome_configs(configs)

	generator.generate_chunk(0, 0)
	assert(terrain_root.get_child_count() == 1)
	assert(terrain_root.has_node("Chunk_0_0"))
	assert((terrain_root.get_node("Chunk_0_0/BaseGrass") as TileMapLayer).tile_set == tile_set)
	assert((terrain_root.get_node("Chunk_0_0/TerrainOverlay") as TileMapLayer).tile_set == tile_set)

	generator.generate_chunk(1, 0)
	assert(terrain_root.get_child_count() == 2)
	assert(terrain_root.has_node("Chunk_1_0"))
	assert((terrain_root.get_node("Chunk_1_0/BaseGrass") as TileMapLayer).tile_set == tile_set)
	assert((terrain_root.get_node("Chunk_1_0/TerrainOverlay") as TileMapLayer).tile_set == tile_set)

	var real_generator = WorldGenerator.new()
	real_generator.setup(rng, 64)
	real_generator.set_biome_configs(configs)
	var real_tile_set = load("res://assets/tilesets/world_terrain_tileset.tres") as TileSet
	assert(real_tile_set != null)
	real_generator.set_layered_terrain_tileset(real_tile_set, 0, 0, {
		WorldGenerator.BIOME_DIRT: 1,
		WorldGenerator.BIOME_SAND: 2,
		WorldGenerator.BIOME_SNOW: 3,
		WorldGenerator.BIOME_SWAMP: 1,
		WorldGenerator.BIOME_STONE: 1,
		WorldGenerator.BIOME_WATER: 4,
	}, true)
	real_generator.set_terrain_paint_mode(WorldGenerator.TERRAIN_PAINT_GLOBAL_NEIGHBORS)

	var real_terrain_root = Node2D.new()
	var real_object_root = Node2D.new()
	root.add_child(real_terrain_root)
	root.add_child(real_object_root)
	real_generator.init_chunks(real_terrain_root, real_object_root)
	for cy in range(-3, 4):
		for cx in range(-3, 4):
			real_generator.generate_chunk(cx, cy, false)

	var total_base_cells = 0
	for cy in range(-3, 4):
		for cx in range(-3, 4):
			var chunk = real_terrain_root.get_node("Chunk_%d_%d" % [cx, cy])
			var base_layer = chunk.get_node("BaseGrass") as TileMapLayer
			total_base_cells += base_layer.get_used_cells().size()
			var center_cell = Vector2i(WorldGenerator.CHUNK_SIZE / 2, WorldGenerator.CHUNK_SIZE / 2)
			assert(base_layer.get_cell_source_id(center_cell) >= 0)
	assert(total_base_cells >= 49 * WorldGenerator.CHUNK_SIZE * WorldGenerator.CHUNK_SIZE)

	quit(0)
