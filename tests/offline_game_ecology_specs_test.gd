extends SceneTree

var _failed = false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		return
	var source = file.get_as_text()

	for id in ["flower", "grass_tuft", "leaf_pile", "twig", "tall_grass", "mushroom"]:
		_check(source.contains("\"id\": \"%s\"" % id), "%s decoration should be configured" % id)
		_check(_definition_line(source, id).contains("\"clustered\": true"), "%s should use clustered ecological placement" % id)

	for id in ["tree_round", "tree_conifer", "herb_red", "fiber_plant", "flower", "grass_tuft", "leaf_pile", "twig", "tall_grass", "mushroom"]:
		var definition = _definition_line(source, id)
		_check(definition.contains("\"region_noise\""), "%s should use coherent region noise" % id)
		_check(definition.contains("\"ecology\""), "%s should be gated by ecology layers" % id)
		_check(definition.contains("\"temperature\""), "%s should use the temperature layer" % id)
		_check(definition.contains("\"moisture\""), "%s should use the moisture layer" % id)
		_check(definition.contains("\"soil_depth\""), "%s should use the soil depth layer" % id)

	_check(_definition_line(source, "leaf_pile").contains("\"cluster_group\": \"forest\""), "leaf piles should share forest clusters")
	_check(_definition_line(source, "twig").contains("\"cluster_group\": \"forest\""), "twigs should share forest clusters")
	_check(_definition_line(source, "flower").contains("\"cluster_group\": \"meadow\""), "flowers should use meadow clusters")
	_check(_definition_line(source, "grass_tuft").contains("\"cluster_group\": \"meadow\""), "grass tufts should use meadow clusters")
	_check(_definition_line(source, "tall_grass").contains("\"cluster_group\": \"wet_grass\""), "tall grass should use wet grass clusters")
	_check(_definition_line(source, "mushroom").contains("\"cluster_group\": \"fungi\""), "mushrooms should use fungi clusters")

	quit(1 if _failed else 0)


func _definition_line(source: String, id: String) -> String:
	var lines = source.split("\n")
	for i in range(lines.size()):
		if not lines[i].contains("\"id\": \"%s\"" % id):
			continue
		var text = lines[i]
		for j in range(i + 1, min(i + 14, lines.size())):
			if lines[j].contains("{\"id\":"):
				break
			text += lines[j]
		return text
	return ""


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
