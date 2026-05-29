extends SceneTree

var _failed = false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260526

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var sample_a = generator._sample_ecology_layers(-320, 160)
	var sample_b = generator._sample_ecology_layers(960, -704)
	var has_all_layers = true
	for layer in ["temperature", "moisture", "soil_depth", "elevation"]:
		if not sample_a.has(layer):
			_check(false, "ecology sample should include %s" % layer)
			has_all_layers = false
			continue
		_check(sample_a[layer] >= 0.0 and sample_a[layer] <= 1.0, "%s should be normalized" % layer)

	if has_all_layers:
		_check(not is_equal_approx(sample_a["elevation"], sample_b["elevation"]), "elevation should vary across world space")

	var low_wet = {"temperature": 0.52, "moisture": 0.94, "soil_depth": 0.48, "elevation": 0.08}
	var high_rock = {"temperature": 0.38, "moisture": 0.24, "soil_depth": 0.10, "elevation": 0.92}
	_check(generator._select_biome_for_ecology(low_wet, 32, 32) == WorldGenerator.BIOME_WATER, "low wet elevation should become water")
	_check(generator._select_biome_for_ecology(high_rock, 32, 32) == WorldGenerator.BIOME_STONE, "high thin rocky elevation should become stone")

	var forest_definition = {
		"id": "tree",
		"ecology": {
			"temperature": {"target": 0.54, "tolerance": 0.35, "weight": 0.7},
			"moisture": {"target": 0.66, "tolerance": 0.28, "weight": 1.2},
			"soil_depth": {"target": 0.72, "tolerance": 0.26, "weight": 1.1},
			"elevation": {"target": 0.44, "tolerance": 0.34, "weight": 0.8},
			"min_multiplier": 0.05,
		},
	}
	var forest_site = {"temperature": 0.54, "moisture": 0.66, "soil_depth": 0.72, "elevation": 0.44}
	var alpine_site = {"temperature": 0.54, "moisture": 0.66, "soil_depth": 0.72, "elevation": 0.94}
	_check(generator._get_ecology_spawn_multiplier(forest_definition, forest_site) > 0.95, "matching elevation should keep tree density")
	_check(generator._get_ecology_spawn_multiplier(forest_definition, alpine_site) < 0.85, "wrong elevation should reduce tree density")

	var file = FileAccess.open("res://scripts/game/world_generator.gd", FileAccess.READ)
	_check(file != null, "WorldGenerator script should be readable")
	var source = file.get_as_text()
	_check(source.contains("_sample_base_elevation"), "WorldGenerator should sample base terrain elevation")
	_check(source.contains("_sample_local_relief"), "WorldGenerator should sample overlay/local relief")
	_check(source.contains("_get_biome_patch_noise"), "WorldGenerator should apply biome-specific patch noise")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
