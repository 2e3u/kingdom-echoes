extends Node
class_name ItemDatabase

## 物品静态数据库 — 所有物品的固定属性定义

static var items: Dictionary = {}

static func _static_init() -> void:
    _register_materials()
    _register_tools()
    _register_weapons()
    _register_armors()
    _register_consumables()
    _register_blocks()
    _register_special()

static func _register_materials() -> void:
    # 木材系
    items["wood"] = {
        "name": "木材", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.NONE, "harvest_type": SharedEnums.HarvestType.WOOD,
    }
    items["hardwood"] = {
        "name": "硬木", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.UNCOMMON,
        "tool_tier": SharedEnums.ToolTier.STONE, "harvest_type": SharedEnums.HarvestType.WOOD,
    }
    # 矿石系
    items["copper_ore"] = {
        "name": "铜矿石", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.WOOD, "harvest_type": SharedEnums.HarvestType.ORE,
    }
    items["iron_ore"] = {
        "name": "铁矿石", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.STONE, "harvest_type": SharedEnums.HarvestType.ORE,
    }
    items["silver_ore"] = {
        "name": "银矿石", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.UNCOMMON,
        "tool_tier": SharedEnums.ToolTier.COPPER, "harvest_type": SharedEnums.HarvestType.ORE,
    }
    items["mithril_ore"] = {
        "name": "秘银矿石", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.RARE,
        "tool_tier": SharedEnums.ToolTier.IRON, "harvest_type": SharedEnums.HarvestType.ORE,
    }
    # 金属锭
    items["copper_ingot"] = {
        "name": "铜锭", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
    }
    items["iron_ingot"] = {
        "name": "铁锭", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
    }
    items["silver_ingot"] = {
        "name": "银锭", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.UNCOMMON,
    }
    items["mithril_ingot"] = {
        "name": "秘银锭", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.RARE,
    }
    # 其他材料
    items["stone"] = {
        "name": "石头", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.NONE, "harvest_type": SharedEnums.HarvestType.NONE,
    }
    items["fiber"] = {
        "name": "纤维", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.NONE, "harvest_type": SharedEnums.HarvestType.FIBER,
    }
    items["herb_red"] = {
        "name": "红叶草", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.NONE, "harvest_type": SharedEnums.HarvestType.HERB,
    }
    items["clay"] = {
        "name": "粘土", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": SharedEnums.ToolTier.WOOD, "harvest_type": SharedEnums.HarvestType.NONE,
    }

static func _register_tools() -> void:
    # 镐
    items["wooden_pickaxe"] = _make_tool("木镐", "pickaxe", SharedEnums.ToolTier.WOOD, 50, SharedEnums.HarvestType.ORE)
    items["stone_pickaxe"] = _make_tool("石镐", "pickaxe", SharedEnums.ToolTier.STONE, 100, SharedEnums.HarvestType.ORE)
    items["copper_pickaxe"] = _make_tool("铜镐", "pickaxe", SharedEnums.ToolTier.COPPER, 150, SharedEnums.HarvestType.ORE)
    items["iron_pickaxe"] = _make_tool("铁镐", "pickaxe", SharedEnums.ToolTier.IRON, 250, SharedEnums.HarvestType.ORE)
    # 斧
    items["wooden_axe"] = _make_tool("木斧", "axe", SharedEnums.ToolTier.WOOD, 50, SharedEnums.HarvestType.WOOD)
    items["stone_axe"] = _make_tool("石斧", "axe", SharedEnums.ToolTier.STONE, 100, SharedEnums.HarvestType.WOOD)
    items["copper_axe"] = _make_tool("铜斧", "axe", SharedEnums.ToolTier.COPPER, 150, SharedEnums.HarvestType.WOOD)
    items["iron_axe"] = _make_tool("铁斧", "axe", SharedEnums.ToolTier.IRON, 250, SharedEnums.HarvestType.WOOD)

static func _make_tool(tool_name: String, tool_type: String, tier: int, durability: int, harvest: int) -> Dictionary:
    return {
        "name": tool_name, "category": SharedEnums.ItemCategory.TOOL,
        "stack_max": 1, "rarity": SharedEnums.Rarity.COMMON,
        "tool_tier": tier, "harvest_type": harvest,
        "durability_max": durability,
        "tool_type": tool_type,
    }

static func _register_weapons() -> void:
    items["wooden_sword"] = _make_weapon("木剑", "sword", 5, 1.0, 0.05, 1.5, 50)
    items["stone_sword"] = _make_weapon("石剑", "sword", 8, 1.0, 0.05, 1.5, 80)
    items["iron_sword"] = _make_weapon("铁剑", "sword", 12, 1.0, 0.05, 1.5, 150)
    items["iron_bow"] = _make_weapon("铁弓", "bow", 10, 0.8, 0.10, 2.0, 120)
    items["mithril_spear"] = _make_weapon("秘银矛", "spear", 18, 1.2, 0.08, 1.8, 300)

static func _make_weapon(weapon_name: String, wpn_type: String, dmg: int, atk_spd: float, crit_c: float, crit_m: float, dur: int) -> Dictionary:
    return {
        "name": weapon_name, "category": SharedEnums.ItemCategory.WEAPON,
        "stack_max": 1, "rarity": SharedEnums.Rarity.COMMON,
        "durability_max": dur,
        "stats": {"damage": dmg, "attack_speed": atk_spd, "crit_chance": crit_c, "crit_multiplier": crit_m},
        "weapon_type": wpn_type,
    }

static func _register_armors() -> void:
    items["leather_armor"] = _make_armor("皮革甲", "chest", 0.10, 60)
    items["iron_armor"] = _make_armor("铁甲", "chest", 0.20, 120)
    items["leather_helm"] = _make_armor("皮革盔", "head", 0.05, 40)
    items["iron_helm"] = _make_armor("铁盔", "head", 0.10, 80)

static func _make_armor(armor_name: String, slot: String, reduction: float, dur: int) -> Dictionary:
    return {
        "name": armor_name, "category": SharedEnums.ItemCategory.ARMOR,
        "stack_max": 1, "rarity": SharedEnums.Rarity.COMMON,
        "durability_max": dur,
        "armor_slot": slot, "damage_reduction": reduction,
    }

static func _register_consumables() -> void:
    items["health_potion"] = {
        "name": "生命药剂", "category": SharedEnums.ItemCategory.CONSUMABLE,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "use_effect": {"type": "heal", "value": 30},
    }
    items["bandage"] = {
        "name": "绷带", "category": SharedEnums.ItemCategory.CONSUMABLE,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "use_effect": {"type": "heal", "value": 10},
    }

static func _register_blocks() -> void:
    items["wood_floor"] = {
        "name": "木地板", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.FLOOR,
    }
    items["stone_floor"] = {
        "name": "石砖地板", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.FLOOR,
    }
    items["wood_wall"] = {
        "name": "木墙", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.WALL,
    }
    items["stone_wall"] = {
        "name": "石墙", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 999, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.WALL,
    }
    items["wooden_chest"] = {
        "name": "木箱", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.FURNITURE,
    }
    items["torch"] = {
        "name": "火把", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.DECORATION,
    }
    items["workbench"] = {
        "name": "工作台", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.WORKSTATION,
        "station_type": SharedEnums.CraftStation.WORKBENCH,
    }
    items["furnace"] = {
        "name": "熔炉", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.WORKSTATION,
        "station_type": SharedEnums.CraftStation.FURNACE,
    }
    items["anvil"] = {
        "name": "铁砧", "category": SharedEnums.ItemCategory.MATERIAL,
        "stack_max": 99, "rarity": SharedEnums.Rarity.COMMON,
        "block_type": SharedEnums.BlockType.WORKSTATION,
        "station_type": SharedEnums.CraftStation.ANVIL,
    }

static func _register_special() -> void:
    items["backpack_expander"] = {
        "name": "背包扩展券", "category": SharedEnums.ItemCategory.SPECIAL,
        "stack_max": 1, "rarity": SharedEnums.Rarity.UNCOMMON,
        "use_effect": {"type": "expand_inventory", "value": 4},
    }
    items["teleport_stone"] = {
        "name": "传送石", "category": SharedEnums.ItemCategory.SPECIAL,
        "stack_max": 1, "rarity": SharedEnums.Rarity.RARE,
    }

static func get_item(item_id: String) -> Dictionary:
    return items.get(item_id, {})

static func get_item_name(item_id: String) -> String:
    return items.get(item_id, {}).get("name", item_id)
