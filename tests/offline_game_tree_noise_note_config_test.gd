extends SceneTree

var _failed = false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")
	var tree_definition = _definition_line(source, "tree")

	_check(tree_definition.contains("\"placement_mode\": \"poisson_grid\""), "tree placement should use the restored poisson candidate pipeline")
	_check(tree_definition.contains("\"grid_cell_size\": 150"), "tree spacing should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"grid_density\": 0.58"), "tree base density should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"candidate_multiplier\": 14"), "tree candidate multiplier should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"min_distance_factor\": 0.70"), "tree minimum distance should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"frequency\": 0.018"), "forest noise frequency should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"threshold\": 0.54"), "forest noise threshold should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"softness\": 0.105"), "forest noise softness should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"power\": 1.45"), "forest noise power should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"octaves\": 4"), "forest noise octaves should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"gain\": 0.56"), "forest noise gain should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"temperature\": 0.48"), "tree temperature preference should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"moisture\": 0.66"), "tree moisture preference should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"soil_depth\": 0.80"), "tree soil preference should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"tolerance\": 0.34"), "tree ecology tolerance should match the Obsidian Perlin note")
	_check(tree_definition.contains("\"min_multiplier\": 0.08"), "tree ecology floor should match the Obsidian Perlin note")

	var generator_source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")
	_check(generator_source.contains("res_candidate_x_%s"), "poisson tree placement should use irregular per-candidate X positions")
	_check(generator_source.contains("res_candidate_y_%s"), "poisson tree placement should use irregular per-candidate Y positions")
	_check(generator_source.contains("accepted_positions"), "poisson tree placement should filter candidates by accepted distances")

	quit(1 if _failed else 0)


func _definition_line(source: String, id: String) -> String:
	var lines = source.split("\n")
	for i in range(lines.size()):
		if not lines[i].contains("\"id\": \"%s\"" % id):
			continue
		var text = lines[i]
		for j in range(i + 1, min(i + 14, lines.size())):
			if lines[j].contains("{\"id\":"):
				break
			text += lines[j]
		return text
	return ""


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
