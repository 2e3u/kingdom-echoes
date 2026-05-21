extends Node
class_name BuildController

## 客户端建造控制器 — 管理建造模式、方块选择、输入处理
## 通过 NetworkRPC 向服务端发送放置/拆除请求

var _build_mode: bool = false
var _selected_block_id: String = ""
var _place_cooldown: float = 0.0
const PLACE_INTERVAL: float = 0.2

signal build_mode_changed(active: bool)


func _ready() -> void:
	if not NetworkRPC.build_result_received.is_connected(_on_build_result):
		NetworkRPC.build_result_received.connect(_on_build_result)

func _process(delta: float) -> void:
	# 冷却时间递减
	if _place_cooldown > 0.0:
		_place_cooldown -= delta


func toggle_build_mode() -> void:
	_build_mode = not _build_mode
	if not _build_mode:
		_selected_block_id = ""
	build_mode_changed.emit(_build_mode)


func select_block(block_id: String) -> void:
	_selected_block_id = block_id


func try_place(player_position: Vector2, mouse_world_pos: Vector2) -> bool:
	# 检查前置条件
	if not _build_mode:
		return false
	if _selected_block_id.is_empty():
		return false
	if _place_cooldown > 0.0:
		return false

	# 距离检查：玩家必须在建造范围内
	if player_position.distance_to(mouse_world_pos) > SharedConstants.BUILD_RANGE * SharedConstants.TILE_SIZE:
		return false

	# 重置冷却
	_place_cooldown = PLACE_INTERVAL

	var grid_pos = _world_to_grid(mouse_world_pos)
	var action_data = {
		"action": "place",
		"block_id": _selected_block_id,
		"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
	}

	# 发送到服务端
	NetworkRPC.rpc("_receive_build_action", action_data)
	return true


func try_remove(mouse_world_pos: Vector2) -> bool:
	# 检查前置条件
	if not _build_mode:
		return false
	if _place_cooldown > 0.0:
		return false

	# 距离检查
	# 注意：try_remove 不接收 player_position，由调用方在外部做距离检查或使用 try_remove_at

	# 重置冷却
	_place_cooldown = PLACE_INTERVAL

	var grid_pos = _world_to_grid(mouse_world_pos)
	var action_data = {
		"action": "remove",
		"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
	}

	# 发送到服务端
	NetworkRPC.rpc("_receive_build_action", action_data)
	return true


func try_remove_at(player_position: Vector2, mouse_world_pos: Vector2) -> bool:
	# 包含距离检查的拆除，推荐调用方使用此方法
	if not _build_mode:
		return false
	if _place_cooldown > 0.0:
		return false

	if player_position.distance_to(mouse_world_pos) > SharedConstants.BUILD_RANGE * SharedConstants.TILE_SIZE:
		return false

	return try_remove(mouse_world_pos)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	# 将世界像素坐标转换为网格坐标
	var grid_x = int(floor(world_pos.x / SharedConstants.TILE_SIZE))
	var grid_y = int(floor(world_pos.y / SharedConstants.TILE_SIZE))
	return Vector2i(grid_x, grid_y)


func is_build_mode_active() -> bool:
	return _build_mode


func get_selected_block_id() -> String:
	return _selected_block_id
func _on_build_result(result: Dictionary) -> void:
	var msg = result.get("message", "")
	if not msg.is_empty():
		print("[Build] %s" % msg)
