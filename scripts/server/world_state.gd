extends Node
class_name WorldStateManager

## 世界状态管理器 — 维护权威世界状态
## 负责序列化/反序列化世界状态，生成全量/增量快照用于同步

var world_state: SharedDataModels.WorldState = SharedDataModels.WorldState.new()
var last_snapshot_tick: int = 0

var placed_blocks: Dictionary = {}  # {"x,y": Dictionary}
var resource_nodes: Dictionary = {}  # {"node_id": Dictionary}


func _ready() -> void:
    world_state = SharedDataModels.WorldState.new()


## 更新玩家位置（权威写入）
func update_player_position(player_id: int, new_position: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
    for i in range(world_state.players.size()):
        if world_state.players[i].get("player_id", -1) == player_id:
            world_state.players[i]["position"] = {"x": new_position.x, "y": new_position.y}
            world_state.players[i]["velocity"] = {"x": velocity.x, "y": velocity.y}
            return
    # 玩家不在列表中（尚未加入），静默忽略
    push_warning("[WorldState] 尝试更新未知玩家位置: %d" % player_id)


## 更新或添加玩家状态
func update_player_state(player_data: Dictionary) -> void:
    var pid = player_data.get("player_id", -1)
    if pid < 0:
        return
    for i in range(world_state.players.size()):
        if world_state.players[i].get("player_id", -1) == pid:
            world_state.players[i] = player_data
            return
    world_state.players.append(player_data)


## 移除玩家
func remove_player(player_id: int) -> void:
    for i in range(world_state.players.size() - 1, -1, -1):
        if world_state.players[i].get("player_id", -1) == player_id:
            world_state.players.remove_at(i)
            return


## 获取指定玩家数据
func get_player(player_id: int) -> Dictionary:
    for p in world_state.players:
        if p.get("player_id", -1) == player_id:
            return p
    return {}


## 获取所有玩家位置
func get_all_player_positions() -> Dictionary:
    # 返回 {player_id: Vector2} 映射
    var result: Dictionary = {}
    for p in world_state.players:
        var pid = p.get("player_id", -1)
        var pos = p.get("position", {"x": 0.0, "y": 0.0})
        result[pid] = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
    return result


func place_block(grid_key: String, block_data: Dictionary) -> void:
    placed_blocks[grid_key] = block_data

func remove_block(grid_key: String) -> void:
    placed_blocks.erase(grid_key)

func get_blocks_in_range(min_pos: Vector2i, max_pos: Vector2i) -> Array:
    var result: Array = []
    for key in placed_blocks:
        var block = placed_blocks[key]
        var gp = block.get("grid_pos", {"x": 0, "y": 0})
        var bx = gp.get("x", 0)
        var by = gp.get("y", 0)
        if bx >= min_pos.x and bx <= max_pos.x and by >= min_pos.y and by <= max_pos.y:
            result.append(block)
    return result

func add_resource_node(node_data: Dictionary) -> void:
    var node_id = node_data.get("node_id", "")
    if not node_id.is_empty():
        resource_nodes[node_id] = node_data

func deplete_resource_node(node_id: String) -> void:
    if resource_nodes.has(node_id):
        resource_nodes[node_id]["is_depleted"] = true
        resource_nodes[node_id]["depleted_at"] = Time.get_unix_time_from_system()


## 返回完整世界状态快照
func get_full_snapshot() -> Dictionary:
    last_snapshot_tick = world_state.tick
    var snapshot = world_state.to_dict()
    snapshot["placed_blocks"] = placed_blocks
    snapshot["resource_nodes"] = resource_nodes
    return snapshot


## 返回增量状态快照（自 since_tick 以来的变化）
## 初期先返回全量快照，后续可改为真实增量
func get_delta_snapshot(since_tick: int) -> Dictionary:
    return get_full_snapshot()
