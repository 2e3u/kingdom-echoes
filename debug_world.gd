extends SceneTree

func _init():
	print("========== WorldGenerator DEBUG ==========")
	
	# Setup
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	const TILE_SIZE = 48
	const WORLD_W = 100
	const WORLD_H = 75
	
	# Build configs exactly like kingdom_echoes.gd
	var biome_configs: Array[Dictionary] = []
	for biome_id in ["grass", "dirt", "sand", "snow", "swamp", "forest_floor", "stone_path", "water"]:
		var path = "res://assets/sprites/atlas_%s.png" % biome_id
		var exists = FileAccess.file_exists(path)
		var tex = load(path) if exists else null
		print("BIOME %s: path=%s file_exists=%s tex=%s" % [biome_id, path, exists, "OK" if tex else "NULL"])
		if tex:
			print("  tex type=%s size=%s" % [tex.get_class(), tex.get_size()])
		biome_configs.append({
			"id": biome_id,
			"atlas_path": path,
			"variant_count": 9,
		})
	
	# Create WorldGenerator
	var wg = WorldGenerator.new()
	wg.setup(rng, TILE_SIZE, WORLD_W, WORLD_H)
	wg.set_biome_configs(biome_configs)
	wg.set_resource_defs([])
	wg.set_decoration_defs([])
	
	# Generate biome grid
	wg._generate_biome_grid()
	print("\n--- biome_grid ---")
	print("Size: %d rows x %d cols" % [wg.biome_grid.size(), wg.biome_grid[0].size() if wg.biome_grid.size() > 0 else 0])
	
	# Count biomes
	var counts = {}
	for row in wg.biome_grid:
		for b in row:
			var bid = WorldGenerator.BIOME_IDS[b]
			counts[bid] = counts.get(bid, 0) + 1
	print("Biome distribution:")
	for bid in counts:
		print("  %s: %d (%.1f%%)" % [bid, counts[bid], counts[bid] * 100.0 / (WORLD_W * WORLD_H)])
	
	# Build TileSet
	print("\n--- TileSet ---")
	var ts = wg._build_tileset()
	print("Source count: %d" % ts.get_source_count())
	for i in range(ts.get_source_count()):
		var src_id = ts.get_source_id(i)
		print("  Source %d: id=%d" % [i, src_id])
	
	# Build TileMap
	print("\n--- TileMap ---")
	var tm = wg._build_tilemap()
	print("TileSet valid: %s" % ("YES" if tm.tile_set else "NO"))
	
	# Check some cells
	for y in range(0, 5):
		for x in range(0, 5):
			var src = tm.get_cell_source_id(0, Vector2i(x, y))
			var ac = tm.get_cell_atlas_coords(0, Vector2i(x, y))
			var bid = WorldGenerator.BIOME_IDS[wg.biome_grid[y][x]]
			print("  Cell (%d,%d): src=%d atlas=%s biome=%s" % [x, y, src, ac, bid])
	
	print("\n========== DEBUG COMPLETE ==========")
	quit()
