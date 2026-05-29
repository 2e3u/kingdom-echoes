extends SceneTree

var _failed = false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")

	var round_tree = _definition_line(source, "tree_round")
	var conifer_tree = _definition_line(source, "tree_conifer")
	_check(not round_tree.is_empty(), "round tree forest definition should exist")
	_check(not conifer_tree.is_empty(), "conifer tree forest definition should exist")
	_check(round_tree.contains("\"cluster_group\": \"round_forest\""), "round trees should use their own forest cluster")
	_check(conifer_tree.contains("\"cluster_group\": \"conifer_forest\""), "conifer trees should use their own forest cluster")
	_check(round_tree.contains("\"group\": \"round_forest\""), "round trees should use a separate Perlin region")
	_check(conifer_tree.contains("\"group\": \"conifer_forest\""), "conifer trees should use a separate Perlin region")
	_check(round_tree.contains("\"scale\": 0.36"), "round trees should be visually larger")
	_check(conifer_tree.contains("\"scale\": 0.40"), "conifer trees should be visually larger")

	# 树木限定在 TREE_BIOME_IDS（排除泥土层 dirt 与沙漠层 sand），不再生长于全部陆地地形
	for id in ["tree_round", "tree_conifer"]:
		var tree_def = _definition_line(source, id)
		_check(tree_def.contains("TREE_BIOME_IDS"), "%s should grow only on tree biomes, excluding dirt/sand" % id)
		_check(tree_def.contains("\"block_on_water\": true"), "%s should explicitly reject water cells" % id)

	# 其余小植被仍允许在所有非水地形上生长
	for id in ["flower", "grass_tuft", "mushroom", "leaf_pile", "twig", "tall_grass"]:
		var definition = _definition_line(source, id)
		_check(definition.contains("LAND_BIOME_IDS"), "%s should be allowed on every non-water biome" % id)
		_check(definition.contains("\"block_on_water\": true"), "%s should explicitly reject water cells" % id)

	for id in ["flower", "grass_tuft", "mushroom", "leaf_pile", "twig", "tall_grass"]:
		var definition = _definition_line(source, id)
		_check(definition.contains("\"placement_mode\": \"poisson_grid\""), "%s should use poisson scatter instead of per-tile columns" % id)
		_check(definition.contains("\"grid_cell_size\""), "%s should control spacing through poisson grid cell size" % id)
		_check(definition.contains("\"position_jitter\""), "%s should jitter inside cells" % id)

	quit(1 if _failed else 0)


func _definition_line(source: String, id: String) -> String:
	var lines = source.split("\n")
	for i in range(lines.size()):
		if not lines[i].contains("\"id\": \"%s\"" % id):
			continue
		var text = lines[i]
		for j in range(i + 1, min(i + 16, lines.size())):
			if lines[j].contains("{\"id\":"):
				break
			text += lines[j]
		return text
	return ""


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
