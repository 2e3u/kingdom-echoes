extends SceneTree


func _init() -> void:
	var game_source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")
	var generator_source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")
	var overlay_source = FileAccess.get_file_as_string("res://scripts/game/ecology_debug_overlay.gd")

	_check(game_source.contains("KEY_TAB"), "ecology debug overlay should cycle with Tab")
	_check(game_source.contains("_cycle_ecology_debug_layer"), "OfflineGame should expose a debug overlay cycle method")
	_check(game_source.contains("EcologyDebugOverlay"), "OfflineGame should create the ecology debug overlay")
	_check(generator_source.contains("func get_debug_ecology_value"), "WorldGenerator should expose ecology debug layer values")
	_check(generator_source.contains("\"elevation\""), "WorldGenerator should expose elevation as an ecology layer")
	_check(generator_source.contains("func _smootherstep"), "WorldGenerator should expose fifth-order smoothing for ecology shaping")
	_check(generator_source.contains("forest_raw"), "WorldGenerator should expose raw forest noise for visual comparison")
	_check(overlay_source.contains("forest_raw"), "EcologyDebugOverlay should include raw forest noise")
	_check(overlay_source.contains("elevation"), "EcologyDebugOverlay should include terrain elevation")
	_check(overlay_source.contains("tree_density"), "EcologyDebugOverlay should include final tree density")
	_check(overlay_source.contains("class_name EcologyDebugOverlay"), "EcologyDebugOverlay should be implemented as a reusable Node2D")
	_check(overlay_source.contains("queue_redraw()"), "EcologyDebugOverlay should redraw only when layer or chunks change")

	quit(1 if _failed else 0)


var _failed = false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
