extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)
	if not _check(generator.has_method("_get_clustered_spawn_density"), "WorldGenerator should expose clustered spawn density for ecological placement"):
		return

	var definition = {
		"id": "test_colony",
		"density": 0.0,
		"clustered": true,
		"scatter_density": 0.001,
		"cluster_cell_size": 64,
		"cluster_chance": 1.0,
		"cluster_radius_min": 12.0,
		"cluster_radius_max": 24.0,
		"cluster_density": 0.75,
	}

	var high_density_cells = 0
	var low_density_cells = 0
	var max_density = 0.0
	for y in range(-96, 96):
		for x in range(-96, 96):
			var density = generator._get_clustered_spawn_density(definition, x, y, "test")
			max_density = max(max_density, density)
			if density >= 0.35:
				high_density_cells += 1
			if density <= 0.002:
				low_density_cells += 1

	_check(max_density >= 0.65, "cluster centers should create dense local spawn zones")
	_check(high_density_cells > 200, "clustered placement should create visible colonies")
	_check(low_density_cells > high_density_cells * 5, "clustered placement should leave open space between colonies")

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
