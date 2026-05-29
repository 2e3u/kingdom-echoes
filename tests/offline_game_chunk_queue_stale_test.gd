extends SceneTree

var _failed = false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		return
	var source = file.get_as_text()

	_check(source.contains("var _desired_chunks: Array[Vector2i] = []"), "chunk queue should track desired chunks separately from loaded chunks")
	_check(source.contains("_pending_load_chunks.clear()"), "chunk queue should discard stale pending loads when the player moves quickly")
	_check(source.contains("_pending_content_chunks.erase(key)"), "chunk queue should discard stale pending content when a chunk unloads")
	_check(source.contains("if key not in _desired_chunks"), "chunk loader should skip chunks that are no longer desired")
	_check(source.contains("_pending_unload_chunks.erase(key)"), "chunk queue should cancel pending unloads when a chunk becomes desired again")
	_check(source.contains("_loaded_chunks.append(key)"), "chunk loader should mark chunks loaded only after generation finishes")
	_check(not source.contains("_loaded_chunks = desired"), "desired chunks must not be treated as already loaded")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
