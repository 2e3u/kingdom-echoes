extends Node
class_name PersistenceManager

## 持久化管理器 — 负责 JSON 文件读写
## 世界状态每 5 秒自动保存，启动时恢复

const SAVE_INTERVAL: float = 5.0

var world_state_manager: WorldStateManager = null
var item_manager: ItemManager = null
var class_manager: ClassManager = null
var skill_manager: SkillManager = null
var _save_timer: float = 0.0

func _ready() -> void:
	_ensure_save_dir()
	print("[Persistence] 持久化管理器已初始化")

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SharedConstants.SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SharedConstants.SAVE_DIR)

func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_auto_save()

# ---------- 通用读写 ----------

func save_json(file_path: String, data: Dictionary) -> bool:
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[Persistence] 无法写入文件: %s" % file_path)
		return false
	file.store_string(json_string)
	file.close()
	print("[Persistence] 保存成功: %s" % file_path)
	return true

func load_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print("[Persistence] 文件不存在: %s" % file_path)
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[Persistence] 无法读取文件: %s" % file_path)
		return {}
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[Persistence] JSON 解析失败: %s" % file_path)
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

# ---------- 自动保存 ----------

func _auto_save() -> void:
	if world_state_manager:
		save_full_world_state()
	# 同时保存所有在线玩家的背包
	if item_manager and world_state_manager:
		for p in world_state_manager.world_state.players:
			var pid = p.get("player_id", -1)
			if pid >= 0:
				save_inventory(pid)
				if class_manager:
					save_player_class(pid)

# ---------- 世界状态持久化（含方块+资源节点） ----------

func save_full_world_state() -> bool:
	if not world_state_manager:
		return false
	var data = world_state_manager.get_full_snapshot()
	data["saved_at"] = Time.get_unix_time_from_system()
	return save_json(SharedConstants.SAVE_DIR + "world_state.json", data)

func load_full_world_state() -> Dictionary:
	var data = load_json(SharedConstants.SAVE_DIR + "world_state.json")
	if data.is_empty():
		print("[Persistence] 无世界存档，将使用程序生成")
		return {}
	data.erase("saved_at")
	# 恢复方块地图
	if world_state_manager:
		var blocks = data.get("placed_blocks", {})
		world_state_manager.placed_blocks = blocks
		var resources = data.get("resource_nodes", {})
		world_state_manager.resource_nodes = resources
		# 恢复世界状态字段（tick, players, game_state 等）
		world_state_manager.world_state.from_dict(data)
	print("[Persistence] 世界状态已加载, tick: %d" % data.get("tick", 0))
	return data

# 向后兼容别名
func save_world_state(world_data: Dictionary) -> bool:
	var data = world_data.duplicate(true)
	data["saved_at"] = Time.get_unix_time_from_system()
	return save_json(SharedConstants.SAVE_DIR + "world_state.json", data)

func load_world_state() -> Dictionary:
	return load_full_world_state()

# ---------- 世界地块数据持久化 ----------

func save_world_data(tiles: Array) -> bool:
	var data = {
		"world_version": SharedConstants.WORLD_VERSION,
		"tiles": tiles,
		"saved_at": Time.get_unix_time_from_system()
	}
	return save_json(SharedConstants.SAVE_DIR + "world_data.json", data)

func load_world_data() -> Dictionary:
	var data = load_json(SharedConstants.SAVE_DIR + "world_data.json")
	if data.is_empty():
		print("[Persistence] 无世界地块数据，将使用程序生成")
		return {}
	print("[Persistence] 世界地块数据已加载")
	return data

# ---------- 玩家背包持久化 ----------

func save_inventory(player_id: int) -> bool:
	if not item_manager:
		return false
	var inv_data = item_manager.get_inventory_dict(player_id)
	if inv_data.is_empty():
		return false
	# 合并到现有玩家数据
	var existing = load_player_data(player_id)
	existing["inventory"] = inv_data
	return save_player_data(player_id, existing)

func load_inventory(player_id: int) -> Dictionary:
	var data = load_player_data(player_id)
	return data.get("inventory", {})

func restore_player_inventory(player_id: int) -> bool:
	if not item_manager:
		return false
	var inv_data = load_inventory(player_id)
	if inv_data.is_empty():
		return false
	# 用保存的背包数据覆盖当前背包
	var inv = item_manager.get_inventory(player_id)
	if not inv:
		item_manager.initialize_player_inventory(player_id)
		inv = item_manager.get_inventory(player_id)
	if not inv:
		return false
	inv.from_dict(inv_data)
	print("[Persistence] 玩家 %d 背包已恢复 (%d 格)" % [player_id, inv_data.get("max_slots", 0)])
	return true

# ---------- 玩家数据持久化 ----------

func save_player_data(player_id: int, player_data: Dictionary) -> bool:
	var file_path = SharedConstants.SAVE_DIR + "player_%d.json" % player_id
	return save_json(file_path, player_data)

func load_player_data(player_id: int) -> Dictionary:
	var file_path = SharedConstants.SAVE_DIR + "player_%d.json" % player_id
	return load_json(file_path)

func delete_player_data(player_id: int) -> bool:
	var file_path = SharedConstants.SAVE_DIR + "player_%d.json" % player_id
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false

# ---------- 排行榜 ----------

func save_leaderboard(data: Array[Dictionary]) -> bool:
	var dict = {"leaderboard": data, "updated_at": Time.get_datetime_string_from_system()}
	return save_json(SharedConstants.SAVE_DIR + "leaderboard.json", dict)

func load_leaderboard() -> Array[Dictionary]:
	var data = load_json(SharedConstants.SAVE_DIR + "leaderboard.json")
	return data.get("leaderboard", [])

# ---------- 职业数据持久化 ----------

func save_player_class(player_id: int) -> bool:
	if not class_manager:
		return false
	var stats = class_manager.to_dict(player_id)
	if stats.is_empty():
		return false
	var skill_data = skill_manager.to_dict(player_id) if skill_manager else {}
	stats["skills"] = skill_data
	var existing = load_player_data(player_id)
	existing["class"] = stats
	return save_player_data(player_id, existing)

func load_player_class(player_id: int) -> Dictionary:
	var data = load_player_data(player_id)
	return data.get("class", {})

func restore_player_class(player_id: int) -> bool:
	var class_data = load_player_class(player_id)
	if class_data.is_empty():
		return false
	if class_manager:
		class_manager.restore(player_id, class_data)
	if skill_manager and class_data.has("skills"):
		skill_manager.from_dict(player_id, class_data["skills"])
	print("[Persistence] 玩家 %d 职业数据已恢复" % player_id)
	return true

