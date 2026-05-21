extends Node
class_name NetworkRPC

## 共享 RPC 中继节点 — 作为 autoload 存在于客户端和服务端相同路径
## 所有跨网络 RPC 方法统一在此定义，确保 NodePath 一致

# ---------- 客户端 → 服务端 RPC ----------

@rpc("any_peer", "call_remote", "reliable")
func _receive_player_input(input_data: Dictionary) -> void:
	## 服务端接收：客户端发送的玩家输入
	# 由 GameLoop 连接此信号处理
	var sender_id = multiplayer.get_remote_sender_id()
	player_input_received.emit(input_data, sender_id)


@rpc("any_peer", "call_remote", "reliable")
func _receive_auth_request(request_data: Dictionary) -> void:
	## 服务端接收：客户端发送的认证请求
	var sender_id = multiplayer.get_remote_sender_id()
	auth_request_received.emit(request_data, sender_id)


# ---------- 服务端 → 客户端 RPC ----------

@rpc("authority", "call_remote", "reliable")
func _on_world_state(state_data: Dictionary) -> void:
	## 客户端接收：服务端广播的世界状态
	world_state_received.emit(state_data)


@rpc("authority", "call_remote", "reliable")
func _on_auth_response(response_data: Dictionary) -> void:
	## 客户端接收：认证响应
	auth_response_received.emit(response_data)


@rpc("authority", "call_remote", "reliable")
func _on_player_joined(peer_id: int, player_data: Dictionary) -> void:
	## 客户端接收：新玩家加入通知
	player_joined_received.emit(peer_id, player_data)


@rpc("authority", "call_remote", "reliable")
func _on_player_left(peer_id: int) -> void:
	## 客户端接收：玩家离开通知
	player_left_received.emit(peer_id)


# ---------- 客户端 → 服务端 RPC ----------

@rpc("any_peer", "call_remote", "reliable")
func _receive_harvest_action(action_data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	harvest_action_received.emit(action_data, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func _receive_craft_action(action_data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	craft_action_received.emit(action_data, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func _receive_build_action(action_data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	build_action_received.emit(action_data, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func _receive_inventory_action(action_data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	inventory_action_received.emit(action_data, sender_id)

# ---------- 职业系统 RPC ----------

@rpc("any_peer", "call_remote", "reliable")
func _receive_class_action(action_data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	class_action_received.emit(action_data, sender_id)

# ---------- 服务端 → 客户端 RPC ----------

@rpc("authority", "call_remote", "reliable")
func _on_inventory_state(inventory_data: Dictionary) -> void:
	inventory_state_received.emit(inventory_data)

@rpc("authority", "call_remote", "reliable")
func _on_block_map(blocks: Array) -> void:
	block_map_received.emit(blocks)

@rpc("authority", "call_remote", "reliable")
func _on_block_placed(block_data: Dictionary) -> void:
	block_placed_received.emit(block_data)

@rpc("authority", "call_remote", "reliable")
func _on_block_removed(grid_pos: Dictionary) -> void:
	block_removed_received.emit(grid_pos)

@rpc("authority", "call_remote", "reliable")
func _on_craft_result(result_data: Dictionary) -> void:
	craft_result_received.emit(result_data)

@rpc("authority", "call_remote", "reliable")
func _on_build_result(result_data: Dictionary) -> void:
	build_result_received.emit(result_data)

@rpc("authority", "call_remote", "reliable")
func _on_class_stats(stats_data: Dictionary) -> void:
	class_stats_received.emit(stats_data)

@rpc("authority", "call_remote", "reliable")
func _on_skill_slots(slots_data: Array) -> void:
	skill_slots_received.emit(slots_data)


# ---------- 信号 ----------

## 服务端信号：收到玩家输入
signal player_input_received(input_data: Dictionary, peer_id: int)

## 服务端信号：收到认证请求（request_data, peer_id）
signal auth_request_received(request_data: Dictionary, peer_id: int)

## 客户端信号：收到世界状态
signal world_state_received(state_data: Dictionary)

## 客户端信号：收到认证响应
signal auth_response_received(response_data: Dictionary)

## 客户端信号：收到玩家加入通知
signal player_joined_received(peer_id: int, player_data: Dictionary)

## 客户端信号：收到玩家离开通知
signal player_left_received(peer_id: int)

signal harvest_action_received(action_data: Dictionary, peer_id: int)
signal craft_action_received(action_data: Dictionary, peer_id: int)
signal build_action_received(action_data: Dictionary, peer_id: int)
signal inventory_action_received(action_data: Dictionary, peer_id: int)

signal inventory_state_received(inventory_data: Dictionary)
signal block_map_received(blocks: Array)
signal block_placed_received(block_data: Dictionary)
signal block_removed_received(grid_pos: Dictionary)
signal craft_result_received(result_data: Dictionary)
signal build_result_received(result_data: Dictionary)
signal class_action_received(action_data: Dictionary, peer_id: int)
signal class_stats_received(stats_data: Dictionary)
signal skill_slots_received(slots_data: Array)

