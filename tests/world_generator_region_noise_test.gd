extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260524

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	if not _check(generator.has_method("_get_region_spawn_multiplier"), "WorldGenerator should expose region noise for element patches"):
		return

	var definition = {
		"id": "tree",
		"cluster_group": "forest",
		"region_noise": {
			"group": "forest",
			"frequency": 0.035,
			"threshold": 0.52,
			"softness": 0.16,
			"min_multiplier": 0.0,
		},
	}

	var high_cells = 0
	var low_cells = 0
	var transitions = 0
	var checks = 0
	for y in range(-96, 96, 4):
		var last_high = generator._get_region_spawn_multiplier(definition, -96, y, "res") >= 0.55
		for x in range(-92, 96, 4):
			var multiplier = generator._get_region_spawn_multiplier(definition, x, y, "res")
			var current_high = multiplier >= 0.55
			if multiplier >= 0.75:
				high_cells += 1
			if multiplier <= 0.20:
				low_cells += 1
			if current_high != last_high:
				transitions += 1
			last_high = current_high
			checks += 1

	_check(high_cells > 20, "region noise should create high-density patches")
	_check(low_cells > 20, "region noise should leave clear gaps between patches")
	_check(float(transitions) / float(checks) < 0.35, "region noise should be spatially coherent, not per-cell scatter")

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
