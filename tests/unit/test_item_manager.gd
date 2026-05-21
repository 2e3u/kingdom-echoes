extends GutTest

var _im: ItemManager

func before_each() -> void:
	_im = ItemManager.new()
	_im.initialize_player_inventory(1)

func after_each() -> void:
	_im.free()

func test_init_creates_correct_slots() -> void:
	var inv = _im.get_inventory(1)
	assert_eq(inv.max_slots, SharedConstants.INVENTORY_INITIAL_SLOTS)
	assert_eq(inv.slots.size(), SharedConstants.INVENTORY_INITIAL_SLOTS)

func test_add_and_has_items() -> void:
	assert_true(_im.add_item(1, "wood", 10))
	assert_true(_im.has_items(1, "wood", 10))
	assert_false(_im.has_items(1, "wood", 99))

func test_add_stack_merge() -> void:
	_im.add_item(1, "wood", 50)
	_im.add_item(1, "wood", 40)
	assert_true(_im.has_items(1, "wood", 90))

func test_remove_items() -> void:
	_im.add_item(1, "wood", 10)
	assert_true(_im.remove_item(1, "wood", 3))
	assert_true(_im.has_items(1, "wood", 7))
	assert_false(_im.remove_item(1, "wood", 99))

func test_can_add_when_full() -> void:
	var inv = _im.get_inventory(1)
	for i in range(inv.slots.size()):
		inv.slots[i] = {"item_id": "full_%d" % i, "quantity": 99}
	assert_false(_im.can_add_item(1, "wood", 1))

func test_consume_durability_and_break() -> void:
	_im.add_item(1, "wooden_sword", 1, 50)
	var inv = _im.get_inventory(1)
	var idx = -1
	for i in range(inv.slots.size()):
		if inv.slots[i].get("item_id", "") == "wooden_sword":
			idx = i; break
	assert_ne(idx, -1)
	_im.consume_durability(1, idx, 50)
	assert_true(inv.slots[idx].get("broken", false))

func test_repair_item() -> void:
	_im.add_item(1, "wooden_sword", 1, 10)
	_im.add_item(1, "wood", 10)
	var inv = _im.get_inventory(1)
	var idx = -1
	for i in range(inv.slots.size()):
		if inv.slots[i].get("item_id", "") == "wooden_sword":
			idx = i; break
	_im.consume_durability(1, idx, 50)
	assert_true(_im.repair_item(1, idx))
	assert_false(inv.slots[idx].has("broken"))

func test_remove_player_inventory() -> void:
	_im.remove_player_inventory(1)
	assert_null(_im.get_inventory(1))
