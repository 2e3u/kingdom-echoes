extends CanvasLayer
class_name UIController

## UI 控制器 — 管理所有 UI 界面
## 登录界面、HUD、设置、错误提示等

var login_ui: Control = null
var hud_ui: Control = null

# 登录界面子控件引用
var _email_input: LineEdit = null
var _password_input: LineEdit = null
var _player_name_input: LineEdit = null
var _address_input: LineEdit = null
var _login_button: Button = null
var _register_button: Button = null
var _status_label: Label = null

enum UIScreen {
	NONE,
	LOGIN,
	HUD,
	SETTINGS,
	ERROR,
}

var current_screen: UIScreen = UIScreen.NONE

signal connect_requested(address: String)
signal auth_requested(type: String, email: String, password: String, player_name: String)


func _ready() -> void:
	_load_login_screen()
	print("[UIController] UI 控制器已初始化")


func _load_login_screen() -> void:
	# 加载登录界面场景
	var login_scene = load("res://scenes/ui/login.tscn")
	if login_scene == null:
		push_error("[UIController] 无法加载 login.tscn")
		return

	login_ui = login_scene.instantiate()
	add_child(login_ui)

	# 查找子控件
	var vbox = login_ui.get_node_or_null("VBoxContainer")
	if vbox:
		_email_input = vbox.get_node_or_null("EmailInput") as LineEdit
		_password_input = vbox.get_node_or_null("PasswordInput") as LineEdit
		_player_name_input = vbox.get_node_or_null("PlayerNameInput") as LineEdit
		_address_input = vbox.get_node_or_null("ServerAddressInput") as LineEdit
		_status_label = vbox.get_node_or_null("StatusLabel") as Label

		var btn_container = vbox.get_node_or_null("ButtonContainer")
		if btn_container:
			_login_button = btn_container.get_node_or_null("LoginButton") as Button
			_register_button = btn_container.get_node_or_null("RegisterButton") as Button

	# 连接按钮信号
	if _login_button:
		_login_button.pressed.connect(_on_login_pressed)
	if _register_button:
		_register_button.pressed.connect(_on_register_pressed)

	# 初始状态：认证按钮禁用，等连接成功后再启用
	_set_auth_buttons_disabled(true)

	show_screen(UIScreen.LOGIN)


func _load_hud_screen() -> void:
	var hud_scene = load("res://scenes/ui/hud.tscn")
	if hud_scene:
		hud_ui = hud_scene.instantiate()
		add_child(hud_ui)
		hud_ui.visible = false


func show_screen(screen: UIScreen) -> void:
	if login_ui:
		login_ui.visible = (screen == UIScreen.LOGIN)
	if hud_ui:
		hud_ui.visible = (screen == UIScreen.HUD)
	current_screen = screen


# ---------- 连接管理 ----------

func on_connected() -> void:
	# 连接成功后启用认证按钮
	_set_auth_buttons_disabled(false)
	show_status("已连接到服务器 — 请登录或注册")


func on_disconnected() -> void:
	_set_auth_buttons_disabled(true)
	show_status("未连接")


# ---------- 登录界面交互 ----------

func _on_login_pressed() -> void:
	var email = _get_email()
	var password = _get_password()
	var player_name = _get_player_name()

	if email.is_empty() or password.is_empty():
		show_status("请输入邮箱和密码")
		return

	if player_name.is_empty():
		show_status("请输入玩家名称")
		return

	_set_auth_buttons_disabled(true)
	show_status("正在登录...")
	auth_requested.emit("login", email, password, player_name)


func _on_register_pressed() -> void:
	var email = _get_email()
	var password = _get_password()
	var player_name = _get_player_name()

	if email.is_empty() or password.is_empty():
		show_status("请输入邮箱和密码")
		return

	if player_name.is_empty():
		show_status("请输入玩家名称")
		return

	_set_auth_buttons_disabled(true)
	show_status("正在注册...")
	auth_requested.emit("register", email, password, player_name)


func _get_email() -> String:
	if _email_input:
		return _email_input.text.strip_edges()
	return ""


func _get_password() -> String:
	if _password_input:
		return _password_input.text
	return ""


func _get_player_name() -> String:
	if _player_name_input:
		return _player_name_input.text.strip_edges()
	return ""


func _get_address() -> String:
	if _address_input:
		var text = _address_input.text.strip_edges()
		if text != "":
			return text
	return "127.0.0.1"


func _set_auth_buttons_disabled(disabled: bool) -> void:
	if _login_button:
		_login_button.disabled = disabled
	if _register_button:
		_register_button.disabled = disabled


# ---------- 状态显示 ----------

func show_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
	else:
		print("[UIController] 状态: %s" % message)


func show_error(message: String) -> void:
	# 在状态标签上显示错误
	if _status_label:
		_status_label.text = "错误: %s" % message
	else:
		push_error("[UIController] 错误: %s" % message)

	# 恢复按钮
	_set_auth_buttons_disabled(false)


func get_server_address() -> String:
	return _get_address()


func show_auth_success(player_name: String) -> void:
	show_status("欢迎, %s!" % player_name)
	# 切换到 HUD
	if hud_ui == null:
		_load_hud_screen()
	show_screen(UIScreen.HUD)


# ---------- HUD 更新 ----------

func update_hud_fps(fps: int) -> void:
	pass


func update_hud_ping(ping_ms: int) -> void:
	pass


func update_hud_player_count(count: int) -> void:
	pass


func add_chat_message(sender: String, message: String) -> void:
	pass
