extends SceneTree

var _failed = false


func _init() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/game/kingdom_echoes.gd")

	# 树木与花草使用的精灵贴图较大，必须缩放到原始 PNG 尺寸以下(scale 为 0.xx)，
	# 避免在地图上显示得过于巨大。这里只校验"被缩小过"，不锁死具体数值，便于后续微调。
	for id in ["tree_round", "tree_conifer", "flower", "grass_tuft", "tall_grass"]:
		var definition = _definition_line(source, id)
		_check(not definition.is_empty(), "%s should be configured" % id)
		_check(definition.contains("\"scale\": 0."), "%s sprite should be scaled down (scale < 1.0)" % id)

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
