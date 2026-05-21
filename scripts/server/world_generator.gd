extends Node
class_name WorldGenerator

## 世界程序生成器 — 生成地形、群落边界、资源节点

var seed_value: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const WORLD_WIDTH_TILES: int = 200
const WORLD_HEIGHT_TILES: int = 200


func _ready() -> void:
    if seed_value == 0:
        seed_value = randi()
    rng.seed = seed_value
    print("[WorldGenerator] 种子: %d" % seed_value)


func generate() -> Dictionary:
    var result = {
        "seed": seed_value,
        "width": WORLD_WIDTH_TILES,
        "height": WORLD_HEIGHT_TILES,
        "biomes": _generate_biomes(),
        "resource_nodes": _generate_resources(),
        "spawn_point": {"x": WORLD_WIDTH_TILES / 2.0 * SharedConstants.TILE_SIZE,
                        "y": WORLD_HEIGHT_TILES / 2.0 * SharedConstants.TILE_SIZE},
    }
    return result


func _generate_biomes() -> Array:
    var biomes: Array = []
    var biome_types = ["central_plains", "northern_forest", "western_swamp",
                       "eastern_coast", "southern_desert", "snow_mountain",
                       "highland", "elf_forest", "shadow_canyon"]
    for x in range(0, WORLD_WIDTH_TILES, 4):
        for y in range(0, WORLD_HEIGHT_TILES, 4):
            var noise_val = (sin(x * 0.1) * cos(y * 0.1) + 1.0) / 2.0
            var biome_idx = int(noise_val * biome_types.size()) % biome_types.size()
            biomes.append({
                "x": x, "y": y,
                "biome": biome_types[biome_idx],
            })
    return biomes


func _generate_resources() -> Array[Dictionary]:
    var nodes: Array[Dictionary] = []
    var node_id = 0
    # 树木
    for i in range(500):
        var pos = _random_position()
        nodes.append(_make_node("tree_%d" % node_id, SharedEnums.HarvestType.WOOD, pos, 0,
            [{"item_id": "wood", "quantity": 3, "chance": 1.0},
             {"item_id": "hardwood", "quantity": 1, "chance": 0.1}]))
        node_id += 1
    # 铜矿
    for i in range(200):
        var pos = _random_position()
        nodes.append(_make_node("copper_%d" % node_id, SharedEnums.HarvestType.ORE, pos, 1,
            [{"item_id": "copper_ore", "quantity": 2, "chance": 1.0},
             {"item_id": "stone", "quantity": 1, "chance": 0.5}]))
        node_id += 1
    # 铁矿
    for i in range(150):
        var pos = _random_position()
        nodes.append(_make_node("iron_%d" % node_id, SharedEnums.HarvestType.ORE, pos, 2,
            [{"item_id": "iron_ore", "quantity": 2, "chance": 1.0},
             {"item_id": "stone", "quantity": 2, "chance": 0.5}]))
        node_id += 1
    # 草药
    for i in range(300):
        var pos = _random_position()
        nodes.append(_make_node("herb_%d" % node_id, SharedEnums.HarvestType.HERB, pos, 0,
            [{"item_id": "herb_red", "quantity": 2, "chance": 1.0}]))
        node_id += 1
    # 纤维
    for i in range(250):
        var pos = _random_position()
        nodes.append(_make_node("fiber_%d" % node_id, SharedEnums.HarvestType.FIBER, pos, 0,
            [{"item_id": "fiber", "quantity": 3, "chance": 1.0}]))
        node_id += 1
    return nodes


func _make_node(id: String, type: int, pos: Vector2, tier: int, drops: Array) -> Dictionary:
    return {
        "node_id": id,
        "resource_type": type,
        "position": {"x": pos.x, "y": pos.y},
        "tool_tier_required": tier,
        "drops": drops,
        "respawn_time": 60.0,
        "is_depleted": false,
        "depleted_at": 0.0,
    }


func _random_position() -> Vector2:
    var x = rng.randf_range(0, WORLD_WIDTH_TILES * SharedConstants.TILE_SIZE)
    var y = rng.randf_range(0, WORLD_HEIGHT_TILES * SharedConstants.TILE_SIZE)
    return Vector2(x, y)


func get_seed() -> int:
    return seed_value
