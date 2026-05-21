extends Node
class_name AuthManager

## 认证管理器 — 处理邮箱+密码的注册和登录
## SHA-256 + 随机 salt 哈希密码存储
## Session token 管理（7天有效期）

signal auth_success(player_id: int, player_name: String)
signal auth_failed(reason: String)

const SERVER_VERSION: String = "0.1.0"
const TOKEN_EXPIRY_SEC: int = 7 * 24 * 3600  # 7天
const SALT_BYTES: int = 16
const TOKEN_BYTES: int = 32
const USERS_FILE: String = "user://data/users.json"
const EMAIL_REGEX: String = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

# 用户数据: { email: { "password_hash", "salt", "player_name", "tokens": [{token, expires_at}], "created_at" } }
var users: Dictionary = {}
var _crypto: Crypto = null


func _ready() -> void:
	users.clear()
	_crypto = Crypto.new()
	_ensure_data_dir()
	_load_users()
	# 启动时清理过期 token
	_clean_expired_tokens()
	print("[Auth] 认证管理器已初始化, 已加载 %d 个用户" % users.size())


# ---------- 公开接口 ----------

## 注册新用户
## 返回: { "success": bool, "message": String, "token": String, "player_name": String }
func register(email: String, password: String, player_name: String) -> Dictionary:
	email = email.strip_edges().to_lower()

	# 验证邮箱格式
	if not _validate_email(email):
		return {"success": false, "message": "邮箱格式不正确"}

	# 验证密码强度
	if password.length() < 6:
		return {"success": false, "message": "密码至少需要6个字符"}

	if password.length() > 64:
		return {"success": false, "message": "密码不能超过64个字符"}

	# 验证玩家名
	player_name = player_name.strip_edges()
	if player_name.is_empty():
		return {"success": false, "message": "玩家名不能为空"}

	if player_name.length() > 16:
		return {"success": false, "message": "玩家名过长（最多16字符）"}

	# 检查邮箱是否已注册
	if users.has(email):
		return {"success": false, "message": "该邮箱已注册"}

	# 生成 salt 并哈希密码
	var salt = _generate_salt()
	var password_hash = _hash_password(password, salt)

	# 生成 session token
	var token = _generate_token()
	var expires_at = Time.get_unix_time_from_system() + TOKEN_EXPIRY_SEC

	# 存储用户
	users[email] = {
		"password_hash": password_hash,
		"salt": salt,
		"player_name": player_name,
		"tokens": [{"token": token, "expires_at": expires_at}],
		"created_at": Time.get_unix_time_from_system(),
	}

	_save_users()
	print("[Auth] 新用户注册: %s (%s)" % [email, player_name])

	return {
		"success": true,
		"message": "注册成功！欢迎, %s!" % player_name,
		"token": token,
		"player_name": player_name,
	}


## 邮箱+密码登录
## 返回: { "success": bool, "message": String, "token": String, "player_name": String }
func login(email: String, password: String) -> Dictionary:
	email = email.strip_edges().to_lower()

	if not users.has(email):
		return {"success": false, "message": "邮箱未注册"}

	var user = users[email]
	var stored_salt = user.get("salt", "")
	var stored_hash = user.get("password_hash", "")

	# 比对密码哈希
	var input_hash = _hash_password(password, stored_salt)
	if input_hash != stored_hash:
		return {"success": false, "message": "密码错误"}

	# 生成新 session token（保留旧 token 最多5个）
	var token = _generate_token()
	var expires_at = Time.get_unix_time_from_system() + TOKEN_EXPIRY_SEC
	var tokens: Array = user.get("tokens", [])
	tokens.append({"token": token, "expires_at": expires_at})
	# 最多保留5个 token
	while tokens.size() > 5:
		tokens.pop_front()
	user["tokens"] = tokens

	_save_users()
	print("[Auth] 用户登录: %s (%s)" % [email, user.get("player_name", "?")])

	return {
		"success": true,
		"message": "登录成功！欢迎回来, %s!" % user.get("player_name", ""),
		"token": token,
		"player_name": user.get("player_name", ""),
	}


## 验证 session token
## 返回: { "success": bool, "message": String, "player_name": String, "email": String }
func validate_token(token: String) -> Dictionary:
	if token.is_empty():
		return {"success": false, "message": "Token 为空"}

	var now = Time.get_unix_time_from_system()

	for email in users:
		var user = users[email]
		var tokens: Array = user.get("tokens", [])
		for t in tokens:
			if t.get("token", "") == token:
				if t.get("expires_at", 0) > now:
					return {
						"success": true,
						"message": "Token 有效",
						"player_name": user.get("player_name", ""),
						"email": email,
					}
				else:
					return {"success": false, "message": "Token 已过期，请重新登录"}

	return {"success": false, "message": "无效的 Token"}


# ---------- 内部方法 ----------

## SHA-256 + salt 哈希密码
func _hash_password(password: String, salt: String) -> String:
	return (salt + password).sha256_text()


## 生成随机 salt（16 字节 → 32 字符 hex）
func _generate_salt() -> String:
	var bytes = _crypto.generate_random_bytes(SALT_BYTES)
	return bytes.hex_encode()


## 生成随机 session token（32 字节 → 64 字符 hex）
func _generate_token() -> String:
	var bytes = _crypto.generate_random_bytes(TOKEN_BYTES)
	return bytes.hex_encode()


## 验证邮箱格式
func _validate_email(email: String) -> bool:
	if email.is_empty():
		return false
	var regex = RegEx.new()
	var err = regex.compile(EMAIL_REGEX)
	if err != OK:
		push_error("[Auth] 邮箱正则编译失败: %d" % err)
		# 正则编译失败时回退到简单校验
		return email.contains("@") and email.contains(".") and email.find("@") < email.find(".")
	return regex.search(email) != null


# ---------- 持久化 ----------

func _ensure_data_dir() -> void:
	if not DirAccess.dir_exists_absolute("user://data"):
		DirAccess.make_dir_recursive_absolute("user://data")


func _save_users() -> void:
	var data = {"users": users}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(USERS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("[Auth] 无法保存用户数据: %s" % USERS_FILE)
		return
	file.store_string(json_string)
	file.close()


func _load_users() -> void:
	if not FileAccess.file_exists(USERS_FILE):
		print("[Auth] 用户数据文件不存在，将创建新文件")
		return
	var file = FileAccess.open(USERS_FILE, FileAccess.READ)
	if file == null:
		push_error("[Auth] 无法读取用户数据: %s" % USERS_FILE)
		return
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[Auth] 用户数据 JSON 解析失败")
		return

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return

	var loaded_users = data.get("users", {})
	if typeof(loaded_users) == TYPE_DICTIONARY:
		users = loaded_users


## 清理所有过期 token
func _clean_expired_tokens() -> void:
	var now = Time.get_unix_time_from_system()
	var cleaned_count: int = 0
	for email in users:
		var tokens: Array = users[email].get("tokens", [])
		var valid_tokens: Array = []
		for t in tokens:
			if t.get("expires_at", 0) > now:
				valid_tokens.append(t)
			else:
				cleaned_count += 1
		users[email]["tokens"] = valid_tokens
	if cleaned_count > 0:
		print("[Auth] 清理了 %d 个过期 token" % cleaned_count)
		_save_users()
