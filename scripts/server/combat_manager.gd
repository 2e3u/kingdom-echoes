extends Node
class_name CombatManager

## 服务端战斗管理器 — 攻击判定、伤害计算、死亡/重生

var player_manager: PlayerManager = null
var world_state_manager: WorldStateManager = null
var item_manager: ItemManager = null

const ATTACK_RANGE: float = 48.0
const RESPAWN_DELAY: float = 5.0
const HEALTH_REGEN_PER_SEC: float = 1.0
const HEALTH_REGEN_DELAY: float = 3.0  # 受伤后延迟再生

var _attack_cooldowns: Dictionary = {}       # {player_id: remaining_seconds}
var _last_damage_time: Dictionary = {}        # {player_id: timestamp}
var _respawn_timers: Dictionary = {}          # {player_id: remaining_seconds}
var _dead_players: Array[int] = []

signal damage_dealt(attacker_id: int, target_id: int, damage: int)
signal player_died(player_id: int, killer_id: int)
signal player_respawned(player_id: int)


func _ready() -> void:
	print("[Combat] 战斗管理器已初始化")


func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_respawns(delta)
	_tick_health_regen(delta)


# ---------- 攻击 ----------

func try_attack(attacker_id: int, target_id: int) -> Dictionary:
	if _attack_cooldowns.get(attacker_id, 0.0) > 0.0:
		return {"success": false, "message": "攻击冷却中"}
	if not player_manager:
		return {"success": false, "message": "系统未就绪"}
	var attacker = player_manager.get_player(attacker_id)
	var target = player_manager.get_player(target_id)
	if not attacker or not target:
		return {"success": false, "message": "目标不存在"}
	if target.health <= 0:
		return {"success": false, "message": "目标已死亡"}

	var dist = attacker.position.distance_to(target.position)
	if dist > ATTACK_RANGE:
		return {"success": false, "message": "目标不在攻击范围内"}

	var weapon = _get_equipped_weapon(attacker_id)
	if weapon.is_empty():
		return {"success": false, "message": "未装备武器"}

	var stats = weapon.get("stats", {})
	var base_dmg: float = stats.get("damage", 3)
	var atk_speed: float = stats.get("attack_speed", 1.0)
	var crit_chance: float = stats.get("crit_chance", 0.0)
	var crit_mult: float = stats.get("crit_multiplier", 1.5)

	var is_crit = randf() < crit_chance
	var raw_dmg = base_dmg * (crit_mult if is_crit else 1.0)

	var armor_reduction = _get_armor_reduction(target_id)
	var final_dmg = max(1, int(raw_dmg * (1.0 - armor_reduction)))

	target.health = max(0, target.health - final_dmg)
	_last_damage_time[target_id] = Time.get_ticks_msec() / 1000.0

	_attack_cooldowns[attacker_id] = 1.0 / atk_speed
	_consume_weapon_durability(attacker_id)

	damage_dealt.emit(attacker_id, target_id, final_dmg)

	var result = {
		"success": true,
		"damage": final_dmg,
		"is_crit": is_crit,
		"target_health": target.health,
	}

	if target.health <= 0:
		_handle_death(target_id, attacker_id)
		result["killed"] = true

	return result


func _get_equipped_weapon(player_id: int) -> Dictionary:
	if not item_manager:
		return {}
	var inv = item_manager.get_inventory(player_id)
	if not inv:
		return {}
	for slot in inv.slots:
		if slot.is_empty():
			continue
		if slot.get("broken", false):
			continue
		var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
		if item_def.get("category", -1) == SharedEnums.ItemCategory.WEAPON:
			return item_def
	return {}


func _get_armor_reduction(player_id: int) -> float:
	if not item_manager:
		return 0.0
	var inv = item_manager.get_inventory(player_id)
	if not inv:
		return 0.0
	var reduction: float = 0.0
	for slot in inv.slots:
		if slot.is_empty():
			continue
		if slot.get("broken", false):
			continue
		var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
		if item_def.get("category", -1) == SharedEnums.ItemCategory.ARMOR:
			reduction += item_def.get("damage_reduction", 0.0)
	return min(reduction, 0.75)  # 上限 75%


func _consume_weapon_durability(player_id: int) -> void:
	if not item_manager:
		return
	var inv = item_manager.get_inventory(player_id)
	if not inv:
		return
	for i in range(inv.slots.size()):
		var slot = inv.slots[i]
		if slot.is_empty():
			continue
		if slot.get("broken", false):
			continue
		var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
		if item_def.get("category", -1) == SharedEnums.ItemCategory.WEAPON:
			item_manager.consume_durability(player_id, i, 1)
			return


# ---------- 死亡 ----------

func _handle_death(player_id: int, killer_id: int) -> void:
	var pd = player_manager.get_player(player_id)
	if pd:
		pd.state = SharedEnums.PlayerState.DEAD
		# 掉落物品
		_drop_items_on_death(player_id)

	_dead_players.append(player_id)
	_respawn_timers[player_id] = RESPAWN_DELAY
	player_died.emit(player_id, killer_id)
	print("[Combat] 玩家 %d 被 %d 击杀" % [player_id, killer_id])


func _drop_items_on_death(player_id: int) -> void:
	if not item_manager:
		return
	var inv = item_manager.get_inventory(player_id)
	if not inv:
		return
	var dropped: Array[Dictionary] = []
	for i in range(inv.slots.size() - 1, -1, -1):
		var slot = inv.slots[i]
		if slot.is_empty():
			continue
		if randf() < 0.3:
			dropped.append(slot.duplicate())
			inv.slots[i] = {}
	if not dropped.is_empty():
		print("[Combat] 玩家 %d 死亡掉落 %d 件物品" % [player_id, dropped.size()])


# ---------- 重生 ----------

func _tick_respawns(delta: float) -> void:
	var respawned: Array[int] = []
	for pid in _respawn_timers:
		_respawn_timers[pid] -= delta
		if _respawn_timers[pid] <= 0.0:
			respawned.append(pid)

	for pid in respawned:
		_respawn_timers.erase(pid)
		_dead_players.erase(pid)
		_respawn_player(pid)


func _respawn_player(player_id: int) -> void:
	var pd = player_manager.get_player(player_id)
	if not pd:
		return
	pd.health = 100
	pd.state = SharedEnums.PlayerState.IDLE
	pd.position = player_manager.get_spawn_position()
	player_respawned.emit(player_id)
	print("[Combat] 玩家 %d 已重生" % player_id)


# ---------- 冷却 ----------

func _tick_cooldowns(delta: float) -> void:
	for pid in _attack_cooldowns:
		_attack_cooldowns[pid] = max(0.0, _attack_cooldowns[pid] - delta)


# ---------- 生命再生 ----------

func _tick_health_regen(delta: float) -> void:
	if not player_manager:
		return
	var now = Time.get_ticks_msec() / 1000.0
	for pd in player_manager.get_all_players():
		if pd.state == SharedEnums.PlayerState.DEAD:
			continue
		if pd.health <= 0 or pd.health >= 100:
			continue
		var last_dmg = _last_damage_time.get(pd.player_id, 0.0)
		if now - last_dmg < HEALTH_REGEN_DELAY:
			continue
		pd.health = min(100, pd.health + int(HEALTH_REGEN_PER_SEC * delta))
		if pd.health >= 100:
			pd.health = 100


# ---------- 查询 ----------

func is_player_dead(player_id: int) -> bool:
	return player_id in _dead_players


func get_attack_cooldown(player_id: int) -> float:
	return _attack_cooldowns.get(player_id, 0.0)


func get_respawn_remaining(player_id: int) -> float:
	return _respawn_timers.get(player_id, 0.0)
