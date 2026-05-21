extends Node
class_name ItemDatabase

## 物品静态数据库 — 所有物品的固定属性定义

static var items: Dictionary = {}

static func _static_init() -> void:
    _register_materials()
    _register_tools()
    _register_weapons()
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
    items["wooden_sword"] = {
        "name": "木剑", "category": SharedEnums.ItemCategory.WEAPON,
        "stack_max": 1, "rarity": SharedEnums.Rarity.COMMON,
        "durability_max": 50,
        "stats": {"damage": 5, "attack_speed": 1.0, "crit_chance": 0.05, "crit_multiplier": 1.5},
        "weapon_type": "sword",
    }
    items["stone_sword"] = {
        "name": "石剑", "category": SharedEnums.ItemCategory.WEAPON,
        "stack_max": 1, "rarity": SharedEnums.Rarity.COMMON,
        "durability_max": 80,
        "stats": {"damage": 8, "attack_speed": 1.0, "crit_chance": 0.05, "crit_multiplier": 1.5},
        "weapon_type": "sword",
    }
    items["iron_sword"] = {
        "name": "铁剑", "category": SharedEnums.ItemCategory.WEAPON,
        "stack_max": 1, "rarity": SharedEnums.Rarity.UNCOMMON,
        "durability_max": 150,
        "stats": {"damage": 12, "attack_speed": 1.0, "crit_chance": 0.05, "crit_multiplier": 1.5},
        "weapon_type": "sword",
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
