extends SceneTree

var _failed := false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")
	_check(source.contains("RIVER_BASIN_WIDTH"), "river generation should use deterministic basin corridors")
	_check(source.contains("func _get_main_river_x"), "river generation should expose a continuous main channel centerline")
	_check(source.contains("func _get_tributary_distance"), "river generation should include tributary corridor sampling")
	_check(
		source.find("func _is_river_core_cell") < source.find("func _get_main_river_x"),
		"river core sampling should route through the corridor network helpers"
	)
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
