extends SceneTree

var _failed = false


func _init() -> void:
	var game_source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")
	var generator_source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")

	_check(game_source.contains("Thread.new()"), "OfflineGame should create worker threads for terrain chunk generation")
	_check(game_source.contains("_active_terrain_jobs"), "OfflineGame should track active terrain worker jobs")
	_check(game_source.contains("_collect_finished_terrain_jobs"), "OfflineGame should collect finished terrain jobs before applying chunks")
	_check(game_source.contains("_start_terrain_job"), "OfflineGame should start terrain jobs from the chunk load queue")
	_check(game_source.contains("wait_to_finish()"), "OfflineGame should join finished terrain worker threads")
	_check(generator_source.contains("func build_chunk_terrain_data"), "WorldGenerator should expose a thread-safe terrain data build phase")
	_check(generator_source.contains("func apply_chunk_terrain_data"), "WorldGenerator should expose a main-thread terrain apply phase")
	_check(generator_source.find("func build_chunk_terrain_data") < generator_source.find("func apply_chunk_terrain_data"), "terrain data should be prepared before it is applied")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
