extends Control
class_name ClassSelectUI

## 职业选择界面 — 创角时显示，选择职业后发送 RPC

signal class_selected(class_type: int)

var _selected_class: int = SharedEnums.ClassType.NONE

@export var class_buttons_container: Control = null
@export var class_name_label: Label = null
@export var class_desc_label: Label = null
@export var class_attrs_label: Label = null
@export var confirm_button: Button = null

func _ready() -> void:
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm)
		confirm_button.disabled = true
	_create_class_buttons()

func _create_class_buttons() -> void:
	if not class_buttons_container:
		return
	for class_type in range(SharedEnums.ClassType.WARRIOR, SharedEnums.ClassType.RANGER + 1):
		var btn = Button.new()
		btn.text = ClassDatabase.get_class_name(class_type)
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_on_class_button.bind(class_type))
		class_buttons_container.add_child(btn)

func _on_class_button(class_type: int) -> void:
	_selected_class = class_type
	var def = ClassDatabase.get_class(class_type)
	if class_name_label:
		class_name_label.text = def.get("name", "")
	if class_desc_label:
		class_desc_label.text = def.get("description", "")
	if class_attrs_label:
		var attrs = def.get("base_attributes", {})
		var text = "基础属性:\n"
		text += "力量: %d | 敏捷: %d | 体质: %d\n" % [attrs.get(SharedEnums.AttributeType.STRENGTH, 0), attrs.get(SharedEnums.AttributeType.AGILITY, 0), attrs.get(SharedEnums.AttributeType.CONSTITUTION, 0)]
		text += "智力: %d | 灵巧: %d | 魅力: %d" % [attrs.get(SharedEnums.AttributeType.INTELLIGENCE, 0), attrs.get(SharedEnums.AttributeType.DEXTERITY, 0), attrs.get(SharedEnums.AttributeType.CHARISMA, 0)]
		class_attrs_label.text = text
	if confirm_button:
		confirm_button.disabled = false

func _on_confirm() -> void:
	if _selected_class == SharedEnums.ClassType.NONE:
		return
	NetworkRPC.rpc("_receive_class_action", {
		"action": "choose_class",
		"class_type": _selected_class,
	})
	class_selected.emit(_selected_class)
	hide()

func show_class_select() -> void:
	show()
