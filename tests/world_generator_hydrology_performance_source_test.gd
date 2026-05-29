extends SceneTree

var _failed := false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")
	var multiplier_start = source.find("func _get_water_spawn_multiplier")
	var multiplier_end = source.find("func _get_region_spawn_multiplier")
	if not _check(multiplier_start >= 0 and multiplier_end > multiplier_start, "water spawn multiplier should exist before region multiplier"):
		quit(1)
		return

	var body = source.substr(multiplier_start, multiplier_end - multiplier_start)
	_check(body.contains("var has_water_rules"), "water spawn multiplier should detect whether a definition has hydrology rules")
	_check(
		body.find("if not has_water_rules:") < body.find("if is_water_cell"),
		"default resource and decoration definitions should skip water checks entirely"
	)
	_check(source.contains("_water_cell_cache"), "water mask lookups should be cached")
	_check(source.contains("_river_bank_distance_cache"), "river bank distance lookups should be cached")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
