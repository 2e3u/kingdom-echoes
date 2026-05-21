extends Node
class_name ItemManager

## 服务端物品管理器 — 管理所有在线玩家的背包

var _inventories: Dictionary = {}  # {player_id: SharedDataModels.Inventory}

func _ready() -> void:
    print("[ItemManager] 物品管理器已初始化")

func initialize_player_inventory(player_id: int) -> void:
    var inv = SharedDataModels.Inventory.new()
    inv.max_slots = SharedConstants.INVENTORY_INITIAL_SLOTS
    for i in range(inv.max_slots):
        inv.slots.append({})
    _inventories[player_id] = inv
    print("[ItemManager] 玩家 %d 背包已初始化 (%d 格)" % [player_id, inv.max_slots])

func remove_player_inventory(player_id: int) -> void:
    _inventories.erase(player_id)

func get_inventory(player_id: int) -> SharedDataModels.Inventory:
    if not _inventories.has(player_id):
        return null
    return _inventories[player_id]

func get_inventory_dict(player_id: int) -> Dictionary:
    var inv = get_inventory(player_id)
    if inv:
        return inv.to_dict()
    return {}

func can_add_item(player_id: int, item_id: String, quantity: int) -> bool:
    var inv = get_inventory(player_id)
    if not inv:
        return false
    var item_def = ItemDatabase.get_item(item_id)
    if item_def.is_empty():
        return false
    var stack_max = item_def.get("stack_max", 99)
    var needed = quantity
    for slot in inv.slots:
        if slot.is_empty():
            continue
        if slot.get("item_id", "") == item_id:
            var space = stack_max - slot.get("quantity", 0)
            if space > 0:
                needed -= min(space, needed)
        if needed <= 0:
            return true
    for slot in inv.slots:
        if slot.is_empty():
            needed -= min(stack_max, needed)
        if needed <= 0:
            return true
    return needed <= 0

func add_item(player_id: int, item_id: String, quantity: int, durability: int = -1) -> bool:
    if not can_add_item(player_id, item_id, quantity):
        return false
    var inv = get_inventory(player_id)
    var item_def = ItemDatabase.get_item(item_id)
    var stack_max = item_def.get("stack_max", 99)
    if durability < 0:
        durability = item_def.get("durability_max", 0)
    var remaining = quantity
    for slot in inv.slots:
        if slot.is_empty():
            continue
        if slot.get("item_id", "") == item_id and slot.get("quantity", 0) < stack_max:
            var space = stack_max - slot.get("quantity", 0)
            var add = min(space, remaining)
            slot["quantity"] = slot.get("quantity", 0) + add
            remaining -= add
        if remaining <= 0:
            return true
    for i in range(inv.slots.size()):
        if inv.slots[i].is_empty():
            var add = min(stack_max, remaining)
            inv.slots[i] = {
                "item_id": item_id,
                "quantity": add,
                "durability": durability,
                "affixes": [],
                "rarity": item_def.get("rarity", SharedEnums.Rarity.COMMON),
            }
            remaining -= add
        if remaining <= 0:
            return true
    return true

func remove_item(player_id: int, item_id: String, quantity: int) -> bool:
    var inv = get_inventory(player_id)
    if not inv:
        return false
    var total = 0
    for slot in inv.slots:
        if not slot.is_empty() and slot.get("item_id", "") == item_id:
            total += slot.get("quantity", 0)
    if total < quantity:
        return false
    var remaining = quantity
    for i in range(inv.slots.size() - 1, -1, -1):
        if inv.slots[i].is_empty():
            continue
        if inv.slots[i].get("item_id", "") == item_id:
            var q = inv.slots[i].get("quantity", 0)
            if q <= remaining:
                remaining -= q
                inv.slots[i] = {}
            else:
                inv.slots[i]["quantity"] = q - remaining
                return true
            if remaining <= 0:
                return true
    return true

func has_items(player_id: int, item_id: String, quantity: int) -> bool:
    var inv = get_inventory(player_id)
    if not inv:
        return false
    var total = 0
    for slot in inv.slots:
        if not slot.is_empty() and slot.get("item_id", "") == item_id:
            total += slot.get("quantity", 0)
    return total >= quantity

func consume_durability(player_id: int, slot_index: int, amount: int = 1) -> bool:
    var inv = get_inventory(player_id)
    if not inv or slot_index >= inv.slots.size():
        return false
    var slot = inv.slots[slot_index]
    if slot.is_empty():
        return false
    var dur = slot.get("durability", 0)
    if dur <= 0:
        return false
    slot["durability"] = max(0, dur - amount)
    if slot["durability"] <= 0:
        slot["broken"] = true
    return true

func repair_item(player_id: int, slot_index: int) -> bool:
    var inv = get_inventory(player_id)
    if not inv or slot_index >= inv.slots.size():
        return false
    var slot = inv.slots[slot_index]
    if slot.is_empty():
        return false
    var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
    var max_dur = item_def.get("durability_max", 0)
    if max_dur <= 0:
        return false
    var repair_cost_id = _get_repair_material(slot.get("item_id", ""))
    if repair_cost_id.is_empty():
        return false
    if not has_items(player_id, repair_cost_id, 1):
        return false
    remove_item(player_id, repair_cost_id, 1)
    slot["durability"] = max_dur
    slot.erase("broken")
    return true

func _get_repair_material(item_id: String) -> String:
    var item_def = ItemDatabase.get_item(item_id)
    var category = item_def.get("category", -1)
    var tier = item_def.get("tool_tier", 0)
    if category == SharedEnums.ItemCategory.TOOL or category == SharedEnums.ItemCategory.WEAPON:
        match tier:
            SharedEnums.ToolTier.WOOD: return "wood"
            SharedEnums.ToolTier.STONE: return "stone"
            SharedEnums.ToolTier.COPPER: return "copper_ingot"
            SharedEnums.ToolTier.IRON: return "iron_ingot"
            SharedEnums.ToolTier.MITHRIL: return "mithril_ingot"
    return ""
