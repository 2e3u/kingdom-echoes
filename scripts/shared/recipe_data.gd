extends Node
class_name RecipeDatabase

## 制造配方数据库 — 所有制造配方的静态定义

static var recipes: Array[Dictionary] = []

static func _static_init() -> void:
    # 基础材料加工
    _add("craft_copper_ingot", "copper_ingot", 1, {"copper_ore": 3}, SharedEnums.CraftStation.FURNACE)
    _add("craft_iron_ingot", "iron_ingot", 1, {"iron_ore": 3}, SharedEnums.CraftStation.FURNACE)
    _add("craft_silver_ingot", "silver_ingot", 1, {"silver_ore": 3}, SharedEnums.CraftStation.FURNACE)
    _add("craft_mithril_ingot", "mithril_ingot", 1, {"mithril_ore": 3}, SharedEnums.CraftStation.FURNACE)

    # 建造方块
    _add("craft_wood_floor", "wood_floor", 4, {"wood": 1}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_stone_floor", "stone_floor", 4, {"stone": 2}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_wood_wall", "wood_wall", 4, {"wood": 2}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_stone_wall", "stone_wall", 4, {"stone": 4}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_wooden_chest", "wooden_chest", 1, {"wood": 8}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_torch", "torch", 4, {"wood": 1, "fiber": 1}, SharedEnums.CraftStation.HAND)

    # 工作站
    _add("craft_workbench", "workbench", 1, {"wood": 10, "stone": 5}, SharedEnums.CraftStation.HAND)
    _add("craft_furnace", "furnace", 1, {"stone": 20, "clay": 10}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_anvil", "anvil", 1, {"iron_ingot": 5, "stone": 10}, SharedEnums.CraftStation.WORKBENCH)

    # 工具
    _add("craft_wooden_pickaxe", "wooden_pickaxe", 1, {"wood": 4, "fiber": 2}, SharedEnums.CraftStation.HAND)
    _add("craft_wooden_axe", "wooden_axe", 1, {"wood": 4, "fiber": 2}, SharedEnums.CraftStation.HAND)
    _add("craft_stone_pickaxe", "stone_pickaxe", 1, {"wood": 4, "stone": 3, "fiber": 2}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_stone_axe", "stone_axe", 1, {"wood": 4, "stone": 3, "fiber": 2}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_copper_pickaxe", "copper_pickaxe", 1, {"wood": 4, "copper_ingot": 3}, SharedEnums.CraftStation.ANVIL)
    _add("craft_copper_axe", "copper_axe", 1, {"wood": 4, "copper_ingot": 3}, SharedEnums.CraftStation.ANVIL)
    _add("craft_iron_pickaxe", "iron_pickaxe", 1, {"wood": 4, "iron_ingot": 3}, SharedEnums.CraftStation.ANVIL)
    _add("craft_iron_axe", "iron_axe", 1, {"wood": 4, "iron_ingot": 3}, SharedEnums.CraftStation.ANVIL)

    # 武器
    _add("craft_wooden_sword", "wooden_sword", 1, {"wood": 6}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_stone_sword", "stone_sword", 1, {"wood": 4, "stone": 5}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_iron_sword", "iron_sword", 1, {"wood": 2, "iron_ingot": 4}, SharedEnums.CraftStation.ANVIL)
    _add("craft_iron_bow", "iron_bow", 1, {"wood": 4, "iron_ingot": 2, "fiber": 4}, SharedEnums.CraftStation.WORKBENCH)
    _add("craft_mithril_spear", "mithril_spear", 1, {"wood": 4, "mithril_ingot": 4}, SharedEnums.CraftStation.ANVIL)

    # 护甲
    _add("craft_leather_armor", "leather_armor", 1, {"fiber": 8}, SharedEnums.CraftStation.LOOM)
    _add("craft_iron_armor", "iron_armor", 1, {"iron_ingot": 6}, SharedEnums.CraftStation.ANVIL)
    _add("craft_leather_helm", "leather_helm", 1, {"fiber": 4}, SharedEnums.CraftStation.LOOM)
    _add("craft_iron_helm", "iron_helm", 1, {"iron_ingot": 3}, SharedEnums.CraftStation.ANVIL)

    # 消耗品
    _add("craft_bandage", "bandage", 3, {"fiber": 2}, SharedEnums.CraftStation.HAND)
    _add("craft_health_potion", "health_potion", 1, {"herb_red": 3, "clay": 1}, SharedEnums.CraftStation.ALCHEMY)

static func _add(recipe_id: String, output_id: String, qty: int, mats: Dictionary, station: int) -> void:
    recipes.append({
        "recipe_id": recipe_id,
        "output_item_id": output_id,
        "output_quantity": qty,
        "materials": mats,
        "station": station,
    })

static func get_recipes_for_station(station: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for r in recipes:
        if r.get("station", 0) == station:
            result.append(r)
    return result

static func get_recipe(recipe_id: String) -> Dictionary:
    for r in recipes:
        if r.get("recipe_id", "") == recipe_id:
            return r
    return {}
