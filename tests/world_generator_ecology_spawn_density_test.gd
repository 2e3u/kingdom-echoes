extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260524

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	if not _check(generator.has_method("_get_ecology_spawn_multiplier"), "WorldGenerator should apply ecology layers to spawn density"):
		return

	var fungi_definition = {
		"id": "mushroom",
		"density": 0.5,
		"ecology": {
			"temperature": 0.46,
			"moisture": 0.82,
			"soil_depth": 0.78,
			"tolerance": 0.32,
			"min_multiplier": 0.10,
		},
	}

	var preferred = {"temperature": 0.48, "moisture": 0.84, "soil_depth": 0.76}
	var hostile = {"temperature": 0.90, "moisture": 0.12, "soil_depth": 0.16}
	var preferred_multiplier = generator._get_ecology_spawn_multiplier(fungi_definition, preferred)
	var hostile_multiplier = generator._get_ecology_spawn_multiplier(fungi_definition, hostile)

	_check(preferred_multiplier > 0.85, "preferred fungal ecology should keep most spawn density")
	_check(hostile_multiplier <= 0.20, "hostile fungal ecology should strongly suppress spawn density")

	var plain_definition = {"id": "plain", "density": 0.5}
	_check(is_equal_approx(generator._get_ecology_spawn_multiplier(plain_definition, hostile), 1.0), "definitions without ecology preferences should keep current density")

	var weighted_definition = {
		"id": "weighted",
		"density": 0.5,
		"ecology": {
			"temperature": {"target": 0.50, "tolerance": 0.20, "weight": 1.0},
			"moisture": {"target": 0.70, "tolerance": 0.25, "weight": 1.0},
			"soil_depth": {"target": 0.65, "tolerance": 0.30, "weight": 1.0},
			"min_multiplier": 0.05,
		},
	}
	var weighted_multiplier = generator._get_ecology_spawn_multiplier(weighted_definition, {"temperature": 0.50, "moisture": 0.70, "soil_depth": 0.65})
	_check(weighted_multiplier > 0.95, "dictionary ecology preferences should support target, tolerance, and weight")

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
