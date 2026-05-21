extends Node
class_name PlayerManager

## 玩家管理器 — 管理所有连接的玩家
## 处理玩家加入、离开、重连、数据存取

signal player_joined(player_id: int, player_name: String)
signal player_left(player_id: int)
## 玩家离开信号（用于 RPC 广播）
signal player_removed(player_id: int)

var players: Dictionary = {}  # {player_id: PlayerData}

func _ready() -> void:
	players.clear()

func add_player(player_id: int, player_name: String) -> SharedDataModels.PlayerData:
	var pd = SharedDataModels.PlayerData.new()
	pd.player_id = player_id
	pd.player_name = player_name
	pd.join_time = Time.get_ticks_msec() / 1000.0
	pd.is_connected = true
	# 使用 get_spawn_position() 设置随机出生位置
	pd.position = get_spawn_position()
	players[player_id] = pd
	print("[PlayerManager] 玩家加入: %d (%s), 当前玩家数: %d" % [player_id, player_name, players.size()])
	player_joined.emit(player_id, player_name)
	return pd

func remove_player(player_id: int) -> void:
	if players.has(player_id):
		var name = players[player_id].player_name
		players.erase(player_id)
		print("[PlayerManager] 玩家离开: %d (%s), 当前玩家数: %d" % [player_id, name, players.size()])
		player_left.emit(player_id)
		# 通知所有需要清理该玩家的子系统
		player_removed.emit(player_id)

func get_player(player_id: int) -> SharedDataModels.PlayerData:
	# TODO: 获取玩家数据，不存在返回 null
	return players.get(player_id, null)

func get_all_players() -> Array[SharedDataModels.PlayerData]:
	# TODO: 返回所有玩家数据数组
	var result: Array[SharedDataModels.PlayerData] = []
	for p in players.values():
		result.append(p)
	return result

func get_player_count() -> int:
	# TODO: 返回当前在线玩家数
	return players.size()

func get_player_dicts() -> Array[Dictionary]:
	# TODO: 返回所有玩家的 Dictionary 数组（用于序列化）
	var result: Array[Dictionary] = []
	for p in players.values():
		result.append(p.to_dict())
	return result

func get_spawn_position() -> Vector2:
	# 在世界范围内随机生成出生位置（留出边距防止贴边）
	const MARGIN: float = 100.0
	var x = randf_range(MARGIN, SharedConstants.WORLD_WIDTH - MARGIN)
	var y = randf_range(MARGIN, SharedConstants.WORLD_HEIGHT - MARGIN)
	return Vector2(x, y)
