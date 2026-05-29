extends SceneTree


func _init() -> void:
	var packed = load("res://scenes/main_menu.tscn") as PackedScene
	_check(packed != null, "main menu scene should load")

	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame

	_check(menu.get_script() != null, "main menu root should have a script")
	_check(menu.get_script().resource_path == "res://scripts/game/main_menu.gd", "main menu root should use main_menu.gd")
	_check(menu.get_node("%StartButton") is Button, "start button should use a rectangular Button hit area")
	_check((menu.get_node("%StartButton") as Button).flat, "start button should stay visually transparent")
	var save_mgr = menu.get_node_or_null("/root/SaveManager")
	var expect_disabled = save_mgr == null or not save_mgr.has_save()
	_check((menu.get_node("%ContinueButton") as Button).disabled == expect_disabled, "continue button disabled state should reflect whether a save exists")
	_check(menu.get_node("MenuPanel/Title") is TextureRect, "title should use the generated texture")
	_check(menu.GAME_SCENE_PATH == "res://scenes/kingdom_echoes.tscn", "start should target the game scene")

	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
