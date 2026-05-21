extends Control
class_name CraftingUI

## 客户端制造界面 — 配方列表 + 材料预览 + 制造按钮

var _current_station: int = SharedEnums.CraftStation.HAND
var _available_recipes: Array[Dictionary] = []
var _craft_cooldown: bool = false

@export var _recipe_list: ItemList = null
@export var _materials_label: Label = null
@export var _craft_button: Button = null


func _ready() -> void:
	hide()
	if _craft_button:
		_craft_button.pressed.connect(_on_craft_pressed)
	if _recipe_list:
		_recipe_list.item_selected.connect(_on_recipe_selected)
	if not NetworkRPC.craft_result_received.is_connected(_on_craft_result):
		NetworkRPC.craft_result_received.connect(_on_craft_result)


func open(station: int, recipes: Array[Dictionary]) -> void:
	_current_station = station
	_available_recipes = recipes
	_refresh_recipe_list()
	show()


func close() -> void:
	hide()


func _refresh_recipe_list() -> void:
	if not _recipe_list:
		return
	_recipe_list.clear()
	for recipe in _available_recipes:
		var item_def = ItemDatabase.get_item(recipe.get("output_item_id", ""))
		var name = item_def.get("name", "???")
		_recipe_list.add_item("%s x%d" % [name, recipe.get("output_quantity", 1)])


func _on_craft_pressed() -> void:
	if not _recipe_list or _craft_cooldown:
		return
	var selected = _recipe_list.get_selected_items()
	if selected.is_empty():
		return
	var idx = selected[0]
	if idx >= _available_recipes.size():
		return
	var recipe = _available_recipes[idx]
	_craft_cooldown = true
	if _craft_button:
		_craft_button.disabled = true
	NetworkRPC.rpc("_receive_craft_action", {
		"recipe_id": recipe.get("recipe_id", ""),
		"station": _current_station,
	})


func _on_craft_result(result: Dictionary) -> void:
	_craft_cooldown = false
	if _craft_button:
		_craft_button.disabled = false
	# 结果通过 UI 弹窗或日志显示
	var msg = result.get("message", "")
	if not msg.is_empty():
		print("[Crafting] %s" % msg)


func _on_recipe_selected(index: int) -> void:
	if index >= _available_recipes.size():
		return
	var recipe = _available_recipes[index]
	if _materials_label:
		var text = "材料:\n"
		var materials: Dictionary = recipe.get("materials", {})
		for mat_id in materials:
			var qty = materials[mat_id]
			text += "  %s x%d\n" % [ItemDatabase.get_item_name(mat_id), qty]
		_materials_label.text = text
