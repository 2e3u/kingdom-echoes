extends Node
class_name GameClient

## 客户端入口脚本 — 挂载到 client.tscn 根节点
## 职责：连接服务端、管理 ENet 客户端、协调子模块

var game_client: GameClientManager = null
var renderer: ClientRenderer = null
var input_handler: InputHandler = null
var ui_controller: UIController = null

var player_id: int = 0
var player_name: String = ""
var is_connected: bool = false

# 认证状态
var _pending_auth_type: String = ""       # 待发送的认证类型（连接成功后发送）
var _pending_email: String = ""
var _pending_password: String = ""
var _pending_player_name: String = ""
var _is_token_auth_attempt: bool = false  # 当前是否为 token 自动登录尝试（失败时清除 token）

const AUTH_CONFIG_PATH: String = "user://auth.cfg"
const AUTH_SECTION: String = "auth"


func _ready() -> void:
	_initialize_subsystems()
	_try_auto_login()
	print("[Client] 客户端已初始化")


func _initialize_subsystems() -> void:
	# 创建网络管理模块
	game_client = GameClientManager.new()
	add_child(game_client)

	# 创建渲染模块
	renderer = ClientRenderer.new()
	add_child(renderer)

	# 创建输入处理模块
	input_handler = InputHandler.new()
	add_child(input_handler)

	# 创建采集控制器
	var gathering_controller = GatheringController.new()
	gathering_controller.name = "GatheringController"
	add_child(gathering_controller)
	input_handler.gathering_controller = gathering_controller

	# 创建建造控制器
	var build_controller = BuildController.new()
	build_controller.name = "BuildController"
	add_child(build_controller)

	# 创建教程控制器
	var tutorial_controller = TutorialController.new()
	tutorial_controller.name = "TutorialController"
	add_child(tutorial_controller)

	# 创建职业选择界面
	var class_select_ui = ClassSelectUI.new()
	class_select_ui.name = "ClassSelectUI"
	class_select_ui.hide()
	add_child(class_select_ui)

	# 创建角色面板
	var character_panel = CharacterPanel.new()
	character_panel.name = "CharacterPanel"
	character_panel.hide()
	add_child(character_panel)

	# 查找场景中已有的 UICanvas (带 UIController 脚本)
	ui_controller = $UICanvas as UIController

	# 将 GameClientManager 引用传递给 Renderer
	renderer.set_game_client(game_client)

	_connect_signals()


func _connect_signals() -> void:
	# 连接 GameClientManager 的信号
	if game_client:
		game_client.connected_to_server.connect(_on_connected)
		game_client.disconnected_from_server.connect(_on_disconnected)
		game_client.auth_response_received.connect(_on_auth_response)

	# 连接 InputHandler → GameClientManager：输入变化时发送 RPC
	if input_handler and game_client:
		if not input_handler.input_changed.is_connected(game_client.send_input):
			input_handler.input_changed.connect(game_client.send_input)

	# 连接 UIController 的信号
	if ui_controller:
		ui_controller.connect_requested.connect(_on_connect_requested)
		ui_controller.auth_requested.connect(_on_ui_auth_requested)

	# 连接 GameClientManager 的职业/技能信号
	if game_client:
		if not game_client.class_stats_updated.is_connected(_on_class_stats_updated):
			game_client.class_stats_updated.connect(_on_class_stats_updated)


func connect_to_server(address: String = "127.0.0.1", port: int = SharedConstants.SERVER_DEFAULT_PORT) -> void:
	# 委托给 GameClientManager 执行实际连接
	if game_client:
		game_client.connect_to_server(address, port)
	else:
		push_error("[Client] GameClientManager 未初始化")


func disconnect_from_server() -> void:
	if game_client:
		game_client.disconnect_from_server()
	is_connected = false
	player_id = 0
	if input_handler:
		input_handler.set_player_id(0)
	print("[Client] 已断开连接")


# ---------- 连接回调 ----------

func _on_connected() -> void:
	is_connected = true
	player_id = game_client.player_id if game_client else 0
	print("[Client] 连接成功, player_id: %d" % player_id)

	if ui_controller:
		ui_controller.on_connected()

	# 如果有待发送的认证请求，发送它
	if not _pending_auth_type.is_empty():
		_send_pending_auth()
	# 否则尝试 token 自动登录
	elif game_client:
		var token = _load_token()
		if not token.is_empty():
			print("[Client] 尝试 token 自动登录...")
			_is_token_auth_attempt = true
			game_client.send_auth_request("validate_token", "", "", "", token)
			if ui_controller:
				ui_controller.show_status("自动登录中...")


func _on_disconnected(reason: String) -> void:
	is_connected = false
	player_id = 0
	print("[Client] 连接断开: %s" % reason)

	_pending_auth_type = ""

	if input_handler:
		input_handler.set_player_id(0)

	if renderer:
		renderer.clear_all_sprites()

	if ui_controller:
		ui_controller.show_error(reason)
		ui_controller.on_disconnected()


func _on_connect_requested(address: String) -> void:
	print("[Client] 收到连接请求, 地址: %s" % address)
	if ui_controller:
		ui_controller.show_status("正在连接 %s ..." % address)
	connect_to_server(address)


# ---------- 认证流程 ----------

func _on_ui_auth_requested(auth_type: String, email: String, password: String, player_name: String) -> void:
	# UI 请求认证（登录/注册）
	if not is_connected:
		# 先连接，连接成功后再发送认证
		_pending_auth_type = auth_type
		_pending_email = email
		_pending_password = password
		_pending_player_name = player_name
		var address = ui_controller.get_server_address() if ui_controller else "127.0.0.1"
		_on_connect_requested(address)
		return
	_send_auth(auth_type, email, password, player_name)


func _send_pending_auth() -> void:
	if _pending_auth_type.is_empty() or game_client == null:
		return
	var auth_type = _pending_auth_type
	var email = _pending_email
	var password = _pending_password
	var player_name = _pending_player_name
	_pending_auth_type = ""
	_pending_email = ""
	_pending_password = ""
	_pending_player_name = ""
	_send_auth(auth_type, email, password, player_name)


func _send_auth(auth_type: String, email: String, password: String, player_name: String) -> void:
	# 用户主动发起的认证（登录/注册），清除 token 自动登录标记
	_is_token_auth_attempt = false
	if game_client:
		game_client.send_auth_request(auth_type, email, password, player_name)


func _on_auth_response(response_data: Dictionary) -> void:
	var response = SharedDataModels.AuthResponse.new()
	response.from_dict(response_data)

	if response.success:
		player_id = response.player_id
		player_name = response.player_name
		print("[Client] 认证成功: %s (id: %d)" % [player_name, player_id])

		# 存储 token 用于下次自动登录
		if not response.token.is_empty():
			_save_token(response.token)

		# 告知 InputHandler 本地玩家 ID
		if input_handler:
			input_handler.set_player_id(player_id)

		if ui_controller:
			ui_controller.show_auth_success(player_name)
	else:
		print("[Client] 认证失败: %s" % response.message)
		# 仅在 token 自动登录失败时清除无效 token
		if _is_token_auth_attempt:
			_clear_token()
			_is_token_auth_attempt = false
		if ui_controller:
			ui_controller.show_error(response.message)


# ---------- Token 持久化 ----------

func _save_token(token: String) -> void:
	var config = ConfigFile.new()
	config.set_value(AUTH_SECTION, "token", token)
	config.set_value(AUTH_SECTION, "saved_at", Time.get_unix_time_from_system())
	var err = config.save(AUTH_CONFIG_PATH)
	if err != OK:
		push_error("[Client] 无法保存 token: %d" % err)
	else:
		print("[Client] Token 已保存")


func _load_token() -> String:
	var config = ConfigFile.new()
	var err = config.load(AUTH_CONFIG_PATH)
	if err != OK:
		return ""
	return config.get_value(AUTH_SECTION, "token", "")


func _clear_token() -> void:
	var config = ConfigFile.new()
	config.set_value(AUTH_SECTION, "token", "")
	config.save(AUTH_CONFIG_PATH)
	print("[Client] Token 已清除")


func _try_auto_login() -> void:
	var token = _load_token()
	if token.is_empty():
		print("[Client] 无已保存的 token，跳过自动登录")
		return
	print("[Client] 发现已保存的 token，连接后将自动登录")


# ---------- 旧版兼容 ----------

func send_auth(player_name_str: String) -> void:
	# 保留旧接口，实际不再使用
	player_name = player_name_str
	print("[Client] send_auth() 已弃用，请使用邮箱登录")


func _process(_delta: float) -> void:
	# 客户端主循环
	# InputHandler 的自有 _process 会处理输入收集和节流
	# Renderer 通过信号驱动渲染
	# 此处不需要额外处理
	pass


func _exit_tree() -> void:
	disconnect_from_server()

func _on_class_stats_updated(stats_data: Dictionary) -> void:
	pass

