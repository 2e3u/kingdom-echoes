extends SceneTree

var _failed = false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")

	_check(_definition_line(source, "tree").contains("\"scale\": 0.28"), "imported tree sprites should be scaled down from their source PNG size")
	_check(_definition_line(source, "flower").contains("\"scale\": 0.35"), "imported flower sprites should be scaled down from their source PNG size")
	_check(_definition_line(source, "grass_tuft").contains("\"scale\": 0.25"), "imported grass sprites should be scaled down from their source PNG size")
	_check(_definition_line(source, "tall_grass").contains("\"scale\": 0.30"), "imported tall grass sprites should be scaled down from their source PNG size")

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
