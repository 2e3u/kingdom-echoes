extends Control
class_name CharacterPanel

## 角色面板 — 查看属性、分配自由属性点、管理技能槽

var _current_stats: Dictionary = {}
var _current_slots: Array = []

@export var level_label: Label = null
@export var xp_label: Label = null
@export var class_label: Label = null
@export var free_points_label: Label = null
@export var attrs_container: Control = null
@export var slots_container: Control = null

func _ready() -> void:
	if not NetworkRPC.class_stats_received.is_connected(_on_stats_received):
		NetworkRPC.class_stats_received.connect(_on_stats_received)
	if not NetworkRPC.skill_slots_received.is_connected(_on_slots_received):
		NetworkRPC.skill_slots_received.connect(_on_slots_received)
	_create_attr_rows()
	_create_slot_rows()

func refresh() -> void:
	# 请求服务端发送最新属性
	pass

func _on_stats_received(stats_data: Dictionary) -> void:
	_current_stats = stats_data
	_update_display()

func _on_slots_received(slots_data: Array) -> void:
	_current_slots = slots_data
	_update_slots()

func _create_attr_rows() -> void:
	if not attrs_container:
		return
	var attr_names = ["力量", "敏捷", "体质", "智力", "灵巧", "魅力"]
	var attr_enums = [
		SharedEnums.AttributeType.STRENGTH,
		SharedEnums.AttributeType.AGILITY,
		SharedEnums.AttributeType.CONSTITUTION,
		SharedEnums.AttributeType.INTELLIGENCE,
		SharedEnums.AttributeType.DEXTERITY,
		SharedEnums.AttributeType.CHARISMA,
	]
	for i in range(attr_names.size()):
		var row = HBoxContainer.new()
		row.name = "attr_row_%d" % i
		var label = Label.new()
		label.name = "attr_name"
		label.text = attr_names[i]
		label.custom_minimum_size = Vector2(60, 0)
		row.add_child(label)
		var value = Label.new()
		value.name = "attr_value"
		value.text = "0"
		value.custom_minimum_size = Vector2(40, 0)
		row.add_child(value)
		var plus_btn = Button.new()
		plus_btn.name = "attr_plus"
		plus_btn.text = "+"
		plus_btn.pressed.connect(_on_attr_plus.bind(attr_enums[i]))
		row.add_child(plus_btn)
		attrs_container.add_child(row)

func _create_slot_rows() -> void:
	if not slots_container:
		return
	var slot_names = ["主武器", "副手", "通用1", "通用2", "终极"]
	for i in range(slot_names.size()):
		var row = HBoxContainer.new()
		var label = Label.new()
		label.text = "%s:" % slot_names[i]
		label.custom_minimum_size = Vector2(60, 0)
		row.add_child(label)
		var skill_label = Label.new()
		skill_label.name = "slot_skill_%d" % i
		skill_label.text = "(空)"
		row.add_child(skill_label)
		slots_container.add_child(row)

func _update_display() -> void:
	if level_label:
		level_label.text = "等级: %d" % _current_stats.get("level", 1)
	if xp_label:
		xp_label.text = "经验: %d" % _current_stats.get("xp", 0)
	if class_label:
		var ct = _current_stats.get("class_type", SharedEnums.ClassType.NONE)
		class_label.text = "职业: %s" % ClassDatabase.get_class_name(ct)
	if free_points_label:
		free_points_label.text = "自由属性点: %d" % _current_stats.get("free_points", 0)
	if attrs_container:
		var base = _current_stats.get("base_attributes", {})
		var bonus = _current_stats.get("bonus_attributes", {})
		var equip = _current_stats.get("equipped_stats", {})
		var attr_enums = [
			SharedEnums.AttributeType.STRENGTH,
			SharedEnums.AttributeType.AGILITY,
			SharedEnums.AttributeType.CONSTITUTION,
			SharedEnums.AttributeType.INTELLIGENCE,
			SharedEnums.AttributeType.DEXTERITY,
			SharedEnums.AttributeType.CHARISMA,
		]
		for i in range(attr_enums.size()):
			var row = attrs_container.get_child(i) if i < attrs_container.get_child_count() else null
			if not row:
				continue
			var total = base.get(attr_enums[i], 0) + bonus.get(attr_enums[i], 0) + equip.get(attr_enums[i], 0)
			var val = row.get_node_or_null("attr_value") as Label
			if val:
				val.text = "%d (%d+%d)" % [total, base.get(attr_enums[i], 0), bonus.get(attr_enums[i], 0) + equip.get(attr_enums[i], 0)]

func _update_slots() -> void:
	if not slots_container:
		return
	for i in range(_current_slots.size()):
		var row = slots_container.get_child(i) if i < slots_container.get_child_count() else null
		if not row:
			continue
		var skill_label = row.get_node_or_null("slot_skill_%d" % i) as Label
		if not skill_label:
			continue
		var sid = _current_slots[i].get("skill_id", "")
		skill_label.text = SkillDatabase.get_skill_name(sid) if not sid.is_empty() else "(空)"

func _on_attr_plus(attr: int) -> void:
	var free_points = _current_stats.get("free_points", 0)
	if free_points <= 0:
		return
	NetworkRPC.rpc("_receive_class_action", {
		"action": "allocate_attribute",
		"attribute": attr,
		"points": 1,
	})
