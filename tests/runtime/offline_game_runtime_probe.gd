extends Node

var _failed := false


func _ready() -> void:
	var game = load("res://scenes/kingdom_echoes.tscn").instantiate() as OfflineGame
	if not _check(game != null, "OfflineGame scene should instantiate"):
		get_tree().quit(1)
		return
	add_child(game)

	await get_tree().process_frame
	await get_tree().process_frame

	var total_base_cells = _get_total_base_cells(game)
	_check(total_base_cells >= 81 * WorldGenerator.CHUNK_SIZE * WorldGenerator.CHUNK_SIZE, "startup should paint at least the capped 9x9 base terrain area")

	var max_desired_chunks = int(pow(game.MAX_CHUNK_VIEW_RADIUS * 2 + 1, 2))
	_check(game._desired_chunks.size() <= max_desired_chunks, "desired chunk count should stay capped for performance")
	_check(game._loaded_chunks.size() == game._desired_chunks.size(), "startup should finish loading desired terrain chunks")
	_check(game._pending_load_chunks.is_empty(), "terrain load queue should be empty after startup preload")
	_check(game.camera.position == game.player.position, "camera should start on the loaded player chunk")

	game.player.position = Vector2(1024, 128)
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	var moved_chunk = WorldGenerator.world_position_to_chunk(game.player.position, game.TILE_SIZE)
	game._update_chunks(moved_chunk.x, moved_chunk.y)
	game._process_chunk_queues(game._get_initial_chunk_load_budget(), game.CHUNK_UNLOADS_PER_FRAME)
	await get_tree().process_frame

	_check(game._pending_load_chunks.is_empty(), "terrain load queue should be empty after teleporting to the screenshot area")
	_check(_camera_view_has_base_terrain(game), "BaseGrass should cover sampled cells across the current camera viewport")

	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false


func _get_total_base_cells(game: OfflineGame) -> int:
	var total = 0
	for child in game.terrain_root.get_children():
		var base_layer = child.get_node_or_null("BaseGrass") as TileMapLayer
		if base_layer != null:
			total += base_layer.get_used_cells().size()
	return total


func _camera_view_has_base_terrain(game: OfflineGame) -> bool:
	var viewport_size = game.get_viewport_rect().size
	var half_world = Vector2(
		viewport_size.x / maxf(game.camera.zoom.x, 0.001),
		viewport_size.y / maxf(game.camera.zoom.y, 0.001)
	) * 0.5
	var top_left = game.camera.position - half_world
	var bottom_right = game.camera.position + half_world
	for y_ratio in [0.1, 0.5, 0.9]:
		for x_ratio in [0.1, 0.5, 0.9]:
			var world_pos = Vector2(
				lerpf(top_left.x, bottom_right.x, x_ratio),
				lerpf(top_left.y, bottom_right.y, y_ratio)
			)
			var cell = WorldGenerator.world_position_to_cell(world_pos, game.TILE_SIZE)
			if not _has_base_terrain_cell(game, cell):
				push_error("missing BaseGrass at sampled viewport cell %s world_pos=%s" % [cell, world_pos])
				return false
	return true


func _has_base_terrain_cell(game: OfflineGame, global_cell: Vector2i) -> bool:
	var chunk_key = WorldGenerator.cell_to_chunk(global_cell)
	var chunk = game.terrain_root.get_node_or_null("Chunk_%d_%d" % [chunk_key.x, chunk_key.y])
	if chunk == null:
		return false
	var base_layer = chunk.get_node_or_null("BaseGrass") as TileMapLayer
	if base_layer == null:
		return false
	var local_cell = Vector2i(
		global_cell.x - chunk_key.x * WorldGenerator.CHUNK_SIZE,
		global_cell.y - chunk_key.y * WorldGenerator.CHUNK_SIZE
	)
	return base_layer.get_cell_source_id(local_cell) >= 0
