extends Node
class_name GameLoop

## 权威游戏循环 — 服务端核心 Tick 驱动
## 以固定 tick_rate 运行，处理物理、状态同步、游戏逻辑
##
## 通过 NetworkRPC autoload 接收客户端输入并广播世界状态

var current_tick: int = 0
var game_state: int = SharedEnums.GameState.LOBBY
var tick_timer: float = 0.0
var is_running: bool = false

# 子系统引用
var world_state_manager: WorldStateManager = null
var player_manager: PlayerManager = null
var item_manager: ItemManager = null
var crafting_manager: CraftingManager = null
var build_manager: BuildManager = null

# 待处理输入缓冲: {player_id: input_dict}
var _pending_inputs: Dictionary = {}


func _ready() -> void:
    # 连接到 NetworkRPC 信号接收玩家输入
    if not NetworkRPC.player_input_received.is_connected(_on_player_input_received):
        NetworkRPC.player_input_received.connect(_on_player_input_received)

    item_manager = ItemManager.new()
    item_manager.name = "ItemManager"
    add_child(item_manager)
    if not NetworkRPC.inventory_action_received.is_connected(_on_inventory_action):
        NetworkRPC.inventory_action_received.connect(_on_inventory_action)
    if not NetworkRPC.harvest_action_received.is_connected(_on_harvest_action):
        NetworkRPC.harvest_action_received.connect(_on_harvest_action)

    crafting_manager = CraftingManager.new()
    crafting_manager.name = "CraftingManager"
    crafting_manager.item_manager = item_manager
    add_child(crafting_manager)
    if not NetworkRPC.craft_action_received.is_connected(_on_craft_action):
        NetworkRPC.craft_action_received.connect(_on_craft_action)

	build_manager = BuildManager.new()
	build_manager.name = "BuildManager"
	build_manager.item_manager = item_manager
	build_manager.world_state_manager = world_state_manager
	add_child(build_manager)
	if not NetworkRPC.build_action_received.is_connected(_on_build_action):
		NetworkRPC.build_action_received.connect(_on_build_action)


func start() -> void:
    is_running = true
    current_tick = 0
    game_state = SharedEnums.GameState.LOBBY
    print("[GameLoop] 游戏循环已启动")


func stop() -> void:
    is_running = false
    _pending_inputs.clear()
    print("[GameLoop] 游戏循环已停止")


func _process(delta: float) -> void:
    if not is_running:
        return
    tick_timer += delta
    # 以 tick_rate 固定频率执行 tick()
    var max_ticks = 5
    while tick_timer >= SharedConstants.TICK_DELTA:
        tick_timer -= SharedConstants.TICK_DELTA
        tick()
        max_ticks -= 1
        if max_ticks <= 0:
            push_warning("[GameLoop] 达到每帧最大 tick 限制 (%d)，可能存在性能问题" % 5)
            tick_timer = 0.0
            break


func tick() -> void:
    # 单帧逻辑
    # 1. 处理所有待处理玩家输入
    _process_pending_inputs()

    # 2. 更新世界状态 tick 计数
    if world_state_manager:
        world_state_manager.world_state.tick = current_tick
        world_state_manager.world_state.server_time = Time.get_ticks_msec() / 1000.0

    # 3. 广播世界状态
    _broadcast_world_state()

    # 4. 递增 tick
    current_tick += 1


func _process_pending_inputs() -> void:
    if _pending_inputs.is_empty():
        return
    # 消费所有待处理输入
    var inputs_to_process = _pending_inputs.duplicate()
    _pending_inputs.clear()

    for player_id in inputs_to_process:
        var input_data = inputs_to_process[player_id]
        _apply_player_input(player_id, input_data)


func _apply_player_input(player_id: int, input_data: Dictionary) -> void:
    # 应用玩家输入，更新权威位置
    if not world_state_manager:
        return

    var md = input_data.get("move_direction", {"x": 0.0, "y": 0.0})
    var direction = Vector2(md.get("x", 0.0), md.get("y", 0.0))

    # 输入验证：方向向量规范化并限制长度
    if direction.length() > 1.0:
        direction = direction.normalized()

    # 获取当前玩家位置
    var player_dict = world_state_manager.get_player(player_id)
    var current_pos = Vector2.ZERO
    if not player_dict.is_empty():
        var pos = player_dict.get("position", {"x": 0.0, "y": 0.0})
        current_pos = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))

    # 计算新位置
    var new_position = current_pos + direction * SharedConstants.PLAYER_SPEED * SharedConstants.TICK_DELTA

    # 边界限制（防止移出世界）
    new_position.x = clamp(new_position.x, 0.0, SharedConstants.WORLD_WIDTH)
    new_position.y = clamp(new_position.y, 0.0, SharedConstants.WORLD_HEIGHT)

    # 更新世界状态
    world_state_manager.update_player_position(player_id, new_position, direction)


func _broadcast_world_state() -> void:
    # 广播当前世界状态给所有客户端
    if not world_state_manager:
        return

    var snapshot = world_state_manager.get_full_snapshot()
    # 通过 NetworkRPC autoload 广播（NodePath 在所有客户端一致）
    NetworkRPC.rpc("_on_world_state", snapshot)


func set_game_state(new_state: int) -> void:
    game_state = new_state
    if world_state_manager:
        world_state_manager.world_state.game_state = new_state
    print("[GameLoop] 游戏状态切换: %d" % new_state)


# ---------- 信号处理 ----------

func _on_player_input_received(input_data: Dictionary, peer_id: int) -> void:
    # 接收来自 NetworkRPC 的玩家输入信号
    # 使用 RPC 层验证的 sender_id，而非 input_data 中可能被伪造的 player_id
    if peer_id <= 0:
        return
    # 存储最新输入（覆盖旧输入，每 tick 只处理最新一次）
    _pending_inputs[peer_id] = input_data


func _on_player_joined(player_id: int) -> void:
    # 处理玩家加入
    if not world_state_manager or not player_manager:
        return
    var pd = player_manager.get_player(player_id)
    if pd:
        # 初始化该玩家在世界状态中的位置（出生点已在 PlayerManager 中设置）
        var new_player_dict = pd.to_dict()
        world_state_manager.update_player_state(new_player_dict)
        # 广播新玩家加入给所有客户端（包含位置、名称等完整数据）
        NetworkRPC.rpc("_on_player_joined", player_id, new_player_dict)
        print("[GameLoop] 玩家 %d 已加入世界，位置: (%.0f, %.0f)" % [player_id, pd.position.x, pd.position.y])

    if item_manager:
        item_manager.initialize_player_inventory(player_id)


func _on_player_left(player_id: int) -> void:
    # 处理玩家离开
    if world_state_manager:
        world_state_manager.remove_player(player_id)
    _pending_inputs.erase(player_id)
    # 广播玩家离开给所有客户端
    NetworkRPC.rpc("_on_player_left", player_id)
    print("[GameLoop] 玩家 %d 已离开世界" % player_id)

    if item_manager:
        item_manager.remove_player_inventory(player_id)


func _on_inventory_action(action_data: Dictionary, peer_id: int) -> void:
    var action = action_data.get("action", "")
    match action:
        "use_item":
            var slot = action_data.get("slot", 0)
            var inv = item_manager.get_inventory(peer_id)
            if inv and slot < inv.slots.size():
                var item = inv.slots[slot]
                if not item.is_empty():
                    var item_def = ItemDatabase.get_item(item.get("item_id", ""))
                    var use_effect = item_def.get("use_effect", {})
                    if use_effect.get("type", "") == "expand_inventory":
                        inv.max_slots = min(SharedConstants.INVENTORY_MAX_SLOTS, inv.max_slots + use_effect.get("value", 4))
                        for i in range(use_effect.get("value", 4)):
                            inv.slots.append({})
                        inv.slots[slot] = {}
                    elif use_effect.get("type", "") == "heal":
                        remove_from_slot(peer_id, slot, 1)
        "drop_item":
            var slot = action_data.get("slot", 0)
            remove_from_slot(peer_id, slot, action_data.get("quantity", 1))
        "repair":
            var slot = action_data.get("slot", 0)
            item_manager.repair_item(peer_id, slot)
    _sync_inventory(peer_id)


func remove_from_slot(player_id: int, slot: int, quantity: int) -> void:
    var inv = item_manager.get_inventory(player_id)
    if not inv or slot >= inv.slots.size():
        return
    var item = inv.slots[slot]
    if item.is_empty():
        return
    var q = item.get("quantity", 0)
    if q <= quantity:
        inv.slots[slot] = {}
    else:
        inv.slots[slot]["quantity"] = q - quantity


func _sync_inventory(player_id: int) -> void:
    var inv_data = item_manager.get_inventory_dict(player_id)
    NetworkRPC.rpc_id(player_id, "_on_inventory_state", inv_data)


# ---------- 采集系统 ----------

func _on_harvest_action(action_data: Dictionary, peer_id: int) -> void:
    var player_pos_data = action_data.get("player_position", {"x": 0.0, "y": 0.0})
    var player_pos = Vector2(player_pos_data.get("x", 0.0), player_pos_data.get("y", 0.0))
    var nearest: Dictionary = {}
    var nearest_dist: float = 100.0
    if world_state_manager:
        for node_id in world_state_manager.resource_nodes:
            var node = world_state_manager.resource_nodes[node_id]
            if node.get("is_depleted", false):
                continue
            var node_pos_data = node.get("position", {"x": 0.0, "y": 0.0})
            var node_pos = Vector2(node_pos_data.get("x", 0.0), node_pos_data.get("y", 0.0))
            var dist = player_pos.distance_to(node_pos)
            if dist < nearest_dist:
                nearest_dist = dist
                nearest = node
    if nearest.is_empty():
        return
    var required_tier = nearest.get("tool_tier_required", 0)
    if not _player_has_tool_of_tier(peer_id, required_tier, nearest.get("resource_type", 0)):
        return
    _consume_tool_durability(peer_id, nearest.get("resource_type", 0))
    for drop in nearest.get("drops", []):
        if randf() <= drop.get("chance", 1.0):
            item_manager.add_item(peer_id, drop.get("item_id", ""), drop.get("quantity", 1))
    world_state_manager.deplete_resource_node(nearest.get("node_id", ""))
    _sync_inventory(peer_id)

func _player_has_tool_of_tier(player_id: int, tier: int, harvest_type: int) -> bool:
    if tier <= SharedEnums.ToolTier.NONE:
        return true
    var inv = item_manager.get_inventory(player_id)
    if not inv:
        return false
    for slot in inv.slots:
        if slot.is_empty():
            continue
        var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
        if item_def.get("harvest_type", SharedEnums.HarvestType.NONE) != harvest_type:
            continue
        if item_def.get("tool_tier", 0) >= tier and not slot.get("broken", false):
            return true
    return false

func _consume_tool_durability(player_id: int, harvest_type: int) -> void:
    var inv = item_manager.get_inventory(player_id)
    if not inv:
        return
    for i in range(inv.slots.size()):
        var slot = inv.slots[i]
        if slot.is_empty():
            continue
        var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
        if item_def.get("harvest_type", SharedEnums.HarvestType.NONE) == harvest_type and item_def.get("tool_tier", 0) > 0:
            item_manager.consume_durability(player_id, i, 1)
            return


# ---------- 制造系统 ----------

func _on_craft_action(action_data: Dictionary, peer_id: int) -> void:
    var recipe_id = action_data.get("recipe_id", "")
    var station = action_data.get("station", SharedEnums.CraftStation.HAND)
    var result = crafting_manager.try_craft(peer_id, recipe_id, station)
    NetworkRPC.rpc_id(peer_id, "_on_craft_result", result)
    _sync_inventory(peer_id)

# ---------- 建造系统 ----------

func _on_build_action(action_data: Dictionary, peer_id: int) -> void:
	if not build_manager:
		return
	var action = action_data.get("action", "")
	var grid_pos_data = action_data.get("grid_pos", {"x": 0, "y": 0})
	var grid_pos = Vector2i(grid_pos_data.get("x", 0), grid_pos_data.get("y", 0))
	var player_dict = world_state_manager.get_player(peer_id) if world_state_manager else {}
	var pos_d = player_dict.get("position", {"x": 0.0, "y": 0.0})
	var player_pos = Vector2(pos_d.get("x", 0.0), pos_d.get("y", 0.0))
	match action:
		"place":
			var block_id = action_data.get("block_id", "")
			if block_id.is_empty():
				return
			if build_manager.place_block(peer_id, grid_pos, block_id, player_pos):
				NetworkRPC.rpc("_on_block_placed", {
					"block_id": block_id,
					"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
					"owner_id": peer_id,
				})
				_sync_inventory(peer_id)
			else:
				NetworkRPC.rpc_id(peer_id, "_on_build_result", {"success": false, "message": "放置失败"})
		"remove":
			if build_manager.remove_block(peer_id, grid_pos, player_pos):
				NetworkRPC.rpc("_on_block_removed", {"x": grid_pos.x, "y": grid_pos.y})
				_sync_inventory(peer_id)
			else:
				NetworkRPC.rpc_id(peer_id, "_on_build_result", {"success": false, "message": "拆除失败"})
