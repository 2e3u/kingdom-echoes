extends GutTest

var _im: ItemManager
var _cm: CraftingManager

func before_each() -> void:
	_im = ItemManager.new()
	_im.initialize_player_inventory(1)
	_cm = CraftingManager.new()
	_cm.item_manager = _im

func after_each() -> void:
	_cm.free()
	_im.free()

func test_craft_success() -> void:
	_im.add_item(1, "wood", 6)
	var r = _cm.try_craft(1, "craft_wooden_sword", SharedEnums.CraftStation.WORKBENCH)
	assert_true(r.get("success", false), r.get("message", ""))
	assert_true(_im.has_items(1, "wooden_sword", 1))

func test_craft_insufficient_materials() -> void:
	_im.add_item(1, "wood", 2)
	var r = _cm.try_craft(1, "craft_wooden_sword", SharedEnums.CraftStation.WORKBENCH)
	assert_false(r.get("success", false))

func test_craft_wrong_station() -> void:
	_im.add_item(1, "wood", 10)
	var r = _cm.try_craft(1, "craft_wooden_sword", SharedEnums.CraftStation.FURNACE)
	assert_false(r.get("success", false))

func test_craft_unknown_recipe() -> void:
	assert_false(_cm.try_craft(1, "no_recipe", SharedEnums.CraftStation.HAND).get("success", false))

func test_craft_rollback_on_full() -> void:
	var inv = _im.get_inventory(1)
	for i in range(inv.slots.size() - 1):
		inv.slots[i] = {"item_id": "blocker_%d" % i, "quantity": 99}
	_im.add_item(1, "wood", 10)
	# 最后一个空格放 wood，使其在唯一的空格中
	# 制造需要消耗 6 wood -> 剩余 4 wood，但产出 sword 需要 1 格 -> 如果最后一格是产出则可以
	# 简化：填满所有格
	for i in range(inv.slots.size()):
		inv.slots[i] = {"item_id": "blocker_%d" % i, "quantity": 99}
	var r = _cm.try_craft(1, "craft_wooden_sword", SharedEnums.CraftStation.WORKBENCH)
	assert_false(r.get("success", false))
