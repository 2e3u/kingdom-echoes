extends RefCounted
class_name HarvestController

## HarvestController — 管理资源采集：查找/开始/更新/取消采集、资源耗尽、工具耐久消耗、物品分配

signal harvest_completed(item_id: String, qty: int)

# Dependencies
var player: CharacterBody2D
var resource_sprites: Dictionary
var resource_data: Dictionary
var item_manager: ItemManager
var hud_controller: HUDController
var spawn_text: Callable

# State
var _harvesting: bool = false
var _harvest_target_id: String = ""
var _harvest_progress: float = 0.0
var _harvest_duration: float = 1.5


func setup(p_player, p_resource_sprites, p_resource_data, p_item_manager, p_hud_controller, p_spawn_text) -> void:
	player = p_player
	resource_sprites = p_resource_sprites
	resource_data = p_resource_data
	item_manager = p_item_manager
	hud_controller = p_hud_controller
	spawn_text = p_spawn_text


func is_harvesting() -> bool:
	return _harvesting


func get_progress() -> float:
	return _harvest_progress


# ========== 采集入口 ==========

## 尝试开始采集最近的资源，返回 true 表示开始采集
func try_harvest() -> bool:
	var rid = _find_nearest_resource()
	if rid.is_empty():
		return false
	var res = resource_data[rid]
	var required_tier = res.get("tool_tier", 0)
	var harvest_type = res.get("harvest_type", -1)

	# 检查工具
	var tool_tier = 0
	if required_tier > SharedEnums.ToolTier.NONE:
		tool_tier = _get_best_tool_tier(harvest_type)
		if tool_tier < required_tier:
			var tier_names = {1: "木", 2: "石", 3: "铜", 4: "铁", 5: "秘银"}
			spawn_text.call(player.position + Vector2(0, -20), "需要%s质工具!" % tier_names.get(required_tier, "?"))
			return false

	# 计算采集时间：基础1.5秒，工具越好越快
	var speed_mult = float(required_tier + 1) / float(max(tool_tier, 0) + 1)
	_harvest_duration = 1.5 * speed_mult
	_harvest_target_id = rid
	_harvest_progress = 0.0
	_harvesting = true
	hud_controller.show_harvest_bar(true)
	return true


# ========== 帧更新 ==========

func update(delta: float) -> void:
	if not Input.is_action_pressed("build_place"):
		cancel()
		return

	# 检查目标是否仍在范围内
	var rid = _harvest_target_id
	if rid.is_empty() or not resource_sprites.has(rid) or resource_data.get(rid, {}).get("depleted", false):
		cancel()
		return
	var dist = player.position.distance_to(resource_sprites[rid].position)
	if dist > 60:
		cancel()
		return

	_harvest_progress += delta / _harvest_duration
	hud_controller.update_harvest_bar(_harvest_progress)

	if _harvest_progress >= 1.0:
		_complete_harvest()


# ========== 取消采集 ==========

func cancel() -> void:
	_harvesting = false
	_harvest_target_id = ""
	_harvest_progress = 0.0
	hud_controller.show_harvest_bar(false)


# ========== 内部：查找最近资源 ==========

func _find_nearest_resource() -> String:
	var nearest_id = ""
	var nearest_dist = 55.0
	for rid in resource_sprites:
		if resource_data.get(rid, {}).get("depleted", false):
			continue
		var dist = player.position.distance_to(resource_sprites[rid].position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = rid
	return nearest_id


# ========== 内部：完成采集 ==========

func _complete_harvest() -> void:
	var rid = _harvest_target_id
	var res = resource_data[rid]
	res["depleted"] = true
	var sprite: Sprite2D = resource_sprites[rid]

	# 树变成树墩
	var is_tree = res.get("item_id", "") == "wood"
	if is_tree:
		sprite.texture = TextureGen.get_stump_texture()
	else:
		sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)

	# 消耗工具耐久
	var harvest_type = res.get("harvest_type", -1)
	var required_tier = res.get("tool_tier", 0)
	if required_tier > SharedEnums.ToolTier.NONE:
		_consume_tool_durability(harvest_type)

	# 物品放入快捷栏
	var item_id = res.get("item_id", "")
	var qty = res.get("quantity", 1)
	_add_to_hotbar_first(item_id, qty)
	spawn_text.call(sprite.position, "+%d %s" % [qty, res.get("name", item_id)])

	harvest_completed.emit(item_id, qty)

	cancel()


# ========== 内部：物品分配到快捷栏 ==========

func _add_to_hotbar_first(item_id: String, qty: int) -> void:
	var inv = item_manager.get_inventory(1)
	if not inv:
		item_manager.add_item(1, item_id, qty)
		return
	# 先尝试放入已有该物品的快捷栏格子
	for i in range(9):
		if i < inv.slots.size() and not inv.slots[i].is_empty():
			if inv.slots[i].get("item_id", "") == item_id:
				var max_stack = ItemDatabase.get_item(item_id).get("stack_max", 999)
				var space = max_stack - inv.slots[i].get("quantity", 0)
				if space > 0:
					var add = min(qty, space)
					inv.slots[i]["quantity"] = inv.slots[i].get("quantity", 0) + add
					qty -= add
					if qty <= 0:
						return
	# 找第一个空格子（优先快捷栏）
	for i in range(9):
		if i < inv.slots.size() and inv.slots[i].is_empty():
			inv.slots[i] = {"item_id": item_id, "quantity": qty, "durability": 0, "broken": false}
			return
	# 兜底用 add_item
	item_manager.add_item(1, item_id, qty)


# ========== 内部：工具查找 ==========

## 获取背包中某采集类型的最佳工具等级
func _get_best_tool_tier(harvest_type: int) -> int:
	var inv = item_manager.get_inventory(1)
	if not inv:
		return 0
	var best = 0
	for slot in inv.slots:
		if slot.is_empty():
			continue
		var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
		if item_def.get("harvest_type", -1) == harvest_type and not slot.get("broken", false):
			best = max(best, item_def.get("tool_tier", 0))
	return best


## 检查是否存在满足采集类型和最低等级的工具
func _find_best_tool(harvest_type: int, min_tier: int) -> bool:
	var inv = item_manager.get_inventory(1)
	if not inv:
		return false
	for slot in inv.slots:
		if slot.is_empty():
			continue
		var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
		if item_def.get("harvest_type", -1) == harvest_type and item_def.get("tool_tier", 0) >= min_tier and not slot.get("broken", false):
			return true
	return false


## 消耗第一个匹配工具的一点耐久
func _consume_tool_durability(harvest_type: int) -> void:
	var inv = item_manager.get_inventory(1)
	if not inv:
		return
	for i in range(inv.slots.size()):
		var slot = inv.slots[i]
		if slot.is_empty():
			continue
		var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
		if item_def.get("harvest_type", -1) == harvest_type and item_def.get("tool_tier", 0) > 0:
			item_manager.consume_durability(1, i, 1)
			return
