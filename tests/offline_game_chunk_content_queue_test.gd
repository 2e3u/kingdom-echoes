extends SceneTree

var _failed = false


func _init() -> void:
	var game_source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")
	var generator_source = FileAccess.get_file_as_string("res://scripts/game/world_generator.gd")

	_check(generator_source.contains("generate_chunk(cx: int, cy: int, spawn_content: bool = true)"), "WorldGenerator should allow terrain-only chunk generation")
	_check(generator_source.contains("func populate_chunk_content"), "WorldGenerator should populate resources and decorations as a second phase")
	_check(generator_source.contains("func populate_chunk_resources"), "WorldGenerator should allow resource population as its own phase")
	_check(generator_source.contains("func populate_chunk_decorations"), "WorldGenerator should allow decoration population as its own phase")
	_check(generator_source.contains("func get_resource_definition_count"), "WorldGenerator should expose resource definition count for fine-grained queues")
	_check(generator_source.contains("func get_decoration_definition_count"), "WorldGenerator should expose decoration definition count for fine-grained queues")
	_check(generator_source.contains("func populate_chunk_resource_definition"), "WorldGenerator should populate one resource definition at a time")
	_check(generator_source.contains("func populate_chunk_decoration_definition"), "WorldGenerator should populate one decoration definition at a time")
	_check(game_source.contains("var _pending_content_chunks: Array[Vector2i] = []"), "OfflineGame should queue chunk content separately from terrain")
	_check(game_source.contains("var _pending_decoration_chunks: Array[Vector2i] = []"), "OfflineGame should queue chunk decorations separately from resources")
	_check(game_source.contains("var _pending_resource_jobs: Array[Dictionary] = []"), "OfflineGame should queue individual resource definition jobs")
	_check(game_source.contains("var _pending_decoration_jobs: Array[Dictionary] = []"), "OfflineGame should queue individual decoration definition jobs")
	_check(game_source.contains("const CONTENT_JOBS_PER_FRAME: int = 4"), "content jobs should be spread across frames to avoid chunk loading stalls")
	_check(game_source.contains("var _content_loaded_chunks: Array[Vector2i] = []"), "OfflineGame should track chunks with fully preloaded content")
	_check(game_source.contains("_queue_chunk_content(key)"), "OfflineGame should queue content after terrain generation")
	_check(game_source.contains("_queue_chunk_decoration(key)"), "OfflineGame should queue decorations after resource generation")
	_check(game_source.contains("populate_chunk_resource_definition"), "OfflineGame should run one resource definition per content job")
	_check(game_source.contains("populate_chunk_decoration_definition"), "OfflineGame should run one decoration definition per content job")
	_check(game_source.contains("for i in range(CONTENT_JOBS_PER_FRAME)"), "OfflineGame should process several content jobs per frame")
	_check(game_source.contains("if key in _desired_chunks and key in _loaded_chunks and key not in _content_loaded_chunks"), "content queue should skip stale, unloaded, or already preloaded chunks")
	_check(not game_source.contains("if did_load_terrain:\n\t\treturn"), "chunk queue should keep processing content even when terrain loaded this frame")
	_check(game_source.find("if not _pending_resource_jobs.is_empty()") < game_source.find("if not _pending_content_chunks.is_empty()"), "content queue should finish nearby chunk jobs before opening more chunks")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
