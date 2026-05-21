extends Control
class_name InventoryUI

## 客户端背包界面 — 格子网格 + 物品详情面板

var _inventory_data: Dictionary = {}
var _slots: Array[Control] = []
var _selected_slot: int = -1

@export var slot_scene: PackedScene = null
@export var grid_container: GridContainer = null
@export var detail_panel: Control = null
@export var detail_name: Label = null
@export var detail_desc: Label = null
@export var detail_durability: Label = null
@export var btn_use: Button = null
@export var btn_drop: Button = null
@export var btn_repair: Button = null

const SLOTS_PER_ROW: int = 5

func _ready() -> void:
	hide()
	if btn_use:
		btn_use.pressed.connect(_on_use_pressed)
	if btn_drop:
		btn_drop.pressed.connect(_on_drop_pressed)
	if btn_repair:
		btn_repair.pressed.connect(_on_repair_pressed)

func open(inventory_data: Dictionary) -> void:
	_inventory_data = inventory_data
	_selected_slot = -1
	_refresh_grid()
	_update_detail_panel()
	show()

func close() -> void:
	hide()

func _refresh_grid() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	if not grid_container:
		return
	var slots_data = _inventory_data.get("slots", [])
	for i in range(slots_data.size()):
		var item = slots_data[i]
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(48, 48)
		if not item.is_empty():
			var item_def = ItemDatabase.get_item(item.get("item_id", ""))
			if not item_def:
				continue
			slot_btn.text = item_def.get("name", "?")[0]
			slot_btn.tooltip_text = "%s x%d" % [item_def.get("name", "?"), item.get("quantity", 0)]
			if item.get("broken", false):
				slot_btn.modulate = Color.RED
			elif item.get("durability", 0) > 0:
				var max_dur = item_def.get("durability_max", 1)
				var ratio = float(item.get("durability", 0)) / max_dur
				if ratio < 0.3:
					slot_btn.modulate = Color.ORANGE
		slot_btn.pressed.connect(_on_slot_clicked.bind(i))
		grid_container.add_child(slot_btn)
		_slots.append(slot_btn)

func _on_slot_clicked(index: int) -> void:
	_selected_slot = index
	_update_detail_panel()

func _update_detail_panel() -> void:
	var has_selection = _selected_slot >= 0
	if detail_panel:
		detail_panel.visible = has_selection
	if not has_selection:
		return
	var slots_data = _inventory_data.get("slots", [])
	if _selected_slot >= slots_data.size():
		return
	var item = slots_data[_selected_slot]
	if item.is_empty():
		if detail_panel:
			detail_panel.visible = false
		return
	var item_def = ItemDatabase.get_item(item.get("item_id", ""))
	if detail_name:
		detail_name.text = item_def.get("name", "???")
	if detail_desc:
		var desc = "数量: %d" % item.get("quantity", 0)
		if item.get("broken", false):
			desc += "\n[已损坏 — 需要修理]"
		elif item.get("durability", 0) > 0:
			desc += "\n耐久: %d/%d" % [item.get("durability", 0), item_def.get("durability_max", 0)]
		var stats = item_def.get("stats", {})
		if not stats.is_empty():
			for stat_name in stats:
				desc += "\n%s: %d" % [stat_name, stats[stat_name]]
		detail_desc.text = desc
	if detail_durability:
		var dur = item.get("durability", 0)
		var max_dur = item_def.get("durability_max", 0)
		detail_durability.text = "耐久: %d/%d" % [dur, max_dur] if max_dur > 0 else ""
	if btn_use:
		btn_use.visible = not item_def.get("use_effect", {}).is_empty()
	if btn_repair:
		btn_repair.visible = item.get("broken", false)

func _on_use_pressed() -> void:
	if _selected_slot < 0:
		return
	var slots_data = _inventory_data.get("slots", [])
	if _selected_slot >= slots_data.size():
		return
	NetworkRPC.rpc("_receive_inventory_action", {
		"action": "use_item",
		"slot": _selected_slot,
	})

func _on_drop_pressed() -> void:
	if _selected_slot < 0:
		return
	NetworkRPC.rpc("_receive_inventory_action", {
		"action": "drop_item",
		"slot": _selected_slot,
		"quantity": 1,
	})

func _on_repair_pressed() -> void:
	if _selected_slot < 0:
		return
	NetworkRPC.rpc("_receive_inventory_action", {
		"action": "repair",
		"slot": _selected_slot,
	})

func update_inventory(inventory_data: Dictionary) -> void:
	_inventory_data = inventory_data
	_refresh_grid()
	if _selected_slot >= 0:
		_update_detail_panel()
