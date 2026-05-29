extends SceneTree

var _failed := false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")

	_check(source.contains("const MAX_CHUNK_VIEW_RADIUS: int = 4"), "chunk view radius should be capped to avoid startup stutter")
	_check(source.contains("const CHUNK_VIEW_MARGIN: int = 1"), "chunk view radius should keep only one buffer ring beyond the visible area")
	_check(source.contains("var _last_chunk_view_radius: int = -1"), "chunk updates should track the last radius as well as the last chunk")
	_check(source.contains("if cx == _last_chunk.x and cy == _last_chunk.y and r == _last_chunk_view_radius:"), "chunk updates should refresh when camera viewport coverage changes")
	_check(source.contains("min(MAX_CHUNK_VIEW_RADIUS"), "dynamic radius should clamp to a performance-safe maximum")
	_check(source.contains("max(MIN_CHUNK_VIEW_RADIUS"), "dynamic radius should keep the minimum coverage")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
