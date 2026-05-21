extends Node
class_name BuildManager

## 服务端建造管理器 — 验证权限、距离，执行放置/拆除方块
## 仅服务端权威操作，客户端通过 RPC 发送请求

var item_manager: ItemManager = null
var world_state_manager: WorldStateManager = null


func can_place_block(player_id: int, grid_pos: Vector2i, block_id: String, player_pos: Vector2 = Vector2.ZERO) -> bool:
	# 1. 检查距离
	var block_world_pos = Vector2(grid_pos.x * SharedConstants.TILE_SIZE, grid_pos.y * SharedConstants.TILE_SIZE)
	if player_pos.distance_to(block_world_pos) > SharedConstants.BUILD_RANGE * SharedConstants.TILE_SIZE:
		return false
	# 2. 检查方块物品是否存在
	var item_def = ItemDatabase.get_item(block_id)
	if item_def.is_empty():
		return false
	if not item_def.has("block_type"):
		return false
	# 3. 检查该网格位置是否已被占用
	var grid_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if world_state_manager and world_state_manager.placed_blocks.has(grid_key):
		return false
	# 4. 检查玩家背包中是否拥有该方块物品（至少 1 个）
	if item_manager and not item_manager.has_items(player_id, block_id, 1):
		return false
	return true


func place_block(player_id: int, grid_pos: Vector2i, block_id: String, player_pos: Vector2 = Vector2.ZERO) -> bool:
	if not can_place_block(player_id, grid_pos, block_id, player_pos):
		return false
	if not item_manager.remove_item(player_id, block_id, 1):
		return false
	var item_def = ItemDatabase.get_item(block_id)
	var block_type = item_def.get("block_type", SharedEnums.BlockType.FLOOR)
	var station_type = item_def.get("station_type", -1)
	var block_data = {
		"block_id": block_id,
		"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
		"position": {"x": grid_pos.x * SharedConstants.TILE_SIZE, "y": grid_pos.y * SharedConstants.TILE_SIZE},
		"block_type": block_type,
		"owner_id": player_id,
	}
	if station_type >= 0:
		block_data["station_type"] = station_type
	var grid_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if world_state_manager:
		world_state_manager.place_block(grid_key, block_data)
	return true


func can_remove_block(player_id: int, grid_pos: Vector2i, player_pos: Vector2 = Vector2.ZERO) -> bool:
	if not world_state_manager:
		return false
	# 1. 检查距离
	var block_world_pos = Vector2(grid_pos.x * SharedConstants.TILE_SIZE, grid_pos.y * SharedConstants.TILE_SIZE)
	if player_pos.distance_to(block_world_pos) > SharedConstants.BUILD_RANGE * SharedConstants.TILE_SIZE:
		return false
	# 2. 检查方块存在且为所有者
	var grid_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if not world_state_manager.placed_blocks.has(grid_key):
		return false
	var block = world_state_manager.placed_blocks[grid_key]
	if block.get("owner_id", -1) != player_id:
		return false
	# 3. 检查背包空间能否容纳返还的物品
	var block_id = block.get("block_id", "")
	if item_manager and not block_id.is_empty():
		if not item_manager.can_add_item(player_id, block_id, 1):
			return false
	return true


func remove_block(player_id: int, grid_pos: Vector2i, player_pos: Vector2 = Vector2.ZERO) -> bool:
	if not can_remove_block(player_id, grid_pos, player_pos):
		return false
	var grid_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	var block = world_state_manager.placed_blocks[grid_key]
	var block_id = block.get("block_id", "")
	world_state_manager.remove_block(grid_key)
	if item_manager and not block_id.is_empty():
		item_manager.add_item(player_id, block_id, 1)
	return true
