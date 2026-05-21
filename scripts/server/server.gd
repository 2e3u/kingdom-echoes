extends Node
class_name GameServer

## 服务端入口脚本 — 挂载到 server.tscn 根节点
## 职责：初始化 ENet 服务端、管理玩家连接、启动游戏循环

var enet_peer: ENetMultiplayerPeer = null
var tcp_server: TCPServer = null
var http_connections: Array[StreamPeerTCP] = []
var player_manager: PlayerManager = null
var game_loop: GameLoop = null
var world_state: WorldStateManager = null
var time_system: TimeSystem = null
var auth: AuthManager = null
var persistence: PersistenceManager = null
var world_generator: WorldGenerator = null


func _ready() -> void:
	# 判断是否为服务端模式
	var args = OS.get_cmdline_args()
	if not "--server" in args:
		print("[Server] 非服务端模式，跳过初始化")
		queue_free()
		return

	_initialize_subsystems()
	var enet_ok := _start_enet_server()
	_start_http_server()
	if not enet_ok:
		push_error("[Server] ENet 服务启动失败，服务端未完全就绪")
		return

	# 尝试恢复上次保存的世界状态
	var restored = _restore_world_state()

	# 仅当无存档时生成新世界
	if not restored:
		world_generator = WorldGenerator.new()
		world_generator.name = "WorldGenerator"
		add_child(world_generator)
		var world_data = world_generator.generate()
		if world_state:
			for node in world_data.get("resource_nodes", []):
				world_state.add_resource_node(node)
		print("[Server] 世界已生成, 种子: %d" % world_generator.get_seed())
	else:
		print("[Server] 使用已保存的世界，跳过程序生成")

	# 启动游戏循环
	if game_loop:
		game_loop.start()

	print("[Server] 服务端已启动 — ENet 端口: %d, HTTP 端口: %d" % [
		SharedConstants.SERVER_DEFAULT_PORT,
		SharedConstants.SERVER_HTTP_PORT
	])


func _initialize_subsystems() -> void:
	# 初始化所有子系统
	time_system = TimeSystem.new()
	add_child(time_system)

	auth = AuthManager.new()
	add_child(auth)

	player_manager = PlayerManager.new()
	add_child(player_manager)

	world_state = WorldStateManager.new()
	add_child(world_state)

	game_loop = GameLoop.new()
	add_child(game_loop)

	persistence = PersistenceManager.new()
	add_child(persistence)

	# 将子系统引用注入 GameLoop
	game_loop.world_state_manager = world_state
	game_loop.player_manager = player_manager
	game_loop.time_system = time_system
	# 将 world_state 引用注入子模块（BuildManager 也需要）
	if game_loop.build_manager:
		game_loop.build_manager.world_state_manager = world_state

	# 将 WorldStateManager 引用注入 PersistenceManager（用于自动保存）
	persistence.world_state_manager = world_state
	persistence.item_manager = game_loop.item_manager
	persistence.class_manager = game_loop.class_manager
	persistence.skill_manager = game_loop.skill_manager

	_connect_signals()


func _connect_signals() -> void:
	# 连接 PlayerManager 信号 → GameLoop
	if player_manager and game_loop:
		if not player_manager.player_joined.is_connected(game_loop._on_player_joined):
			player_manager.player_joined.connect(game_loop._on_player_joined)
		if not player_manager.player_left.is_connected(game_loop._on_player_left):
			player_manager.player_left.connect(game_loop._on_player_left)

	# 连接认证请求信号（来自 NetworkRPC autoload）
	if not NetworkRPC.auth_request_received.is_connected(_on_auth_request):
		NetworkRPC.auth_request_received.connect(_on_auth_request)


func _start_enet_server() -> bool:
	# 创建 ENetMultiplayerPeer 服务端
	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(SharedConstants.SERVER_DEFAULT_PORT, SharedConstants.MAX_PLAYERS)
	if error != OK:
		push_error("[Server] ENet 启动失败: %d" % error)
		return false

	multiplayer.multiplayer_peer = enet_peer

	# 连接玩家连接/断开信号
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("[Server] ENet 服务端已启动, 最大玩家数: %d, 端口: %d" % [
		SharedConstants.MAX_PLAYERS, SharedConstants.SERVER_DEFAULT_PORT
	])
	return true


func _on_peer_connected(id: int) -> void:
	print("[Server] 客户端已连接, peer_id: %d (等待认证...)" % id)
	# 不再立即添加到 PlayerManager，等待客户端发送认证请求


func _on_peer_disconnected(id: int) -> void:
	print("[Server] 客户端已断开, peer_id: %d" % id)
	# 从 PlayerManager 移除（如果已经通过认证）
	if player_manager:
		player_manager.remove_player(id)


# ---------- 认证处理 ----------

func _on_auth_request(request_data: Dictionary, peer_id: int) -> void:
	print("[Server] 收到认证请求, peer_id: %d, type: %s" % [peer_id, request_data.get("type", "?")])

	var request_type = request_data.get("type", "")
	var response: Dictionary

	match request_type:
		"register":
			response = auth.register(
				request_data.get("email", ""),
				request_data.get("password", ""),
				request_data.get("player_name", "")
			)
		"login":
			response = auth.login(
				request_data.get("email", ""),
				request_data.get("password", "")
			)
		"validate_token":
			response = auth.validate_token(request_data.get("token", ""))
		_:
			response = {"success": false, "message": "未知认证类型: %s" % request_type}

	# 版本校验
	if response.get("success", false) and request_type != "validate_token":
		var client_version = request_data.get("client_version", "")
		if client_version != auth.SERVER_VERSION:
			response = {
				"success": false,
				"message": "客户端版本不匹配! 服务端: %s, 客户端: %s" % [auth.SERVER_VERSION, client_version],
				"server_version": auth.SERVER_VERSION,
			}
		else:
			response["server_version"] = auth.SERVER_VERSION

	# 认证成功：添加到 PlayerManager
	if response.get("success", false):
		var player_name = response.get("player_name", "Player_%d" % peer_id)
		player_manager.add_player(peer_id, player_name)
		response["player_id"] = peer_id
		print("[Server] 认证成功, peer_id: %d, 玩家: %s" % [peer_id, player_name])
		# 恢复玩家背包
		if persistence:
			persistence.restore_player_inventory(peer_id)
			persistence.restore_player_class(peer_id)

	# 发送响应
	var response_dict = _build_auth_response_dict(response)
	NetworkRPC.rpc_id(peer_id, "_on_auth_response", response_dict)

	# 认证失败：延迟断开连接
	if not response.get("success", false):
		print("[Server] 认证失败, peer_id: %d: %s" % [peer_id, response.get("message", "")])
		_disconnect_peer_delayed(peer_id)


func _build_auth_response_dict(response: Dictionary) -> Dictionary:
	return {
		"success": response.get("success", false),
		"player_id": response.get("player_id", 0),
		"player_name": response.get("player_name", ""),
		"message": response.get("message", ""),
		"token": response.get("token", ""),
		"server_version": response.get("server_version", ""),
	}


func _disconnect_peer_delayed(peer_id: int) -> void:
	# 延迟断开，确保客户端有时间接收错误消息
	await get_tree().create_timer(0.5).timeout
	if enet_peer:
		enet_peer.disconnect_peer(peer_id)


func _start_http_server() -> void:
	# 使用 TCPServer 实现健康检查端点 (Godot 4.4 无内置 HTTP 服务器)
	tcp_server = TCPServer.new()
	var error = tcp_server.listen(SharedConstants.SERVER_HTTP_PORT, "127.0.0.1")
	if error != OK:
		push_error("[Server] HTTP 健康检查启动失败: %d" % error)
		return

	print("[Server] HTTP 健康检查端点已启动 (端口 %d)" % SharedConstants.SERVER_HTTP_PORT)


func _process(_delta: float) -> void:
	# 轮询 HTTP 连接
	_process_http_connections()


func _process_http_connections() -> void:
	if tcp_server == null:
		return

	# 接受新连接
	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		if conn:
			http_connections.append(conn)

	# 处理已有连接
	var i: int = 0
	while i < http_connections.size():
		var conn: StreamPeerTCP = http_connections[i]
		conn.poll()

		var status = conn.get_status()
		match status:
			StreamPeerTCP.STATUS_CONNECTED:
				# 有数据可读时读取 HTTP 请求
				if conn.get_available_bytes() > 0:
					conn.get_utf8_string(conn.get_available_bytes())
					# 发送健康检查响应
					var response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
					conn.put_utf8_string(response)
					# 主动关闭连接，释放服务端资源
					conn.disconnect_from_host()
					http_connections.remove_at(i)
					continue
				i += 1
			StreamPeerTCP.STATUS_NONE:
				# 连接已关闭，移除
				conn.disconnect_from_host()
				http_connections.remove_at(i)
			_:
				i += 1


func _restore_world_state() -> bool:
	if not persistence or not world_state:
		return false
	var saved = persistence.load_full_world_state()
	if saved.is_empty():
		print("[Server] 无已保存的世界状态，使用全新世界")
		return false
	print("[Server] 世界状态已恢复: %d 个玩家, %d 个方块, %d 个资源节点, tick=%d" % [
		saved.get("players", []).size(),
		saved.get("placed_blocks", {}).size(),
		saved.get("resource_nodes", {}).size(),
		saved.get("tick", 0)])
	return true


func _exit_tree() -> void:
	# 退出前保存世界状态
	if persistence and world_state:
		persistence.save_full_world_state()
		print("[Server] 世界状态已保存")

	# 停止游戏循环
	if game_loop:
		game_loop.stop()

	# 清理资源
	# 关闭所有 HTTP 连接
	for conn in http_connections:
		conn.disconnect_from_host()
	http_connections.clear()

	if tcp_server:
		tcp_server.stop()
		tcp_server = null

	if enet_peer:
		enet_peer.close()
		enet_peer = null

	print("[Server] 服务端已关闭")
