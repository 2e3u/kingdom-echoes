extends SceneTree

var _failed = false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		return
	var source = file.get_as_text()

	_check(source.contains("func _get_initial_chunk_load_budget()"), "startup should derive its terrain preload budget from the visible chunk radius")
	_check(source.contains("const CONTENT_JOBS_PER_FRAME: int = 4"), "content queue should spread resource and decoration generation across frames")
	_check(source.contains("const INITIAL_SYNC_CHUNKS"), "startup core preload count should be a tunable constant")
	_check(source.contains("_drain_initial_terrain_jobs(INITIAL_SYNC_CHUNKS)"), "startup should synchronously preload only a bounded core of chunks, then stream the rest across frames")
	_check(not source.contains("_preload_initial_chunk_content(start_chunk, STARTUP_CONTENT_RADIUS)"), "startup should not synchronously spawn nearby vegetation")
	_check(not source.contains("_process_chunk_queues(9999, 9999)"), "startup should not synchronously load every visible chunk")
	_check(source.contains("desired.sort_custom"), "chunk queue should prioritize nearby chunks first")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
