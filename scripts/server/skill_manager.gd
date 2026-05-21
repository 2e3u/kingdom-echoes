extends Node
class_name SkillManager

## 服务端技能管理器 — 管理玩家技能学习、技能槽装备/卸下

var player_skills: Dictionary = {}  # {player_id: {skills: [String], slots: [SkillSlot]}}

## 初始化玩家技能数据
func init_player(player_id: int) -> void:
	player_skills[player_id] = {
		"learned_skills": [],
		"slots": _create_default_slots(),
	}
	print("[SkillManager] 玩家 %d 技能系统已初始化" % player_id)

## 学习技能
func learn_skill(player_id: int, skill_id: String) -> Dictionary:
	var data = _get_player_data(player_id)
	if data == null:
		return {"success": false, "message": "技能数据未初始化"}
	var skill_def = SkillDatabase.get_skill(skill_id)
	if skill_def.is_empty():
		return {"success": false, "message": "技能不存在: %s" % skill_id}
	if skill_id in data["learned_skills"]:
		return {"success": false, "message": "已学习该技能"}
	data["learned_skills"].append(skill_id)
	print("[SkillManager] 玩家 %d 学习技能: %s" % [player_id, skill_id])
	return {"success": true, "skill": skill_def}

## 装备技能到槽位
func equip_skill(player_id: int, slot_index: int, skill_id: String) -> Dictionary:
	var data = _get_player_data(player_id)
	if data == null:
		return {"success": false, "message": "技能数据未初始化"}
	if slot_index < 0 or slot_index >= data["slots"].size():
		return {"success": false, "message": "无效的技能槽索引: %d" % slot_index}
	if not skill_id.is_empty() and not skill_id in data["learned_skills"]:
		return {"success": false, "message": "未学习该技能: %s" % skill_id}
	var slot = data["slots"][slot_index]
	if slot.get("is_locked", false):
		return {"success": false, "message": "该技能槽已锁定"}
	# 检查槽位类型是否匹配
	if not skill_id.is_empty():
		var skill_def = SkillDatabase.get_skill(skill_id)
		var skill_cat = skill_def.get("category", SharedEnums.SkillCategory.GENERAL)
		var slot_type = slot.get("slot_type", -1)
		match slot_type:
			SharedEnums.SkillSlotType.PRIMARY_WEAPON:
				if skill_cat != SharedEnums.SkillCategory.WEAPON_PRIMARY:
					return {"success": false, "message": "该槽只能装备主武器技能"}
			SharedEnums.SkillSlotType.OFFHAND:
				if skill_cat != SharedEnums.SkillCategory.OFFHAND:
					return {"success": false, "message": "该槽只能装备副手技能"}
			SharedEnums.SkillSlotType.ULTIMATE:
				if skill_cat != SharedEnums.SkillCategory.ULTIMATE:
					return {"success": false, "message": "该槽只能装备终极技能"}
	# 检查是否已装备到其他槽（不允许重复装备）
	for i in range(data["slots"].size()):
		if i != slot_index and data["slots"][i].get("skill_id", "") == skill_id:
			data["slots"][i]["skill_id"] = ""  # 从旧槽位移除
	data["slots"][slot_index]["skill_id"] = skill_id
	return {"success": true, "slots": data["slots"]}

## 卸下技能
func unequip_skill(player_id: int, slot_index: int) -> Dictionary:
	return equip_skill(player_id, slot_index, "")

## 获取技能槽状态
func get_slots(player_id: int) -> Array:
	var data = _get_player_data(player_id)
	if data == null:
		return []
	return data["slots"]

## 获取已学技能列表
func get_learned_skills(player_id: int) -> Array:
	var data = _get_player_data(player_id)
	if data == null:
		return []
	return data["learned_skills"]

func _get_player_data(player_id: int):
	if not player_skills.has(player_id):
		return null
	return player_skills[player_id]

func _create_default_slots() -> Array[Dictionary]:
	return [
		{"slot_index": 0, "slot_type": SharedEnums.SkillSlotType.PRIMARY_WEAPON, "skill_id": "", "is_locked": false},
		{"slot_index": 1, "slot_type": SharedEnums.SkillSlotType.OFFHAND, "skill_id": "", "is_locked": false},
		{"slot_index": 2, "slot_type": SharedEnums.SkillSlotType.GENERAL_1, "skill_id": "", "is_locked": false},
		{"slot_index": 3, "slot_type": SharedEnums.SkillSlotType.GENERAL_2, "skill_id": "", "is_locked": false},
		{"slot_index": 4, "slot_type": SharedEnums.SkillSlotType.ULTIMATE, "skill_id": "", "is_locked": true},  # 等级解锁
	]

## 移除玩家技能数据
func remove_player(player_id: int) -> void:
	player_skills.erase(player_id)

func to_dict(player_id: int) -> Dictionary:
	var data = _get_player_data(player_id)
	if data == null:
		return {}
	return {"learned_skills": data["learned_skills"], "slots": data["slots"]}

func from_dict(player_id: int, d: Dictionary) -> void:
	player_skills[player_id] = {
		"learned_skills": d.get("learned_skills", []),
		"slots": d.get("slots", _create_default_slots()),
	}
