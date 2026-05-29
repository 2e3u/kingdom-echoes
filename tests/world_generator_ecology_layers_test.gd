extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260524

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	if not _check(generator.has_method("_sample_ecology_layers"), "WorldGenerator should expose ecological noise layers"):
		return
	if not _check(generator.has_method("_select_biome_for_ecology"), "WorldGenerator should select biomes from ecological layers"):
		return

	var lush = {"temperature": 0.52, "moisture": 0.68, "soil_depth": 0.82, "elevation": 0.44}
	var desert = {"temperature": 0.88, "moisture": 0.12, "soil_depth": 0.22, "elevation": 0.42}
	var tundra = {"temperature": 0.08, "moisture": 0.42, "soil_depth": 0.34, "elevation": 0.68}
	var wetland = {"temperature": 0.62, "moisture": 0.91, "soil_depth": 0.88, "elevation": 0.20}
	var mountain = {"temperature": 0.31, "moisture": 0.30, "soil_depth": 0.06, "elevation": 0.86}

	_check(generator._select_biome_for_ecology(lush, 10, 10) in [WorldGenerator.BIOME_GRASS, WorldGenerator.BIOME_FOREST], "deep temperate soil should become grassland or forest")
	_check(generator._select_biome_for_ecology(desert, 10, 10) == WorldGenerator.BIOME_SAND, "hot dry shallow soil should become sand")
	_check(generator._select_biome_for_ecology(tundra, 10, 10) == WorldGenerator.BIOME_SNOW, "cold regions should become snow")
	_check(generator._select_biome_for_ecology(wetland, 10, 10) in [WorldGenerator.BIOME_SWAMP, WorldGenerator.BIOME_WATER], "very wet deep soil should become swamp or water")
	_check(generator._select_biome_for_ecology(mountain, 10, 10) == WorldGenerator.BIOME_STONE, "thin rocky soil should become stone")

	var first = generator._sample_ecology_layers(128, -256)
	var second = generator._sample_ecology_layers(128, -256)
	for key in ["temperature", "moisture", "soil_depth", "elevation"]:
		_check(first.has(key), "ecology sample should include %s" % key)
		_check(first[key] >= 0.0 and first[key] <= 1.0, "%s should be normalized" % key)
		_check(is_equal_approx(first[key], second[key]), "%s should be deterministic" % key)

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
