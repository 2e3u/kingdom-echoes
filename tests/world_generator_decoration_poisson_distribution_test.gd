extends SceneTree

var _failed = false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")
	var function_text = _function_text(source, "_spawn_deco_poisson_grid")
	_check(function_text.contains("min_px"), "decoration poisson should sample in pixel space")
	_check(function_text.contains("_candidate_hash_float(\"dec_candidate_x_%s\""), "decoration poisson should use irregular candidate X positions")
	_check(function_text.contains("_candidate_hash_float(\"dec_candidate_y_%s\""), "decoration poisson should use irregular candidate Y positions")
	_check(function_text.contains("accepted_positions"), "decoration poisson should filter accepted positions by distance")

	var rng = RandomNumberGenerator.new()
	rng.seed = 20260529

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
	generator.set_decoration_defs([{
		"id": "grass_tuft",
		"biomes": WorldGenerator.BIOME_IDS,
		"placement_mode": "poisson_grid",
		"grid_cell_size": 96,
		"grid_density": 1.0,
		"candidate_multiplier": 14,
		"min_distance_factor": 0.30,
		"z_index": 0,
		"scale": 0.5,
		"texture": TextureGen.get_fiber_texture(),
	}])
	generator.init_chunks(terrain_root, object_root)
	for cy in range(-2, 3):
		generator.generate_chunk(0, cy)

	var jittered = 0
	var coarse_bands = {}
	for child in object_root.get_children():
		var sprite = child as Sprite2D
		if sprite == null:
			continue
		var offset_x = absf(fposmod(sprite.position.x, 64.0) - 32.0)
		var offset_y = absf(fposmod(sprite.position.y, 64.0) - 32.0)
		if offset_x > 1.0 or offset_y > 1.0:
			jittered += 1
		var band = floori(sprite.position.x / 128.0)
		coarse_bands[band] = int(coarse_bands.get(band, 0)) + 1

	_check(object_root.get_child_count() > 20, "poisson decoration test should spawn enough samples")
	_check(jittered > object_root.get_child_count() / 2, "decorations should not line up in tile centers")
	_check(_max_count(coarse_bands) < object_root.get_child_count() / 3, "decorations should not concentrate into persistent vertical bands")

	quit(1 if _failed else 0)


func _function_text(source: String, name: String) -> String:
	var start = source.find("func %s" % name)
	if start < 0:
		return ""
	var next = source.find("\nfunc ", start + 1)
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _max_count(counts: Dictionary) -> int:
	var highest = 0
	for value in counts.values():
		highest = max(highest, int(value))
	return highest


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
