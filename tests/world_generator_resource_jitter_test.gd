extends SceneTree

var _failed = false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")
	_check(
		not source.contains("for cell_y in range(start_cell_y") and not source.contains("for cell_x in range(start_cell_x"),
		"poisson resource placement must not sample from fixed vertical grid columns"
	)

	var rng = RandomNumberGenerator.new()
	rng.seed = 20260524

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
	generator.set_resource_defs([{
		"id": "tree",
		"item": "wood",
		"biomes": WorldGenerator.BIOME_IDS,
		"placement_mode": "poisson_grid",
		"spacing_scale": 1.0,
		"grid_cell_size": 128,
		"grid_density": 1.0,
		"candidate_multiplier": 10,
		"min_distance_factor": 0.25,
		"texture": TextureGen.get_tree_texture(),
	}])
	generator.init_chunks(terrain_root, object_root)
	for cy in range(-2, 3):
		generator.generate_chunk(0, cy)

	var jittered = 0
	var occupied_columns = {}
	var coarse_bands = {}
	for child in object_root.get_children():
		var sprite = child as Sprite2D
		if sprite == null:
			continue
		var offset_x = absf(fposmod(sprite.position.x, 64.0) - 32.0)
		var offset_y = absf(fposmod(sprite.position.y, 64.0) - 32.0)
		if offset_x > 1.0 or offset_y > 1.0:
			jittered += 1
		occupied_columns[floori(sprite.position.x / 64.0)] = true
		var band = floori(sprite.position.x / 128.0)
		coarse_bands[band] = int(coarse_bands.get(band, 0)) + 1

	_check(object_root.get_child_count() > 0, "resource test should spawn resources")
	_check(object_root.get_child_count() > 20, "poisson resource placement should generate enough non-grid candidates for distribution checks")
	_check(jittered > object_root.get_child_count() / 2, "resources should jitter inside cells instead of lining up in visible columns")
	_check(occupied_columns.size() > 2, "poisson resource placement should spread trees across multiple columns")
	_check(
		_max_count(coarse_bands) < object_root.get_child_count() / 3,
		"poisson resource placement should not concentrate trees into persistent vertical bands: max=%d total=%d" % [_max_count(coarse_bands), object_root.get_child_count()]
	)

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false


func _max_count(counts: Dictionary) -> int:
	var highest = 0
	for value in counts.values():
		highest = max(highest, int(value))
	return highest
