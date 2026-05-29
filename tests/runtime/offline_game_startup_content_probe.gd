extends Node

var _failed = false


func _ready() -> void:
	var game = load("res://scenes/kingdom_echoes.tscn").instantiate() as OfflineGame
	if not _check(game != null, "OfflineGame scene should instantiate"):
		get_tree().quit(1)
		return
	add_child(game)

	await get_tree().process_frame
	await get_tree().process_frame

	await _wait_for_content(game, 120)

	_check(game.resource_sprites.size() > 0, "startup should stream in nearby harvestable vegetation")
	_check(_count_decorations(game) > 0, "startup should stream in nearby decorative vegetation")

	get_tree().quit(1 if _failed else 0)


func _count_decorations(game: OfflineGame) -> int:
	var count = 0
	for child in game.object_root.get_children():
		if child != game.player and child is Sprite2D:
			count += 1
	return count


func _wait_for_content(game: OfflineGame, max_frames: int) -> void:
	for i in range(max_frames):
		if game.resource_sprites.size() > 0 and _count_decorations(game) > 0:
			return
		await get_tree().process_frame


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
