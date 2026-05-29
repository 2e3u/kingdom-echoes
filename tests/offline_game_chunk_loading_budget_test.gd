extends SceneTree

var _failed = false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		return
	var source = file.get_as_text()

	_check(source.contains("const MIN_CHUNK_VIEW_RADIUS: int = 3"), "chunk view radius should keep a minimum neighborhood loaded")
	_check(source.contains("const MAX_CHUNK_VIEW_RADIUS: int = 4"), "chunk view radius should cap startup and movement loading cost")
	_check(source.contains("const CHUNK_VIEW_MARGIN: int = 1"), "chunk view radius should include one safety ring beyond the viewport")
	_check(source.contains("func _get_chunk_view_radius()"), "chunk view radius should be computed from the live camera viewport")
	_check(source.contains("get_viewport_rect().size"), "chunk view radius should account for the current window size")
	_check(source.contains("camera.zoom"), "chunk view radius should account for camera zoom")
	_check(source.contains("const CHUNK_LOADS_PER_FRAME: int = 4"), "terrain chunk loading should keep up with the zoomed-out camera")
	_check(source.contains("const CHUNK_QUEUE_FRAME_INTERVAL: int = 1"), "terrain should load every frame so grey gaps do not appear while moving")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
