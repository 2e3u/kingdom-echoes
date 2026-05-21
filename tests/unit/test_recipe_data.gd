extends GutTest

func test_all_recipes_have_valid_output() -> void:
	for recipe in RecipeDatabase.recipes:
		var output_id = recipe.get("output_item_id", "")
		assert_false(output_id.is_empty(), "配方缺少产出")
		assert_false(ItemDatabase.get_item(output_id).is_empty(), "产出物品不存在: %s" % output_id)

func test_recipe_materials_exist() -> void:
	for recipe in RecipeDatabase.recipes:
		for mat_id in recipe.get("materials", {}):
			assert_false(ItemDatabase.get_item(mat_id).is_empty(), "材料不存在: %s" % mat_id)

func test_get_recipe() -> void:
	assert_eq(RecipeDatabase.get_recipe("craft_wooden_sword").get("output_item_id", ""), "wooden_sword")
	assert_true(RecipeDatabase.get_recipe("no_such").is_empty())

func test_get_recipes_for_station() -> void:
	var result = RecipeDatabase.get_recipes_for_station(SharedEnums.CraftStation.FURNACE)
	assert_gt(result.size(), 0)
	for r in result:
		assert_eq(r.get("station", -1), SharedEnums.CraftStation.FURNACE)
