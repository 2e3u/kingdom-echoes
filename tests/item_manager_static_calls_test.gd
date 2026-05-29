extends SceneTree


func _init() -> void:
	var file = FileAccess.open("res://scripts/server/item_manager.gd", FileAccess.READ)
	if not _check(file != null, "ItemManager script should be readable"):
		return
	var source = file.get_as_text()

	_check(source.contains("const ItemData = preload(\"res://scripts/shared/item_data.gd\")"), "ItemManager should call item data static methods through the script type")
	_check(not source.contains("ItemDatabase.get_item("), "ItemManager should not call static get_item through the ItemDatabase autoload instance")
	_check(source.contains("ItemData.get_item(item_id)"), "ItemManager should still look up item definitions by item id")

	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
