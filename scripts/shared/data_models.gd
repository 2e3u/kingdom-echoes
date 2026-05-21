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
	# 职业系统
	var class_type: int = SharedEnums.ClassType.NONE
	var class_branch: int = SharedEnums.ClassBranch.NONE
	var level: int = 1
	var xp: int = 0
	# 6 属性
	var base_attributes: Dictionary = {}    # {STRENGTH: 5, AGILITY: 5, ...}
	var bonus_attributes: Dictionary = {}   # {STRENGTH: 0, AGILITY: 0, ...} — 自由分配
	var free_points: int = 0                # 未分配的自由属性点
	# 技能槽
	var skill_slots: Array[Dictionary] = []  # 5 个槽位 [{skill_id, slot_type}]
	var learned_skills: Array[String] = []   # 已学习技能 ID 列表
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
			"class_type": class_type,
			"class_branch": class_branch,
			"level": level,
			"xp": xp,
			"base_attributes": base_attributes,
			"bonus_attributes": bonus_attributes,
			"free_points": free_points,
			"skill_slots": skill_slots,
			"learned_skills": learned_skills,
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
		class_type = d.get("class_type", SharedEnums.ClassType.NONE)
		class_branch = d.get("class_branch", SharedEnums.ClassBranch.NONE)
		level = d.get("level", 1)
		xp = d.get("xp", 0)
		base_attributes = d.get("base_attributes", {})
		bonus_attributes = d.get("bonus_attributes", {})
		free_points = d.get("free_points", 0)
		skill_slots.clear()
		for s in d.get("skill_slots", []):
			skill_slots.append(s)
		learned_skills.clear()
		for sid in d.get("learned_skills", []):
			learned_skills.append(sid)
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

	# ---------- 角色属性（可序列化传输） ----------
	class CharacterStats:
		var class_type: int = SharedEnums.ClassType.NONE
		var level: int = 1
		var xp: int = 0
		var free_points: int = 0
		var base_attrs: Dictionary = {}
		var bonus_attrs: Dictionary = {}
		var equipped_stats: Dictionary = {}  # 装备附加属性

		func get_total(attr: int) -> int:
			var total: int = 0
			total += base_attrs.get(attr, 0)
			total += bonus_attrs.get(attr, 0)
			total += equipped_stats.get(attr, 0)
			return total

		func to_dict() -> Dictionary:
			return {
				"class_type": class_type,
				"level": level,
				"xp": xp,
				"free_points": free_points,
				"base_attributes": base_attrs,
				"bonus_attributes": bonus_attrs,
				"equipped_stats": equipped_stats,
			}

		func from_dict(d: Dictionary) -> void:
			class_type = d.get("class_type", SharedEnums.ClassType.NONE)
			level = d.get("level", 1)
			xp = d.get("xp", 0)
			free_points = d.get("free_points", 0)
			base_attrs = d.get("base_attributes", {})
			bonus_attrs = d.get("bonus_attributes", {})
			equipped_stats = d.get("equipped_stats", {})

	# ---------- 技能定义 ----------
	class SkillData:
		var skill_id: String = ""
		var name: String = ""
		var category: int = SharedEnums.SkillCategory.GENERAL
		var description: String = ""
		var class_type: int = SharedEnums.ClassType.NONE
		var class_branch: int = SharedEnums.ClassBranch.NONE
		var required_level: int = 1
		var cooldown: float = 1.0
		var mana_cost: int = 0
		var effects: Dictionary = {}

		func to_dict() -> Dictionary:
			return {
				"skill_id": skill_id,
				"name": name,
				"category": category,
				"description": description,
				"class_type": class_type,
				"class_branch": class_branch,
				"required_level": required_level,
				"cooldown": cooldown,
				"mana_cost": mana_cost,
				"effects": effects,
			}

		func from_dict(d: Dictionary) -> void:
			skill_id = d.get("skill_id", "")
			name = d.get("name", "")
			category = d.get("category", SharedEnums.SkillCategory.GENERAL)
			description = d.get("description", "")
			class_type = d.get("class_type", SharedEnums.ClassType.NONE)
			class_branch = d.get("class_branch", SharedEnums.ClassBranch.NONE)
			required_level = d.get("required_level", 1)
			cooldown = d.get("cooldown", 1.0)
			mana_cost = d.get("mana_cost", 0)
			effects = d.get("effects", {})

	# ---------- 技能槽 ----------
	class SkillSlot:
		var slot_index: int = 0
		var slot_type: int = SharedEnums.SkillSlotType.GENERAL_1
		var skill_id: String = ""
		var is_locked: bool = false

		func to_dict() -> Dictionary:
			return {
				"slot_index": slot_index,
				"slot_type": slot_type,
				"skill_id": skill_id,
				"is_locked": is_locked,
			}

		func from_dict(d: Dictionary) -> void:
			slot_index = d.get("slot_index", 0)
			slot_type = d.get("slot_type", SharedEnums.SkillSlotType.GENERAL_1)
			skill_id = d.get("skill_id", "")
			is_locked = d.get("is_locked", false)

func _ready():
	pass
