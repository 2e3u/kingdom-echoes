extends Node
class_name GameClientManager

## 联网管理器 — 处理 RPC 调用、状态同步、插值/预测
## 客户端与服务器之间的网络通信核心
##
## 所有 @rpc 方法通过 NetworkRPC autoload 定义（保证 NodePath 一致）
## 本节点连接到 NetworkRPC 的信号来接收数据

var enet_peer: ENetMultiplayerPeer = null
var player_id: int = 0
var server_tick: int = 0
var last_received_world_state: Dictionary = {}
var pending_inputs: Array[Dictionary] = []
var latency_ms: int = 0
var time_offset: float = 0.0
var is_connected: bool = false

# 客户端预测相关
var _predicted_position: Vector2 = Vector2(SharedConstants.WORLD_WIDTH / 2, SharedConstants.WORLD_HEIGHT / 2)
var _has_predicted_position: bool = false

signal connected_to_server()
signal disconnected_from_server(reason: String)
signal world_state_received(state: Dictionary)
signal remote_player_joined(peer_id: int, player_data: Dictionary)
signal remote_player_left(peer_id: int)
## 客户端信号：收到认证响应（转发自 NetworkRPC）
signal auth_response_received(response_data: Dictionary)
## 客户端信号：背包数据更新
signal inventory_updated(inventory_data: Dictionary)
signal block_updated(block_data: Dictionary)
signal block_removed(grid_pos: Dictionary)
signal class_stats_updated(stats_data: Dictionary)
signal skill_slots_updated(slots_data: Array)

func _ready() -> void:
	print("[GameClientManager] 联网管理器已初始化")
	_connect_network_signals()


func _connect_network_signals() -> void:
	# 连接到 NetworkRPC autoload 的信号（接收服务端消息）
	if not NetworkRPC.world_state_received.is_connected(_on_world_state_received):
		NetworkRPC.world_state_received.connect(_on_world_state_received)
	if not NetworkRPC.auth_response_received.is_connected(_on_auth_response_received):
		NetworkRPC.auth_response_received.connect(_on_auth_response_received)
	if not NetworkRPC.player_joined_received.is_connected(_on_player_joined_received):
		NetworkRPC.player_joined_received.connect(_on_player_joined_received)
	if not NetworkRPC.player_left_received.is_connected(_on_player_left_received):
		NetworkRPC.player_left_received.connect(_on_player_left_received)


	if not NetworkRPC.inventory_state_received.is_connected(_on_inventory_state):
		NetworkRPC.inventory_state_received.connect(_on_inventory_state)
	if not NetworkRPC.block_placed_received.is_connected(_on_block_placed_received):
		NetworkRPC.block_placed_received.connect(_on_block_placed_received)
	if not NetworkRPC.block_removed_received.is_connected(_on_block_removed_received):
		NetworkRPC.block_removed_received.connect(_on_block_removed_received)
	if not NetworkRPC.class_stats_received.is_connected(_on_class_stats_received):
		NetworkRPC.class_stats_received.connect(_on_class_stats_received)
	if not NetworkRPC.skill_slots_received.is_connected(_on_skill_slots_received):
		NetworkRPC.skill_slots_received.connect(_on_skill_slots_received)


# ---------- 连接管理 ----------

func connect_to_server(address: String, port: int = SharedConstants.SERVER_DEFAULT_PORT) -> void:
	# 防止重复连接：先断开已有连接
	if enet_peer or multiplayer.multiplayer_peer:
		disconnect_from_server()

	# 断开旧信号绑定，防止重复绑定
	if multiplayer.connected_to_server.is_connected(_on_connected_ok):
		multiplayer.connected_to_server.disconnect(_on_connected_ok)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

	# 创建 ENetMultiplayerPeer 客户端
	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_client(address, port)
	if error != OK:
		push_error("[GameClientManager] 创建客户端失败: %d" % error)
		disconnected_from_server.emit("无法创建网络连接")
		return

	multiplayer.multiplayer_peer = enet_peer

	# 连接 multiplayer 信号
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# 重新绑定 NetworkRPC 信号（确保连接有效）
	_connect_network_signals()

	print("[GameClientManager] 正在连接到 %s:%d ..." % [address, port])


func disconnect_from_server() -> void:
	if enet_peer:
		enet_peer.close()
		enet_peer = null

	multiplayer.multiplayer_peer = null
	is_connected = false
	_has_predicted_position = false
	_disconnect_network_signals()
	print("[GameClientManager] 已断开连接")


func _disconnect_network_signals() -> void:
	# 断开 NetworkRPC autoload 的所有信号连接（与 _connect_network_signals 对应）
	if NetworkRPC.world_state_received.is_connected(_on_world_state_received):
		NetworkRPC.world_state_received.disconnect(_on_world_state_received)
	if NetworkRPC.auth_response_received.is_connected(_on_auth_response_received):
		NetworkRPC.auth_response_received.disconnect(_on_auth_response_received)
	if NetworkRPC.player_joined_received.is_connected(_on_player_joined_received):
		NetworkRPC.player_joined_received.disconnect(_on_player_joined_received)
	if NetworkRPC.player_left_received.is_connected(_on_player_left_received):
		NetworkRPC.player_left_received.disconnect(_on_player_left_received)
	if NetworkRPC.inventory_state_received.is_connected(_on_inventory_state):
		NetworkRPC.inventory_state_received.disconnect(_on_inventory_state)
	if NetworkRPC.block_placed_received.is_connected(_on_block_placed_received):
		NetworkRPC.block_placed_received.disconnect(_on_block_placed_received)
	if NetworkRPC.block_removed_received.is_connected(_on_block_removed_received):
		NetworkRPC.block_removed_received.disconnect(_on_block_removed_received)
	if NetworkRPC.class_stats_received.is_connected(_on_class_stats_received):
		NetworkRPC.class_stats_received.disconnect(_on_class_stats_received)
	if NetworkRPC.skill_slots_received.is_connected(_on_skill_slots_received):
		NetworkRPC.skill_slots_received.disconnect(_on_skill_slots_received)


func _on_connected_ok() -> void:
	player_id = multiplayer.get_unique_id()
	is_connected = true
	print("[GameClientManager] 已连接到服务器, player_id: %d" % player_id)
	connected_to_server.emit()


func _on_connection_failed() -> void:
	is_connected = false
	multiplayer.multiplayer_peer = null
	print("[GameClientManager] 连接服务器失败")
	disconnected_from_server.emit("连接服务器失败")


func _on_server_disconnected() -> void:
	is_connected = false
	multiplayer.multiplayer_peer = null
	print("[GameClientManager] 与服务器断开连接")
	disconnected_from_server.emit("与服务器断开连接")


# ---------- 接收服务端消息（来自 NetworkRPC 信号） ----------

func _on_world_state_received(state_data: Dictionary) -> void:
	# 接收服务端推送的权威世界状态
	last_received_world_state = state_data
	server_tick = state_data.get("tick", 0)
	# 客户端预测纠正
	_reconcile_position(state_data)
	world_state_received.emit(state_data)


func _on_auth_response_received(response_data: Dictionary) -> void:
	# 接收认证响应，转发给上层（client.gd 处理 token 存储等）
	var response = SharedDataModels.AuthResponse.new()
	response.from_dict(response_data)
	if response.success:
		player_id = response.player_id
		print("[GameClientManager] 认证成功, player_id: %d" % player_id)
	else:
		print("[GameClientManager] 认证失败: %s" % response.message)
	auth_response_received.emit(response_data)


func _on_player_joined_received(peer_id: int, player_data: Dictionary) -> void:
	# 接收服务端通知：新玩家加入
	# 不处理本地玩家自己（本地玩家通过 connected_to_server 信号处理）
	if peer_id == player_id:
		return
	print("[GameClientManager] 远程玩家加入: %d (%s)" % [peer_id, player_data.get("player_name", "?")])
	remote_player_joined.emit(peer_id, player_data)


func _on_player_left_received(peer_id: int) -> void:
	# 接收服务端通知：玩家离开
	print("[GameClientManager] 远程玩家离开: %d" % peer_id)
	remote_player_left.emit(peer_id)


func _on_inventory_state(inventory_data: Dictionary) -> void:
	# 接收服务端推送的背包状态更新
	inventory_updated.emit(inventory_data)


func _on_block_placed_received(block_data: Dictionary) -> void:
	block_updated.emit(block_data)


func _on_block_removed_received(grid_pos: Dictionary) -> void:
	block_removed.emit(grid_pos)


func _on_class_stats_received(stats_data: Dictionary) -> void:
	class_stats_updated.emit(stats_data)


func _on_skill_slots_received(slots_data: Array) -> void:
	skill_slots_updated.emit(slots_data)


# ---------- RPC: 发送到服务端 ----------

func send_input(input_data: Dictionary) -> void:
	# 发送玩家输入到服务端，通过 NetworkRPC autoload 保证 NodePath 一致
	if not is_connected:
		return
	NetworkRPC.rpc_id(1, "_receive_player_input", input_data)
	# 客户端预测：立即应用本地输入
	_apply_prediction(input_data)


func send_auth_request(auth_type: String, email: String, password: String, player_name: String, token: String = "") -> void:
	# 发送认证请求（注册、登录或 token 验证）
	var auth = SharedDataModels.AuthRequest.new()
	auth.type = auth_type
	auth.email = email
	auth.password = password
	auth.player_name = player_name
	auth.token = token
	auth.client_version = "0.1.0"
	NetworkRPC.rpc_id(1, "_receive_auth_request", auth.to_dict())
	print("[GameClientManager] 发送认证请求: type=%s, email=%s" % [auth_type, email])


# ---------- 客户端预测 ----------

func _apply_prediction(input_data: Dictionary) -> void:
	# 根据本地输入立即更新预测位置
	var md = input_data.get("move_direction", {"x": 0.0, "y": 0.0})
	var direction = Vector2(md.get("x", 0.0), md.get("y", 0.0))
	_predicted_position += direction * SharedConstants.PLAYER_SPEED * SharedConstants.TICK_DELTA
	# 边界限制（与服务端一致，防止视觉抖动）
	_predicted_position.x = clamp(_predicted_position.x, 0.0, SharedConstants.WORLD_WIDTH)
	_predicted_position.y = clamp(_predicted_position.y, 0.0, SharedConstants.WORLD_HEIGHT)
	_has_predicted_position = true


func _reconcile_position(server_state: Dictionary) -> void:
	# 服务端状态纠正：比较预测位置与服务端权威位置
	if not _has_predicted_position:
		return
	var players: Array = server_state.get("players", [])
	for p in players:
		var pid = p.get("player_id", -1)
		if pid == player_id:
			var sp = p.get("position", {"x": 0.0, "y": 0.0})
			var server_pos = Vector2(sp.get("x", 0.0), sp.get("y", 0.0))
			var error_distance = _predicted_position.distance_to(server_pos)
			# 误差大于阈值时纠正
			const SNAP_THRESHOLD: float = 50.0
			if error_distance > SNAP_THRESHOLD:
				_predicted_position = server_pos
			else:
				# 平滑插值到服务端位置
				_predicted_position = _predicted_position.lerp(server_pos, 0.3)
			break


func get_predicted_or_server_position() -> Vector2:
	# 返回预测位置或兜底查找服务端位置
	if _has_predicted_position:
		return _predicted_position
	# 从最后收到的世界状态中查找本地玩家位置
	var players: Array = last_received_world_state.get("players", [])
	for p in players:
		if p.get("player_id", -1) == player_id:
			var sp = p.get("position", {"x": 0.0, "y": 0.0})
			return Vector2(sp.get("x", 0.0), sp.get("y", 0.0))
	return Vector2(SharedConstants.WORLD_WIDTH / 2, SharedConstants.WORLD_HEIGHT / 2)


# ---------- 插值 ----------

func interpolate_remote_players(alpha: float) -> Dictionary:
	# 对远程玩家进行插值，返回插值后的状态用于渲染
	# alpha: 插值因子 [0, 1]
	var result = last_received_world_state.duplicate(true)
	var players: Array = result.get("players", [])
	for i in range(players.size()):
		var p = players[i]
		if p.get("player_id", -1) == player_id:
			# 本地玩家使用预测位置
			var pred = get_predicted_or_server_position()
			p["position"] = {"x": pred.x, "y": pred.y}
		# 远程玩家暂时直接使用服务端位置（后续可加入插值缓冲）
	return result


func calculate_latency(server_time: float, client_send_time: float) -> void:
	# 根据服务端返回的时间戳计算延迟
	var now = Time.get_ticks_msec() / 1000.0
	latency_ms = int((now - client_send_time) * 1000.0)

