extends SceneTree


func _init() -> void:
	var file = FileAccess.open("res://scripts/game/kingdom_echoes.gd", FileAccess.READ)
	if file == null:
		push_error("OfflineGame script should be readable")
		quit(1)
		return
	var source = file.get_as_text()
	if not source.contains("camera.zoom = Vector2(0.35, 0.35)"):
		push_error("camera should start zoomed out for macro ecology inspection")
		quit(1)
		return
	quit(0)
