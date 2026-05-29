extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 91

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var tree_def = {
		"id": "tree",
		"clustered": true,
		"cluster_group": "forest",
		"scatter_density": 0.0,
		"cluster_cell_size": 96,
		"cluster_chance": 1.0,
		"cluster_radius_min": 18.0,
		"cluster_radius_max": 42.0,
		"cluster_density": 0.45,
	}
	var leaf_def = tree_def.duplicate()
	leaf_def["id"] = "leaf_pile"
	leaf_def["cluster_density"] = 0.9

	var shared_hotspots = 0
	var tree_only_hotspots = 0
	for y in range(-128, 128):
		for x in range(-128, 128):
			var tree_density = generator._get_clustered_spawn_density(tree_def, x, y, "res")
			var leaf_density = generator._get_clustered_spawn_density(leaf_def, x, y, "dec")
			if tree_density > 0.20 and leaf_density > 0.40:
				shared_hotspots += 1
			elif tree_density > 0.20 and leaf_density <= 0.01:
				tree_only_hotspots += 1

	_check(shared_hotspots > 500, "shared cluster groups should align forest-dependent decorations with trees")
	_check(tree_only_hotspots < 50, "forest decorations should not drift away from tree cluster centers")

	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
