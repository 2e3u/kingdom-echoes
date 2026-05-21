extends GutTest

func test_all_items_have_name_and_category() -> void:
	for item_id in ItemDatabase.items:
		var item = ItemDatabase.items[item_id]
		assert_ne(item.get("name", ""), "", "物品 %s 缺少名称" % item_id)
		assert_ne(item.get("category", -1), -1, "物品 %s 缺少分类" % item_id)
		assert_gt(item.get("stack_max", 0), 0, "物品 %s stack_max 需 >0" % item_id)

func test_weapons_have_combat_stats() -> void:
	for item_id in ItemDatabase.items:
		var item = ItemDatabase.items[item_id]
		if item.get("category", -1) == SharedEnums.ItemCategory.WEAPON:
			var stats = item.get("stats", {})
			assert_gt(stats.get("damage", 0), 0, "武器 %s 缺少 damage" % item_id)
			assert_true(stats.has("attack_speed"), "武器 %s 缺少 attack_speed" % item_id)

func test_armors_have_damage_reduction() -> void:
	for item_id in ItemDatabase.items:
		var item = ItemDatabase.items[item_id]
		if item.get("category", -1) == SharedEnums.ItemCategory.ARMOR:
			assert_gt(item.get("damage_reduction", 0.0), 0.0, "护甲 %s 缺少伤害减免" % item_id)

func test_tools_have_harvest_type() -> void:
	for item_id in ItemDatabase.items:
		var item = ItemDatabase.items[item_id]
		if item.get("category", -1) == SharedEnums.ItemCategory.TOOL:
			assert_ne(item.get("harvest_type", -1), SharedEnums.HarvestType.NONE, "工具 %s 缺少采集类型" % item_id)

func test_get_item_known_and_unknown() -> void:
	assert_eq(ItemDatabase.get_item_name("wood"), "木材")
	assert_eq(ItemDatabase.get_item_name("does_not_exist"), "does_not_exist")
	assert_false(ItemDatabase.get_item("nonexistent").is_empty() == false)
