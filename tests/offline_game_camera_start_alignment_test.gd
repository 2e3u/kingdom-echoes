extends SceneTree

var _failed := false


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if not _check(file != null, "OfflineGame script should be readable"):
		quit(1)
		return
	var source = file.get_as_text()
	var camera_position_index = source.find("camera.position = player.position")
	var smoothing_index = source.find("camera.position_smoothing_enabled = true")

	_check(camera_position_index >= 0, "camera should start at the player before smoothing begins")
	_check(smoothing_index >= 0, "camera should still use smoothing after startup alignment")
	if camera_position_index >= 0 and smoothing_index >= 0:
		_check(camera_position_index < smoothing_index, "camera should align to the player before position smoothing is enabled")
	_check(source.contains("camera.reset_smoothing()"), "camera smoothing should be reset after becoming current")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
