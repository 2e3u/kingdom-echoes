extends SceneTree

var _failed = false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		return
	var source = file.get_as_text()

	var groups = {
		"mushrooms": 3,
		"rocks": 3,
		"twigs": 3,
		"leaves": 2,
		"tall_grass": 2,
		"flowers": 4,
	}
	for folder in groups:
		for i in range(1, int(groups[folder]) + 1):
			var path = _expected_path(folder, i)
			_check(source.contains(path), "OfflineGame should reference decoration texture: %s" % path)
			_check(FileAccess.file_exists(path), "decoration texture should exist: %s" % path)

	for path in [
		"res://assets/vegetation/mushrooms/mushroom_01.png",
		"res://assets/vegetation/rocks/rock_01.png",
		"res://assets/vegetation/twigs/twig_01.png",
		"res://assets/vegetation/leaves/leaf_pile_01.png",
		"res://assets/vegetation/tall_grass/tall_grass_01.png",
		"res://assets/vegetation/flowers/flower_01.png",
	]:
		_check(FileAccess.file_exists(path), "decoration texture should exist: %s" % path)

	quit(1 if _failed else 0)


func _expected_path(folder: String, index: int) -> String:
	var prefixes = {
		"mushrooms": "mushroom",
		"rocks": "rock",
		"twigs": "twig",
		"leaves": "leaf_pile",
		"tall_grass": "tall_grass",
		"flowers": "flower",
	}
	return "res://assets/vegetation/%s/%s_%02d.png" % [folder, prefixes[folder], index]


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
