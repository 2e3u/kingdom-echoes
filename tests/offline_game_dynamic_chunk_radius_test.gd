extends SceneTree

var _failed := false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		quit(1)
		return
	var source = file.get_as_text()

	_check(source.contains("func _get_chunk_view_radius()"), "OfflineGame should compute chunk view radius dynamically")
	_check(source.contains("get_viewport_rect().size"), "chunk radius should use the live viewport size")
	_check(source.contains("camera.zoom.x"), "chunk radius should use camera horizontal zoom")
	_check(source.contains("camera.zoom.y"), "chunk radius should use camera vertical zoom")
	_check(source.contains("WorldGenerator.CHUNK_SIZE"), "chunk radius should convert visible tiles into chunk coverage")
	_check(source.contains("visible_chunk_radius + CHUNK_VIEW_MARGIN"), "chunk radius should include extra margin around the visible area")
	_check(source.contains("func _get_initial_chunk_load_budget()"), "startup preload should use the dynamic radius")
	_check(source.contains("pow(radius * 2 + 1, 2)"), "startup preload should cover the full square of desired chunks")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
