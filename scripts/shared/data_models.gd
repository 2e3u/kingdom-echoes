extends Node
class_name SharedDataModels

## 共享数据模型 — 客户端和服务端使用同一套数据结构
## 所有方法返回 Dictionary，通过 ENet RPC 以 JSON 序列化传输

# ---------- 玩家数据 ----------
class PlayerData:
	var player_id: int = 0
	var player_name: String = ""
	var team: int = SharedEnums.Team.NONE
	var state: int = SharedEnums.PlayerState.IDLE
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var health: int = 100
	var score: int = 0
	var is_connected: bool = false
	var join_time: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"player_id": player_id,
			"player_name": player_name,
			"team": team,
			"state": state,
			"position": {"x": position.x, "y": position.y},
			"velocity": {"x": velocity.x, "y": velocity.y},
			"health": health,
			"score": score,
			"is_connected": is_connected,
			"join_time": join_time,
		}

	func from_dict(d: Dictionary) -> void:
		player_id = d.get("player_id", 0)
		player_name = d.get("player_name", "")
		team = d.get("team", SharedEnums.Team.NONE)
		state = d.get("state", SharedEnums.PlayerState.IDLE)
		var pos = d.get("position", {"x": 0.0, "y": 0.0})
		position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		var vel = d.get("velocity", {"x": 0.0, "y": 0.0})
		velocity = Vector2(vel.get("x", 0.0), vel.get("y", 0.0))
		health = d.get("health", 100)
		score = d.get("score", 0)
		is_connected = d.get("is_connected", false)
		join_time = d.get("join_time", 0.0)


# ---------- 世界状态 ----------
class WorldState:
	var game_state: int = SharedEnums.GameState.LOBBY
	var tick: int = 0
	var players: Array[Dictionary] = []
	var server_time: float = 0.0
	var match_time_remaining: float = 0.0

	func to_dict() -> Dictionary:
		var player_dicts: Array[Dictionary] = []
		for p in players:
			player_dicts.append(p)
		return {
			"game_state": game_state,
			"tick": tick,
			"players": player_dicts,
			"server_time": server_time,
			"match_time_remaining": match_time_remaining,
		}

	func from_dict(d: Dictionary) -> void:
		game_state = d.get("game_state", SharedEnums.GameState.LOBBY)
		tick = d.get("tick", 0)
		players.clear()
		var p_arr: Array = d.get("players", [])
		for p in p_arr:
			players.append(p)
		server_time = d.get("server_time", 0.0)
		match_time_remaining = d.get("match_time_remaining", 0.0)


# ---------- 玩家输入 ----------
class PlayerInput:
	var player_id: int = 0
	var tick: int = 0
	var move_direction: Vector2 = Vector2.ZERO
	var interact: bool = false
	var timestamp: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"player_id": player_id,
			"tick": tick,
			"move_direction": {"x": move_direction.x, "y": move_direction.y},
			"interact": interact,
			"timestamp": timestamp,
		}

	func from_dict(d: Dictionary) -> void:
		player_id = d.get("player_id", 0)
		tick = d.get("tick", 0)
		var md = d.get("move_direction", {"x": 0.0, "y": 0.0})
		move_direction = Vector2(md.get("x", 0.0), md.get("y", 0.0))
		interact = d.get("interact", false)
		timestamp = d.get("timestamp", 0.0)


# ---------- 认证请求/响应 ----------
class AuthRequest:
	var type: String = ""            # "register" | "login" | "validate_token"
	var email: String = ""
	var password: String = ""        # 明文密码，由服务端哈希
	var player_name: String = ""
	var token: String = ""           # 用于自动登录的 session token
	var client_version: String = ""

	func to_dict() -> Dictionary:
		return {
			"type": type,
			"email": email,
			"password": password,
			"player_name": player_name,
			"token": token,
			"client_version": client_version,
		}

	func from_dict(d: Dictionary) -> void:
		type = d.get("type", "")
		email = d.get("email", "")
		password = d.get("password", "")
		player_name = d.get("player_name", "")
		token = d.get("token", "")
		client_version = d.get("client_version", "")


class AuthResponse:
	var success: bool = false
	var player_id: int = 0
	var player_name: String = ""
	var message: String = ""
	var token: String = ""           # session token，客户端保存用于自动登录
	var server_version: String = ""

	func to_dict() -> Dictionary:
		return {
			"success": success,
			"player_id": player_id,
			"player_name": player_name,
			"message": message,
			"token": token,
			"server_version": server_version,
		}

	func from_dict(d: Dictionary) -> void:
		success = d.get("success", false)
		player_id = d.get("player_id", 0)
		player_name = d.get("player_name", "")
		message = d.get("message", "")
		token = d.get("token", "")
		server_version = d.get("server_version", "")


# ---------- 物品实例 ----------
class ItemInstance:
	var item_id: String = ""
	var quantity: int = 0
	var durability: int = 0
	var affixes: Array[Dictionary] = []   # [{name, effect, value}]
	var rarity: int = SharedEnums.Rarity.COMMON

	func to_dict() -> Dictionary:
		return {
			"item_id": item_id,
			"quantity": quantity,
			"durability": durability,
			"affixes": affixes,
			"rarity": rarity,
		}

	func from_dict(d: Dictionary) -> void:
		item_id = d.get("item_id", "")
		quantity = d.get("quantity", 0)
		durability = d.get("durability", 0)
		affixes.clear()
		for a in d.get("affixes", []):
			affixes.append(a)
		rarity = d.get("rarity", SharedEnums.Rarity.COMMON)


# ---------- 背包 ----------
class Inventory:
	var slots: Array[Dictionary] = []  # 固定大小数组，空位={}
	var max_slots: int = SharedConstants.INVENTORY_INITIAL_SLOTS

	func to_dict() -> Dictionary:
		return {
			"slots": slots,
			"max_slots": max_slots,
		}

	func from_dict(d: Dictionary) -> void:
		slots.clear()
		for s in d.get("slots", []):
			slots.append(s)
		max_slots = d.get("max_slots", SharedConstants.INVENTORY_INITIAL_SLOTS)


# ---------- 方块实例（世界中的方块） ----------
class BlockInstance:
	var block_id: String = ""
	var position: Vector2 = Vector2.ZERO       # 世界坐标（像素）
	var grid_pos: Vector2i = Vector2i.ZERO     # 网格坐标
	var block_type: int = SharedEnums.BlockType.FLOOR
	var owner_id: int = 0                      # 放置者 peer_id

	func to_dict() -> Dictionary:
		return {
			"block_id": block_id,
			"position": {"x": position.x, "y": position.y},
			"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
			"block_type": block_type,
			"owner_id": owner_id,
		}

	func from_dict(d: Dictionary) -> void:
		block_id = d.get("block_id", "")
		var pos = d.get("position", {"x": 0.0, "y": 0.0})
		position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		var gp = d.get("grid_pos", {"x": 0, "y": 0})
		grid_pos = Vector2i(gp.get("x", 0), gp.get("y", 0))
		block_type = d.get("block_type", SharedEnums.BlockType.FLOOR)
		owner_id = d.get("owner_id", 0)


# ---------- 制造配方 ----------
class CraftRecipe:
	var recipe_id: String = ""
	var output_item_id: String = ""
	var output_quantity: int = 1
	var materials: Dictionary = {}     # {item_id: quantity}
	var station: int = SharedEnums.CraftStation.HAND
	var min_level: int = 0             # 玩家最低等级
	var unlocked_by_item: String = ""  # 材料触发解锁

	func to_dict() -> Dictionary:
		return {
			"recipe_id": recipe_id,
			"output_item_id": output_item_id,
			"output_quantity": output_quantity,
			"materials": materials,
			"station": station,
			"min_level": min_level,
			"unlocked_by_item": unlocked_by_item,
		}

	func from_dict(d: Dictionary) -> void:
		recipe_id = d.get("recipe_id", "")
		output_item_id = d.get("output_item_id", "")
		output_quantity = d.get("output_quantity", 1)
		materials = d.get("materials", {})
		station = d.get("station", SharedEnums.CraftStation.HAND)
		min_level = d.get("min_level", 0)
		unlocked_by_item = d.get("unlocked_by_item", "")



# ---------- 资源节点（世界中的可采集物） ----------
class ResourceNode:
	var node_id: String = ""
	var resource_type: int = SharedEnums.HarvestType.NONE
	var position: Vector2 = Vector2.ZERO
	var tool_tier_required: int = 0
	var drops: Array[Dictionary] = []  # [{item_id, quantity, chance}]
	var respawn_time: float = 60.0     # 重生时间（秒）
	var is_depleted: bool = false
	var depleted_at: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"node_id": node_id,
			"resource_type": resource_type,
			"position": {"x": position.x, "y": position.y},
			"tool_tier_required": tool_tier_required,
			"drops": drops,
			"respawn_time": respawn_time,
			"is_depleted": is_depleted,
			"depleted_at": depleted_at,
		}

	func from_dict(d: Dictionary) -> void:
		node_id = d.get("node_id", "")
		resource_type = d.get("resource_type", SharedEnums.HarvestType.NONE)
		var pos = d.get("position", {"x": 0.0, "y": 0.0})
		position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		tool_tier_required = d.get("tool_tier_required", 0)
		drops.clear()
		for drop in d.get("drops", []):
			drops.append(drop)
		respawn_time = d.get("respawn_time", 60.0)
		is_depleted = d.get("is_depleted", false)
		depleted_at = d.get("depleted_at", 0.0)


func _ready():
	pass
