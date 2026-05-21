extends Node
class_name CraftingManager

## 服务端制造管理器 — 配方验证、材料消耗、物品产出

var item_manager: ItemManager = null


func try_craft(player_id: int, recipe_id: String, station: int) -> Dictionary:
	if not item_manager:
		return {"success": false, "message": "系统未就绪"}
	var recipe = RecipeDatabase.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"success": false, "message": "未知配方"}
	if recipe.get("station", 0) != station:
		return {"success": false, "message": "错误的工作站"}
	var output_id = recipe.get("output_item_id", "")
	var output_qty = recipe.get("output_quantity", 1)
	if output_id.is_empty() or output_qty <= 0:
		return {"success": false, "message": "配方产出无效"}
	if ItemDatabase.get_item(output_id).is_empty():
		return {"success": false, "message": "配方产出无效"}
	var materials: Dictionary = recipe.get("materials", {})
	for mat_id in materials:
		var needed = materials[mat_id]
		if not item_manager.has_items(player_id, mat_id, needed):
			return {"success": false, "message": "材料不足: %s x%d" % [ItemDatabase.get_item_name(mat_id), needed]}
	# 先消耗材料（释放背包空间），再检查产出空间
	for mat_id in materials:
		item_manager.remove_item(player_id, mat_id, materials[mat_id])
	if not item_manager.can_add_item(player_id, output_id, output_qty):
		# 回滚：返还已消耗的材料
		for mat_id in materials:
			item_manager.add_item(player_id, mat_id, materials[mat_id])
		return {"success": false, "message": "背包已满"}
	item_manager.add_item(player_id, output_id, output_qty)
	return {"success": true, "message": "制造完成", "output": output_id, "quantity": output_qty}


func get_available_recipes_for_player(player_id: int, station: int) -> Array[Dictionary]:
	var all_recipes = RecipeDatabase.get_recipes_for_station(station)
	return all_recipes
