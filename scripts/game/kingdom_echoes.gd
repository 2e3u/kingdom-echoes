extends Node2D
class_name OfflineGame

## 离线单机模式 — 完整游戏循环（无需服务端）
## 包含：地形、资源采集、背包、制造、昼夜循环

const WORLD_TILES_X: int = 80
const WORLD_TILES_Y: int = 60
const TILE_SIZE: int = 32

var player: CharacterBody2D = null
var player_sprite: Sprite2D = null
var camera: Camera2D = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# 资源节点
var resource_sprites: Dictionary = {}
var resource_data: Dictionary = {}

# 游戏子系统
var item_manager: ItemManager = null
var crafting_manager: CraftingManager = null
var time_system: TimeSystem = null

# 输入状态
var harvesting: bool = false
var harvest_target_id: String = ""
var harvest_progress: float = 0.0
var harvest_duration: float = 1.5
var stations_unlocked: Array = [SharedEnums.CraftStation.HAND]

# HUD 控制器
var hud_controller: HUDController = null

# 建造模式
var build_mode: bool = false
var selected_block_item: String = ""
var ghost_sprite: Sprite2D = null
var placed_blocks: Dictionary = {}


func _ready() -> void:
	rng.seed = 42
	_build_ground()
	_spawn_resources()
	_create_player()
	_setup_camera()
	_init_systems()

	# 创建 HUD CanvasLayer
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# 创建并初始化 HUDController
	hud_controller = HUDController.new()
	hud_controller.setup(hud, item_manager, player, time_system, resource_sprites, resource_data, crafting_manager, stations_unlocked, _spawn_floating_text)
	hud_controller.create()

	print("[Offline] 离线模式已启动 — WASD移动 J采集 B背包 C制造 V建造")


# ========== 地形 ==========

func _build_ground() -> void:
	var tm = TileMap.new()
	tm.name = "Ground"
	tm.tile_set = TextureGen.make_tileset()
	for x in range(-10, WORLD_TILES_X + 10):
		for y in range(-10, WORLD_TILES_Y + 10):
			var biome = int((sin(x * 0.12) * cos(y * 0.1) + 1.0) * 1.5)
			tm.set_cell(0, Vector2i(x, y), biome, Vector2i(0, 0))
	add_child(tm)


# ========== 资源生成 ==========

func _spawn_resources() -> void:
	var defs = [
		{"id": "tree", "item": "wood", "qty": 3, "color": Color.SADDLE_BROWN, "count": 200, "size": 22, "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE},
		{"id": "copper_ore", "item": "copper_ore", "qty": 2, "color": Color(0.8, 0.5, 0.2), "count": 80, "size": 14, "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.WOOD},
		{"id": "iron_ore", "item": "iron_ore", "qty": 2, "color": Color(0.5, 0.5, 0.55), "count": 100, "size": 16, "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.STONE},
		{"id": "stone_node", "item": "stone", "qty": 3, "color": Color.DIM_GRAY, "count": 50, "size": 16, "harvest_type": -1, "tool_tier": SharedEnums.ToolTier.NONE},
		{"id": "herb_red", "item": "herb_red", "qty": 2, "color": Color(0.85, 0.2, 0.35), "count": 120, "size": 10, "harvest_type": SharedEnums.HarvestType.HERB, "tool_tier": SharedEnums.ToolTier.NONE},
		{"id": "fiber_plant", "item": "fiber", "qty": 2, "color": Color(0.2, 0.75, 0.25), "count": 140, "size": 12, "harvest_type": SharedEnums.HarvestType.FIBER, "tool_tier": SharedEnums.ToolTier.NONE},
	]
	var res_layer = Node2D.new()
	res_layer.name = "Resources"
	add_child(res_layer)

	for d in defs:
		var tex: ImageTexture = null
		match d.id:
			"tree": tex = TextureGen.get_tree_texture()
			"stone_node": tex = TextureGen.get_stone_texture()
			"copper_ore": tex = TextureGen.get_ore_texture(Color(0.72, 0.42, 0.18), Color(0.95, 0.65, 0.2))
			"iron_ore": tex = TextureGen.get_ore_texture(Color(0.45, 0.42, 0.48), Color(0.65, 0.62, 0.7))
			"herb_red": tex = TextureGen.get_herb_texture()
			"fiber_plant": tex = TextureGen.get_fiber_texture()
		for _i in range(d.count):
			var pos = Vector2(
				rng.randf_range(4, WORLD_TILES_X - 4) * TILE_SIZE,
				rng.randf_range(4, WORLD_TILES_Y - 4) * TILE_SIZE,
			)
			var id = "%s_%d" % [d.id, resource_sprites.size()]
			var sprite = Sprite2D.new()
			sprite.position = pos
			sprite.centered = true
			sprite.texture = tex
			sprite.z_index = 2 if d.id == "tree" else 1
			res_layer.add_child(sprite)
			resource_sprites[id] = sprite
			resource_data[id] = {"name": ItemDatabase.get_item_name(d.item), "item_id": d.item, "quantity": d.qty, "harvest_type": d.harvest_type, "tool_tier": d.tool_tier, "depleted": false}


# ========== 玩家 ==========

func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(WORLD_TILES_X / 2.0 * TILE_SIZE, WORLD_TILES_Y / 2.0 * TILE_SIZE)

	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = 14.0
	player.add_child(col)

	player_sprite = Sprite2D.new()
	player_sprite.name = "Sprite"
	player_sprite.centered = true
	player_sprite.texture = TextureGen.get_player_texture()
	player_sprite.z_index = 5
	player.add_child(player_sprite)

	var name_label = Label.new()
	name_label.text = "玩家"
	name_label.position = Vector2(-20, -22)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	player.add_child(name_label)
	add_child(player)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.zoom = Vector2(2.5, 2.5)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


# ========== 子系统 ==========

func _init_systems() -> void:
	# 背包
	item_manager = ItemManager.new()
	item_manager.name = "ItemManager"
	item_manager.initialize_player_inventory(1)
	add_child(item_manager)

	# 制造
	crafting_manager = CraftingManager.new()
	crafting_manager.name = "CraftingManager"
	crafting_manager.item_manager = item_manager
	add_child(crafting_manager)

	# 昼夜循环
	time_system = TimeSystem.new()
	time_system.name = "TimeSystem"
	add_child(time_system)


# ========== 帧循环 ==========

var move_speed: float = 300.0

func _process(delta: float) -> void:
	if not player:
		return

	# 移动
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"): dir.y -= 1
	if Input.is_action_pressed("move_down"): dir.y += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	if dir.length() > 0:
		dir = dir.normalized()
	player.position += dir * move_speed * delta
	player.position.x = clamp(player.position.x, 64, (WORLD_TILES_X - 2) * TILE_SIZE)
	player.position.y = clamp(player.position.y, 64, (WORLD_TILES_Y - 2) * TILE_SIZE)

	if camera:
		camera.position = player.position

	# 采集：J键按住采集（非建造模式）
	if not build_mode and not hud_controller.inventory_open and not hud_controller.craft_open:
		if Input.is_action_just_pressed("build_place"):
			_start_harvest()
		if harvesting:
			_update_harvest(delta)
	elif harvesting:
		_cancel_harvest()

	if Input.is_action_just_pressed("inventory"):
		hud_controller.toggle_inventory()
		if hud_controller.inventory_open and build_mode:
			build_mode = false
			if ghost_sprite:
				ghost_sprite.visible = false

	# 快捷栏选择 1-9
	for i in range(9):
		if Input.is_key_pressed(KEY_1 + i):
			hud_controller.hotbar_selected = i
			hud_controller.update_hotbar_selection()

	# 昼夜循环
	if time_system:
		time_system._process(delta)

	# 建造模式
	if build_mode:
		_update_ghost_preview()

	# HUD 更新 — 轻量部分每帧，图标纹理仅在脏标记为 true 时刷新
	hud_controller.update(build_mode)
	if hud_controller.inventory_dirty:
		hud_controller.refresh_slots()


# ========== 采集 ==========

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


func _start_harvest() -> void:
	var rid = _find_nearest_resource()
	if rid.is_empty():
		return
	var res = resource_data[rid]
	var required_tier = res.get("tool_tier", 0)
	var harvest_type = res.get("harvest_type", -1)

	# 检查工具
	var tool_tier = 0
	if required_tier > SharedEnums.ToolTier.NONE:
		tool_tier = _get_best_tool_tier(harvest_type)
		if tool_tier < required_tier:
			var tier_names = {1: "木", 2: "石", 3: "铜", 4: "铁", 5: "秘银"}
			_spawn_floating_text(player.position + Vector2(0, -20), "需要%s质工具!" % tier_names.get(required_tier, "?"))
			return

	# 计算采集时间：基础1.5秒，工具越好越快
	var speed_mult = float(required_tier + 1) / float(max(tool_tier, 0) + 1)
	harvest_duration = 1.5 * speed_mult
	harvest_target_id = rid
	harvest_progress = 0.0
	harvesting = true
	hud_controller.show_harvest_bar(true)


func _update_harvest(delta: float) -> void:
	if not Input.is_action_pressed("build_place"):
		_cancel_harvest()
		return

	# 检查目标是否仍在范围内
	var rid = harvest_target_id
	if rid.is_empty() or not resource_sprites.has(rid) or resource_data.get(rid, {}).get("depleted", false):
		_cancel_harvest()
		return
	var dist = player.position.distance_to(resource_sprites[rid].position)
	if dist > 60:
		_cancel_harvest()
		return

	harvest_progress += delta / harvest_duration
	hud_controller.update_harvest_bar(harvest_progress)

	if harvest_progress >= 1.0:
		_complete_harvest()


func _cancel_harvest() -> void:
	harvesting = false
	harvest_target_id = ""
	harvest_progress = 0.0
	hud_controller.show_harvest_bar(false)


func _complete_harvest() -> void:
	var rid = harvest_target_id
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
	_spawn_floating_text(sprite.position, "+%d %s" % [qty, res.get("name", item_id)])

	# 不重生 — 资源一次性采集

	_cancel_harvest()


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


# ========== 输入处理 ==========

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hud_controller.close_all()
		if build_mode:
			_toggle_build_mode()

	if event.is_action_pressed("craft") and not event.is_echo():
		var was_open = hud_controller.craft_open
		if not was_open and build_mode:
			_toggle_build_mode()
		hud_controller.toggle_craft()
		if was_open and build_mode:
			_toggle_build_mode()

	if event.is_action_pressed("build") and not event.is_echo():
		_toggle_build_mode()

	# 建造模式下滚轮 / 鼠标 / J / K
	if build_mode and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_block_selection(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not _is_mouse_over_build_bar(mb.position):
				_try_place_block()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _is_mouse_over_build_bar(mb.position):
				_try_remove_block()

	if build_mode and event.is_action_pressed("build_place") and not event.is_echo():
		_try_place_block()
	if build_mode and event.is_action_pressed("build_remove") and not event.is_echo():
		_try_remove_block()

	# 建造模式数字键选方块
	if build_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var keycode = (event as InputEventKey).keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			var idx = keycode - KEY_1
			var blocks = _get_available_blocks()
			if idx < blocks.size():
				selected_block_item = blocks[idx].item_id
				_refresh_build_selection()

	# 非建造模式数字键选快捷栏
	if not build_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var keycode = (event as InputEventKey).keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			hud_controller.hotbar_selected = keycode - KEY_1
			hud_controller.update_hotbar_selection()
	# 滚轮切换快捷栏
	if not build_mode and not hud_controller.inventory_open and not hud_controller.craft_open and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			hud_controller.hotbar_selected = (hud_controller.hotbar_selected - 1) % 9
			hud_controller.update_hotbar_selection()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hud_controller.hotbar_selected = (hud_controller.hotbar_selected + 1) % 9
			hud_controller.update_hotbar_selection()



# ========== 建造系统 ==========

func _toggle_build_mode() -> void:
	build_mode = !build_mode
	if build_mode:
		hud_controller.inventory_open = false
		hud_controller.craft_open = false
		hud_controller.inv_panel.visible = false
		hud_controller.inv_title.visible = false
		hud_controller.craft_panel.visible = false
		hud_controller.craft_title_label.visible = false
		for btn in hud_controller.craft_buttons:
			btn.visible = false
		if not ghost_sprite:
			ghost_sprite = Sprite2D.new()
			ghost_sprite.name = "BuildGhost"
			ghost_sprite.centered = true
			ghost_sprite.z_index = 100
			ghost_sprite.modulate = Color(1, 1, 1, 0.55)
			add_child(ghost_sprite)
		_refresh_build_selection()
		ghost_sprite.visible = true
		_spawn_floating_text(player.position + Vector2(0, -30), "[建造模式] J放置 K回收")
		hud_controller.set_hint("建造模式: J放置 K回收 1-9选方块 V退出")
		print("[Offline] 建造模式开启 — J放置 K回收 1-9选方块 V退出")
	else:
		ghost_sprite.visible = false
		hud_controller.build_bar.visible = false
		hud_controller.build_label.visible = false
		for btn in hud_controller.build_buttons:
			btn.visible = false
		hud_controller.set_hint("WASD移动 J采集 B背包 C制造 V建造")
		print("[Offline] 建造模式关闭")


func _get_available_blocks() -> Array:
	var inv = item_manager.get_inventory(1)
	if not inv:
		return []
	var blocks: Array = []
	var seen: Dictionary = {}
	for slot in inv.slots:
		if slot.is_empty():
			continue
		var item_id = slot.get("item_id", "")
		if seen.has(item_id):
			continue
		var item_def = ItemDatabase.get_item(item_id)
		if item_def.has("block_type") and slot.get("quantity", 0) > 0:
			blocks.append({"item_id": item_id, "name": item_def.get("name", item_id), "block_type": item_def.get("block_type", 0)})
			seen[item_id] = true
	return blocks


func _refresh_build_selection() -> void:
	for btn in hud_controller.build_buttons:
		btn.queue_free()
	hud_controller.build_buttons.clear()

	var blocks = _get_available_blocks()
	if blocks.is_empty():
		selected_block_item = ""
		return

	if selected_block_item.is_empty() or not blocks.any(func(b): return b.item_id == selected_block_item):
		selected_block_item = blocks[0].item_id

	var y = 38
	for b in blocks:
		var btn = Button.new()
		btn.text = b.name
		btn.position = Vector2(614, y)
		btn.size = Vector2(172, 22)
		btn.add_theme_font_size_override("font_size", 10)
		if b.item_id == selected_block_item:
			btn.add_theme_color_override("font_color", Color.YELLOW)
			btn.disabled = true
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
		btn.pressed.connect(_select_block.bind(b.item_id))
		btn.visible = build_mode
		hud_controller.hud.add_child(btn)
		hud_controller.build_buttons.append(btn)
		y += 26

	hud_controller.build_bar.visible = build_mode
	hud_controller.build_label.visible = build_mode


func _select_block(item_id: String) -> void:
	selected_block_item = item_id
	_refresh_build_selection()


func _is_mouse_over_build_bar(mouse_pos: Vector2) -> bool:
	if not hud_controller.build_bar.visible:
		return false
	var bar_rect = Rect2(hud_controller.build_bar.position, hud_controller.build_bar.size)
	return bar_rect.has_point(mouse_pos)


func _cycle_block_selection(direction: int) -> void:
	var blocks = _get_available_blocks()
	if blocks.is_empty():
		return
	var idx = -1
	for i in range(blocks.size()):
		if blocks[i].item_id == selected_block_item:
			idx = i
			break
	idx = (idx + direction) % blocks.size()
	selected_block_item = blocks[idx].item_id
	_refresh_build_selection()


func _update_ghost_preview() -> void:
	if not ghost_sprite or selected_block_item.is_empty():
		return
	var mouse_pos = get_global_mouse_position()
	var grid_pos = (mouse_pos / TILE_SIZE).floor() * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	# 限制在世界范围内
	grid_pos.x = clamp(grid_pos.x, TILE_SIZE, (WORLD_TILES_X - 1) * TILE_SIZE)
	grid_pos.y = clamp(grid_pos.y, TILE_SIZE, (WORLD_TILES_Y - 1) * TILE_SIZE)
	ghost_sprite.position = grid_pos

	var img = TextureGen.get_block_texture(selected_block_item).get_image()
	ghost_sprite.texture = ImageTexture.create_from_image(img)

	# 检查是否被占用
	var grid_key = "%d_%d" % [int(grid_pos.x), int(grid_pos.y)]
	if placed_blocks.has(grid_key):
		ghost_sprite.modulate = Color(1, 0.3, 0.3, 0.55)
	else:
		ghost_sprite.modulate = Color(1, 1, 1, 0.55)


func _try_place_block() -> void:
	if selected_block_item.is_empty():
		return
	var grid_pos: Vector2
	if ghost_sprite and ghost_sprite.visible:
		grid_pos = ghost_sprite.position
	else:
		var mouse_pos = get_global_mouse_position()
		grid_pos = (mouse_pos / TILE_SIZE).floor() * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	grid_pos.x = clamp(grid_pos.x, TILE_SIZE, (WORLD_TILES_X - 1) * TILE_SIZE)
	grid_pos.y = clamp(grid_pos.y, TILE_SIZE, (WORLD_TILES_Y - 1) * TILE_SIZE)

	var grid_key = "%d_%d" % [int(grid_pos.x), int(grid_pos.y)]
	if placed_blocks.has(grid_key):
		return

	var inv = item_manager.get_inventory(1)
	if not inv:
		return
	if not item_manager.remove_item(1, selected_block_item, 1):
		_spawn_floating_text(player.position + Vector2(0, -20), "缺少方块!")
		return

	var item_def = ItemDatabase.get_item(selected_block_item)
	var block_type = item_def.get("block_type", 0)
	var sprite = Sprite2D.new()
	sprite.name = "Block_%s" % grid_key
	sprite.position = grid_pos
	sprite.centered = true
	sprite.z_index = 1
	sprite.texture = TextureGen.get_block_texture(selected_block_item)
	add_child(sprite)
	placed_blocks[grid_key] = {"item_id": selected_block_item, "sprite": sprite}

	# 工作站解锁对应制造站
	if block_type == SharedEnums.BlockType.WORKSTATION:
		var station_type = item_def.get("station_type", -1)
		if station_type > 0 and station_type not in stations_unlocked:
			stations_unlocked.append(station_type)
			_spawn_floating_text(grid_pos + Vector2(0, -20), "解锁工作站!")

	_spawn_floating_text(grid_pos + Vector2(0, -16), "放置: %s" % item_def.get("name", selected_block_item))
	_refresh_build_selection()


func _try_remove_block() -> void:
	var grid_pos: Vector2
	if ghost_sprite and ghost_sprite.visible:
		grid_pos = ghost_sprite.position
	else:
		var mouse_pos = get_global_mouse_position()
		grid_pos = (mouse_pos / TILE_SIZE).floor() * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	var grid_key = "%d_%d" % [int(grid_pos.x), int(grid_pos.y)]
	if not placed_blocks.has(grid_key):
		return
	var block_info = placed_blocks[grid_key]
	var sprite: Sprite2D = block_info.sprite
	if is_instance_valid(sprite):
		sprite.queue_free()
	_spawn_floating_text(grid_pos + Vector2(0, -16), "回收: %s" % ItemDatabase.get_item_name(block_info.item_id))
	item_manager.add_item(1, block_info.item_id, 1)
	placed_blocks.erase(grid_key)
	_refresh_build_selection()


# ========== 浮字 ==========

func _spawn_floating_text(pos: Vector2, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-30, -10)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	add_child(lbl)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 30, 0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)
