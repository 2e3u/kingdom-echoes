extends Node
## 作为 autoload 注册，不可使用 class_name

## 技能静态数据库 — 所有技能的固定属性定义
## 技能来源：武器自带、天赋树解锁、任务奖励

static var skills: Dictionary = {}

static func _static_init() -> void:
	_register_warrior_skills()
	_register_archer_skills()
	_register_mage_skills()
	_register_ranger_skills()
	_register_common_skills()

# ---------- 战士技能 ----------

static func _register_warrior_skills() -> void:
	# 狂战士分支
	skills["warrior_power_strike"] = {
		"name": "强力一击",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "蓄力重击，造成 150% 武器伤害",
		"class_type": SharedEnums.ClassType.WARRIOR,
		"class_branch": SharedEnums.ClassBranch.BERSERKER,
		"required_level": 3,
		"cooldown": 6.0,
		"mana_cost": 15,
		"effects": {"damage_mult": 1.5},
	}
	skills["warrior_whirlwind"] = {
		"name": "旋风斩",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "旋转攻击周围敌人，造成 100% 武器伤害",
		"class_type": SharedEnums.ClassType.WARRIOR,
		"class_branch": SharedEnums.ClassBranch.BERSERKER,
		"required_level": 8,
		"cooldown": 10.0,
		"mana_cost": 25,
		"effects": {"damage_mult": 1.0, "aoe_radius": 96},
	}
	# 守护者分支
	skills["warrior_shield_wall"] = {
		"name": "盾墙",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "举盾防御，减少 40% 伤害，持续 5 秒",
		"class_type": SharedEnums.ClassType.WARRIOR,
		"class_branch": SharedEnums.ClassBranch.GUARDIAN,
		"required_level": 3,
		"cooldown": 20.0,
		"mana_cost": 20,
		"effects": {"damage_reduction": 0.4, "duration": 5.0},
	}
	skills["warrior_taunt"] = {
		"name": "嘲讽",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "嘲讽附近敌人，强制攻击自己 3 秒",
		"class_type": SharedEnums.ClassType.WARRIOR,
		"class_branch": SharedEnums.ClassBranch.GUARDIAN,
		"required_level": 8,
		"cooldown": 15.0,
		"mana_cost": 10,
		"effects": {"taunt_duration": 3.0, "aoe_radius": 128},
	}

# ---------- 射手技能 ----------

static func _register_archer_skills() -> void:
	skills["archer_headshot"] = {
		"name": "精准射击",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "瞄准弱点，造成 200% 武器伤害，必定暴击",
		"class_type": SharedEnums.ClassType.ARCHER,
		"class_branch": SharedEnums.ClassBranch.SNIPER,
		"required_level": 3,
		"cooldown": 8.0,
		"mana_cost": 20,
		"effects": {"damage_mult": 2.0, "guaranteed_crit": true},
	}
	skills["archer_arrow_rain"] = {
		"name": "箭雨",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "向目标区域释放箭雨，对范围内敌人造成 80% 武器伤害",
		"class_type": SharedEnums.ClassType.ARCHER,
		"class_branch": SharedEnums.ClassBranch.SKIRMISHER,
		"required_level": 3,
		"cooldown": 12.0,
		"mana_cost": 30,
		"effects": {"damage_mult": 0.8, "aoe_radius": 128},
	}

# ---------- 法师技能 ----------

static func _register_mage_skills() -> void:
	skills["mage_fireball"] = {
		"name": "火球术",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "发射火球，造成 120% 魔法伤害，附加灼烧",
		"class_type": SharedEnums.ClassType.MAGE,
		"class_branch": SharedEnums.ClassBranch.ELEMENTALIST,
		"required_level": 3,
		"cooldown": 4.0,
		"mana_cost": 15,
		"effects": {"damage_mult": 1.2, "element": "fire", "burn_duration": 3.0},
	}
	skills["mage_dark_bolt"] = {
		"name": "暗影箭",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "释放暗影能量，造成 130% 魔法伤害，减速目标",
		"class_type": SharedEnums.ClassType.MAGE,
		"class_branch": SharedEnums.ClassBranch.ARCANIST,
		"required_level": 3,
		"cooldown": 5.0,
		"mana_cost": 18,
		"effects": {"damage_mult": 1.3, "element": "dark", "slow_amount": 0.3, "slow_duration": 2.0},
	}

# ---------- 游侠技能 ----------

static func _register_ranger_skills() -> void:
	skills["ranger_backstab"] = {
		"name": "背刺",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "从背后攻击，造成 250% 武器伤害（需潜行或背后位置）",
		"class_type": SharedEnums.ClassType.RANGER,
		"class_branch": SharedEnums.ClassBranch.ASSASSIN,
		"required_level": 3,
		"cooldown": 8.0,
		"mana_cost": 20,
		"effects": {"damage_mult": 2.5, "requires_stealth": true},
	}
	skills["ranger_bear_trap"] = {
		"name": "捕兽夹",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "放置陷阱，触发后定身敌人 2 秒并造成 80% 武器伤害",
		"class_type": SharedEnums.ClassType.RANGER,
		"class_branch": SharedEnums.ClassBranch.SURVIVALIST,
		"required_level": 3,
		"cooldown": 15.0,
		"mana_cost": 15,
		"effects": {"damage_mult": 0.8, "root_duration": 2.0, "trap_duration": 30.0},
	}

# ---------- 通用技能 ----------

static func _register_common_skills() -> void:
	skills["dash"] = {
		"name": "闪避突进",
		"category": SharedEnums.SkillCategory.GENERAL,
		"description": "向移动方向快速冲刺，无敌帧 0.2 秒",
		"class_type": SharedEnums.ClassType.NONE,  # 全职业通用
		"class_branch": SharedEnums.ClassBranch.NONE,
		"required_level": 5,
		"cooldown": 5.0,
		"mana_cost": 10,
		"effects": {"dash_distance": 128, "invincible_duration": 0.2},
	}

static func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

static func get_skill_name(skill_id: String) -> String:
	return skills.get(skill_id, {}).get("name", skill_id)

static func get_skills_for_class(class_type: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_id in skills:
		var s = skills[skill_id]
		var ct = s.get("class_type", SharedEnums.ClassType.NONE)
		if ct == class_type or ct == SharedEnums.ClassType.NONE:
			result.append(s)
	return result

static func get_skills_for_branch(branch: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_id in skills:
		var s = skills[skill_id]
		if s.get("class_branch", SharedEnums.ClassBranch.NONE) == branch:
			result.append(s)
	return result
