extends SceneTree

var _failed := false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		return
	var source = file.get_as_text()

	_check(
		source.contains("WorldGenerator.BIOME_WATER: 4"),
		"OfflineGame should map water biomes to river terrain 4"
	)

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
