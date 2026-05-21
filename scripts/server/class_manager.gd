extends Node
class_name ClassManager

## 服务端职业管理器 — 权威处理职业选择、属性分配、经验与升级

var player_classes: Dictionary = {}   # {player_id: CharacterStats}

func is_class_chosen(player_id: int) -> bool:
	return player_classes.has(player_id)

## 选择职业（创角时调用）
func choose_class(player_id: int, class_type: int) -> Dictionary:
	if class_type < SharedEnums.ClassType.WARRIOR or class_type > SharedEnums.ClassType.RANGER:
		return {"success": false, "message": "无效的职业类型"}
	var class_def = ClassDatabase.get_class(class_type)
	if class_def.is_empty():
		return {"success": false, "message": "职业数据不存在"}
	var stats = SharedDataModels.CharacterStats.new()
	stats.class_type = class_type
	stats.level = 1
	stats.xp = 0
	stats.free_points = 0
	stats.base_attrs = class_def.get("base_attributes", {}).duplicate(true)
	stats.bonus_attrs = _empty_attributes()
	player_classes[player_id] = stats
	print("[ClassManager] 玩家 %d 选择职业: %s" % [player_id, class_def.get("name", "?")])
	return {"success": true, "stats": stats.to_dict()}

## 添加经验值
func add_xp(player_id: int, amount: int) -> Dictionary:
	var stats = player_classes.get(player_id)
	if not stats:
		return {"success": false, "message": "尚未选择职业"}
	stats.xp += amount
	var leveled = false
	var levels_gained = 0
	while _xp_to_next_level(stats.level) <= stats.xp and stats.level < SharedConstants.MAX_LEVEL:
		_level_up(player_id)
		leveled = true
		levels_gained += 1
	var result = stats.to_dict()
	result["leveled_up"] = leveled
	result["levels_gained"] = levels_gained
	return {"success": true, "stats": result}

## 分配自由属性点
func allocate_attribute(player_id: int, attr: int, points: int) -> Dictionary:
	if points <= 0:
		return {"success": false, "message": "分配点数必须大于 0"}
	var stats = player_classes.get(player_id)
	if not stats:
		return {"success": false, "message": "尚未选择职业"}
	if attr < SharedEnums.AttributeType.STRENGTH or attr > SharedEnums.AttributeType.CHARISMA:
		return {"success": false, "message": "无效的属性类型"}
	if stats.free_points < points:
		return {"success": false, "message": "自由属性点不足 (需要 %d, 剩余 %d)" % [points, stats.free_points]}
	var current = stats.bonus_attrs.get(attr, 0)
	if current + points > SharedConstants.ATTR_MAX_PER_ATTR:
		return {"success": false, "message": "单项属性不能超过 %d" % SharedConstants.ATTR_MAX_PER_ATTR}
	stats.bonus_attrs[attr] = current + points
	stats.free_points -= points
	return {"success": true, "stats": stats.to_dict()}

## 获取角色属性快照
func get_stats(player_id: int) -> Dictionary:
	var stats = player_classes.get(player_id)
	if not stats:
		return {}
	return stats.to_dict()

func _level_up(player_id: int) -> void:
	var stats = player_classes.get(player_id)
	if not stats:
		return
	stats.level += 1
	stats.free_points += SharedConstants.ATTR_POINTS_PER_LEVEL
	# 自动分配职业属性
	var class_def = ClassDatabase.get_class(stats.class_type)
	var auto = class_def.get("levelup_auto", {})
	for attr_key in auto:
		stats.base_attrs[attr_key] = stats.base_attrs.get(attr_key, 0) + auto[attr_key]
	print("[ClassManager] 玩家 %d 升级至 Lv.%d" % [player_id, stats.level])

func _xp_to_next_level(level: int) -> int:
	return int(SharedConstants.XP_CURVE_BASE * pow(SharedConstants.XP_CURVE_GROWTH, level - 1))

func _empty_attributes() -> Dictionary:
	return {
		SharedEnums.AttributeType.STRENGTH: 0,
		SharedEnums.AttributeType.AGILITY: 0,
		SharedEnums.AttributeType.CONSTITUTION: 0,
		SharedEnums.AttributeType.INTELLIGENCE: 0,
		SharedEnums.AttributeType.DEXTERITY: 0,
		SharedEnums.AttributeType.CHARISMA: 0,
	}

## 移除玩家职业数据（玩家离线时调用）
func remove_player(player_id: int) -> void:
	player_classes.erase(player_id)

## 从持久化数据恢复
func restore(player_id: int, stats_data: Dictionary) -> void:
	var stats = SharedDataModels.CharacterStats.new()
	stats.from_dict(stats_data)
	player_classes[player_id] = stats
	print("[ClassManager] 玩家 %d 职业数据已恢复 (Lv.%d %s)" % [
		player_id, stats.level, ClassDatabase.get_class_name(stats.class_type)])

## 序列化所有数据（用于持久化）
func to_dict(player_id: int) -> Dictionary:
	var stats = player_classes.get(player_id)
	if not stats:
		return {}
	return stats.to_dict()
