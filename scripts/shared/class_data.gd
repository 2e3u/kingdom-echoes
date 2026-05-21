extends Node
class_name ClassDatabase

## 职业静态数据库 — 4 职业的固定属性定义

static var classes: Dictionary = {}

static func _static_init() -> void:
	_register_warrior()
	_register_archer()
	_register_mage()
	_register_ranger()

## 战士：近战物理，剑/斧/锤，高体高力
static func _register_warrior() -> void:
	classes[SharedEnums.ClassType.WARRIOR] = {
		"name": "战士",
		"description": "近战物理攻击者，擅长剑、斧、锤。高生命值与物理伤害。",
		"weapons": ["sword", "axe", "hammer"],
		"base_attributes": {
			SharedEnums.AttributeType.STRENGTH: 8,
			SharedEnums.AttributeType.AGILITY: 4,
			SharedEnums.AttributeType.CONSTITUTION: 8,
			SharedEnums.AttributeType.INTELLIGENCE: 2,
			SharedEnums.AttributeType.DEXTERITY: 5,
			SharedEnums.AttributeType.CHARISMA: 3,
		},
		"levelup_auto": {          # 每级自动分配
			SharedEnums.AttributeType.STRENGTH: 2,
			SharedEnums.AttributeType.CONSTITUTION: 2,
			SharedEnums.AttributeType.DEXTERITY: 1,
		},
		"branches": {
			SharedEnums.ClassBranch.BERSERKER: {
				"name": "狂战士",
				"description": "牺牲防御换取极致物理伤害",
			},
			SharedEnums.ClassBranch.GUARDIAN: {
				"name": "守护者",
				"description": "高防御坦克，保护队友",
			},
		},
	}

## 射手：远程物理，弓/弩/投掷，高敏中力
static func _register_archer() -> void:
	classes[SharedEnums.ClassType.ARCHER] = {
		"name": "射手",
		"description": "远程物理攻击者，擅长弓、弩。高暴击与灵活机动。",
		"weapons": ["bow", "crossbow", "throwing"],
		"base_attributes": {
			SharedEnums.AttributeType.STRENGTH: 5,
			SharedEnums.AttributeType.AGILITY: 8,
			SharedEnums.AttributeType.CONSTITUTION: 4,
			SharedEnums.AttributeType.INTELLIGENCE: 3,
			SharedEnums.AttributeType.DEXTERITY: 7,
			SharedEnums.AttributeType.CHARISMA: 3,
		},
		"levelup_auto": {
			SharedEnums.AttributeType.AGILITY: 3,
			SharedEnums.AttributeType.STRENGTH: 1,
			SharedEnums.AttributeType.DEXTERITY: 1,
		},
		"branches": {
			SharedEnums.ClassBranch.SNIPER: {
				"name": "狙击手",
				"description": "远程单点高爆发伤害",
			},
			SharedEnums.ClassBranch.SKIRMISHER: {
				"name": "游击者",
				"description": "灵活机动，范围攻击",
			},
		},
	}

## 法师：远程魔法，法杖/魔法书，高智低体
static func _register_mage() -> void:
	classes[SharedEnums.ClassType.MAGE] = {
		"name": "法师",
		"description": "远程魔法攻击者，擅长法杖与魔法书。高魔法伤害。",
		"weapons": ["staff", "spellbook"],
		"base_attributes": {
			SharedEnums.AttributeType.STRENGTH: 2,
			SharedEnums.AttributeType.AGILITY: 4,
			SharedEnums.AttributeType.CONSTITUTION: 3,
			SharedEnums.AttributeType.INTELLIGENCE: 9,
			SharedEnums.AttributeType.DEXTERITY: 6,
			SharedEnums.AttributeType.CHARISMA: 6,
		},
		"levelup_auto": {
			SharedEnums.AttributeType.INTELLIGENCE: 3,
			SharedEnums.AttributeType.DEXTERITY: 1,
			SharedEnums.AttributeType.CHARISMA: 1,
		},
		"branches": {
			SharedEnums.ClassBranch.ELEMENTALIST: {
				"name": "元素使",
				"description": "火水电雷四系元素魔法",
			},
			SharedEnums.ClassBranch.ARCANIST: {
				"name": "秘术师",
				"description": "暗系魔法 + 控制",
			},
		},
	}

## 游侠：灵活混合，双匕首/鞭，高中庸
static func _register_ranger() -> void:
	classes[SharedEnums.ClassType.RANGER] = {
		"name": "游侠",
		"description": "灵活混合攻击者，擅长双匕首与鞭。刺客潜行或陷阱驯兽。",
		"weapons": ["dagger", "whip"],
		"base_attributes": {
			SharedEnums.AttributeType.STRENGTH: 4,
			SharedEnums.AttributeType.AGILITY: 8,
			SharedEnums.AttributeType.CONSTITUTION: 4,
			SharedEnums.AttributeType.INTELLIGENCE: 4,
			SharedEnums.AttributeType.DEXTERITY: 7,
			SharedEnums.AttributeType.CHARISMA: 3,
		},
		"levelup_auto": {
			SharedEnums.AttributeType.AGILITY: 2,
			SharedEnums.AttributeType.DEXTERITY: 2,
			SharedEnums.AttributeType.STRENGTH: 1,
		},
		"branches": {
			SharedEnums.ClassBranch.ASSASSIN: {
				"name": "刺客",
				"description": "潜行偷袭，高暴击暗杀",
			},
			SharedEnums.ClassBranch.SURVIVALIST: {
				"name": "生存家",
				"description": "陷阱布置 + 野兽驯服",
			},
		},
	}

static func get_class(class_type: int) -> Dictionary:
	return classes.get(class_type, {})

static func get_class_name(class_type: int) -> String:
	return classes.get(class_type, {}).get("name", "未知")

static func get_base_attributes(class_type: int) -> Dictionary:
	return classes.get(class_type, {}).get("base_attributes", {}).duplicate(true)

static func get_levelup_auto(class_type: int) -> Dictionary:
	return classes.get(class_type, {}).get("levelup_auto", {}).duplicate(true)

static func get_branches(class_type: int) -> Dictionary:
	return classes.get(class_type, {}).get("branches", {})

static func get_weapons(class_type: int) -> Array:
	return classes.get(class_type, {}).get("weapons", [])
