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
var inventory_open: bool = false
var craft_open: bool = false
var current_station: int = SharedEnums.CraftStation.HAND
var stations_unlocked: Array = [SharedEnums.CraftStation.HAND]
var hotbar_selected: int = 0

# HUD 元素
var hud: CanvasLayer = null
# 底部快捷栏
var hotbar_panel: Panel = null
var hotbar_slots: Array[Panel] = []
var hotbar_labels: Array[Label] = []
var hotbar_icons: Array[TextureRect] = []
# 背包面板（B键居中）
var inv_panel: Panel = null
var inv_grid: Array[Panel] = []
var inv_grid_labels: Array[Label] = []
var inv_grid_icons: Array[TextureRect] = []
var inv_title: Label = null
# 制造面板
var craft_panel: Panel = null
var craft_buttons: Array[Button] = []
var craft_title_label: Label = null
# 角落信息
var corner_tl: Label = null  # 左上：时间+位置
var corner_tr: Label = null  # 右上：附近资源
# 提示
var hint_label: Label = null

# 采集进度条
var harvest_bar_bg: ColorRect = null
var harvest_bar_fg: ColorRect = null

# 昼夜灯光
var light_rect: ColorRect = null

# 建造模式
var build_mode: bool = false
var selected_block_item: String = ""
var ghost_sprite: Sprite2D = null
var placed_blocks: Dictionary = {}
var build_bar: Panel = null
var build_buttons: Array[Button] = []
var build_label: Label = null


func _ready() -> void:
	rng.seed = 42
	_build_ground()
	_spawn_resources()
	_create_player()
	_setup_camera()
	_init_systems()
	_create_hud()
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


# ========== HUD ==========

func _create_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# === 底部快捷栏 ===
	var screen_w = 1920; var screen_h = 1080
	var bar_w = 480; var bar_h = 52
	hotbar_panel = Panel.new()
	hotbar_panel.position = Vector2((screen_w - bar_w) / 2, screen_h - bar_h - 4)
	hotbar_panel.size = Vector2(bar_w, bar_h)
	hotbar_panel.modulate = Color(0.08, 0.08, 0.08, 0.8)
	hud.add_child(hotbar_panel)

	for i in range(9):
		var slot = Panel.new()
		slot.position = Vector2(8 + i * 52, 5)
		slot.size = Vector2(46, 42)
		slot.modulate = Color(0.15, 0.15, 0.15, 0.9)
		hotbar_panel.add_child(slot)
		hotbar_slots.append(slot)

		var lbl = Label.new()
		lbl.position = Vector2(10 + i * 52, 5)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.size = Vector2(42, 40)
		lbl.text = ""
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hotbar_panel.add_child(lbl)
		hotbar_labels.append(lbl)

		var icon = TextureRect.new()
		icon.position = Vector2(10 + i * 52 + 3, 7)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		hotbar_panel.add_child(icon)
		hotbar_icons.append(icon)

	# 快捷栏选中高亮
	_update_hotbar_selection()

	# === 背包面板 (B键居中) ===
	var inv_w = 480; var inv_h = 360
	inv_panel = Panel.new()
	inv_panel.position = Vector2((screen_w - inv_w) / 2, (screen_h - inv_h) / 2 - 30)
	inv_panel.size = Vector2(inv_w, inv_h)
	inv_panel.modulate = Color(0.05, 0.05, 0.05, 0.92)
	inv_panel.visible = false
	hud.add_child(inv_panel)

	inv_title = Label.new()
	inv_title.text = "背包"
	inv_title.position = Vector2((screen_w - inv_w) / 2 + 16, (screen_h - inv_h) / 2 - 30 + 10)
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	inv_title.visible = false
	hud.add_child(inv_title)

	# 背包格子 5列x4行
	for row in range(4):
		for col in range(5):
			var idx = row * 5 + col
			var slot = Panel.new()
			slot.position = Vector2(16 + col * 92, 44 + row * 74)
			slot.size = Vector2(84, 68)
			slot.modulate = Color(0.15, 0.15, 0.15, 0.9)
			inv_panel.add_child(slot)
			inv_grid.append(slot)

			var lbl = Label.new()
			lbl.position = Vector2(20 + col * 92, 46 + row * 74)
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.size = Vector2(76, 64)
			lbl.text = ""
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inv_panel.add_child(lbl)
			inv_grid_labels.append(lbl)

			var icon = TextureRect.new()
			icon.position = Vector2(20 + col * 92 + 4, 48 + row * 74 + 4)
			icon.size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			inv_panel.add_child(icon)
			inv_grid_icons.append(icon)

	# === 制造面板 (C键居中) ===
	craft_panel = Panel.new()
	var cw = 420; var ch = 420
	craft_panel.position = Vector2((screen_w - cw) / 2, (screen_h - ch) / 2 - 30)
	craft_panel.size = Vector2(cw, ch)
	craft_panel.modulate = Color(0.05, 0.05, 0.05, 0.92)
	craft_panel.visible = false
	hud.add_child(craft_panel)

	craft_title_label = Label.new()
	craft_title_label.text = "制造 (手工)"
	craft_title_label.position = Vector2((screen_w - cw) / 2 + 16, (screen_h - ch) / 2 - 30 + 10)
	craft_title_label.add_theme_font_size_override("font_size", 20)
	craft_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	craft_title_label.visible = false
	hud.add_child(craft_title_label)
	_refresh_craft_buttons()

	# === 左上角：时间+位置 ===
	corner_tl = Label.new()
	corner_tl.position = Vector2(12, 10)
	corner_tl.add_theme_font_size_override("font_size", 15)
	corner_tl.add_theme_color_override("font_color", Color.WHITE)
	corner_tl.text = ""
	hud.add_child(corner_tl)

	# === 右上角：附近资源 ===
	corner_tr = Label.new()
	corner_tr.position = Vector2(screen_w - 300, 10)
	corner_tr.size = Vector2(288, 80)
	corner_tr.add_theme_font_size_override("font_size", 14)
	corner_tr.add_theme_color_override("font_color", Color.WHITE)
	corner_tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner_tr.text = ""
	hud.add_child(corner_tr)

	# === 底部提示 ===
	hint_label = Label.new()
	hint_label.position = Vector2(16, screen_h - 24)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint_label.text = "WASD移动  J采集  B背包  C制造  V建造  ESC关闭"

	# === 采集进度条 ===
	harvest_bar_bg = ColorRect.new()
	harvest_bar_bg.size = Vector2(200, 14)
	harvest_bar_bg.position = Vector2((1920 - 200) / 2, 60)
	harvest_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	harvest_bar_bg.visible = false
	hud.add_child(harvest_bar_bg)

	harvest_bar_fg = ColorRect.new()
	harvest_bar_fg.size = Vector2(0, 10)
	harvest_bar_fg.position = Vector2((1920 - 200) / 2 + 2, 62)
	harvest_bar_fg.color = Color(0.3, 0.8, 0.3)
	harvest_bar_fg.visible = false
	hud.add_child(harvest_bar_fg)
	hud.add_child(hint_label)

	# === 昼夜光效 ===
	light_rect = ColorRect.new()
	light_rect.size = Vector2(4000, 3000)
	light_rect.position = Vector2(-1000, -1000)
	light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(light_rect)

	# === 建造选择栏 ===
	build_bar = Panel.new()
	build_bar.position = Vector2(620, 8)
	build_bar.size = Vector2(220, 240)
	build_bar.modulate = Color(0.05, 0.05, 0.05, 0.85)
	build_bar.visible = false
	hud.add_child(build_bar)

	build_label = Label.new()
	build_label.text = "建造  J放置 K回收  1-9切换"
	build_label.position = Vector2(634, 14)
	build_label.add_theme_font_size_override("font_size", 12)
	build_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	build_label.visible = false
	hud.add_child(build_label)


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
	if not build_mode and not inventory_open and not craft_open:
		if Input.is_action_just_pressed("build_place"):
			_start_harvest()
		if harvesting:
			_update_harvest(delta)
	elif harvesting:
		_cancel_harvest()

	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()

	# 快捷栏选择 1-9
	for i in range(9):
		if Input.is_key_pressed(KEY_1 + i):
			hotbar_selected = i
			_update_hotbar_selection()

	# 昼夜循环
	if time_system:
		time_system._process(delta)

	# 建造模式
	if build_mode:
		_update_ghost_preview()

	_update_hud()


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
	harvest_bar_bg.visible = true
	harvest_bar_fg.visible = true


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
	harvest_bar_fg.size.x = harvest_progress * 196

	if harvest_progress >= 1.0:
		_complete_harvest()


func _cancel_harvest() -> void:
	harvesting = false
	harvest_target_id = ""
	harvest_progress = 0.0
	harvest_bar_bg.visible = false
	harvest_bar_fg.visible = false
	harvest_bar_fg.size.x = 0


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


# ========== 制造面板 ==========

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_all_panels()

	if event.is_action_pressed("craft") and not event.is_echo():
		craft_open = !craft_open
		if craft_open:
			inventory_open = false
			inv_panel.visible = false
			inv_title.visible = false
			if build_mode:
				_toggle_build_mode()
			_refresh_craft_buttons()
		else:
			_close_all_panels()
		craft_panel.visible = craft_open
		craft_title_label.visible = craft_open
		for btn in craft_buttons:
			btn.visible = craft_open

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
			hotbar_selected = keycode - KEY_1
			_update_hotbar_selection()
	# 滚轮切换快捷栏
	if not build_mode and not inventory_open and not craft_open and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			hotbar_selected = (hotbar_selected - 1) % 9
			_update_hotbar_selection()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hotbar_selected = (hotbar_selected + 1) % 9
			_update_hotbar_selection()



func _refresh_craft_buttons() -> void:
	for btn in craft_buttons:
		btn.queue_free()
	craft_buttons.clear()

	var cp = craft_panel.position
	# 制造站切换按钮
	var station_names = {SharedEnums.CraftStation.HAND: "手工", SharedEnums.CraftStation.WORKBENCH: "工作台",
		SharedEnums.CraftStation.FURNACE: "熔炉", SharedEnums.CraftStation.ANVIL: "铁砧",
		SharedEnums.CraftStation.ALCHEMY: "炼金"}
	var station_order = [SharedEnums.CraftStation.HAND, SharedEnums.CraftStation.WORKBENCH,
		SharedEnums.CraftStation.FURNACE, SharedEnums.CraftStation.ANVIL, SharedEnums.CraftStation.ALCHEMY]
	var tab_x = cp.x + 16
	for st in station_order:
		if st not in stations_unlocked:
			continue
		var tab = Button.new()
		tab.text = station_names.get(st, "?")
		tab.position = Vector2(tab_x, cp.y + 40)
		tab.size = Vector2(68, 28)
		tab.add_theme_font_size_override("font_size", 12)
		if st == current_station:
			tab.add_theme_color_override("font_color", Color.YELLOW)
			tab.disabled = true
		else:
			tab.add_theme_color_override("font_color", Color.WHITE)
		tab.pressed.connect(_on_station_changed.bind(st))
		tab.visible = craft_open
		hud.add_child(tab)
		craft_buttons.append(tab)
		tab_x += 68

	var recipes = RecipeDatabase.get_recipes_for_station(current_station)
	var inv = item_manager.get_inventory(1)
	var y_offset = cp.y + 76

	for i in range(recipes.size()):
		var recipe = recipes[i]
		var mats = recipe.get("materials", {})
		var can_craft = true
		var mat_text_parts: Array[String] = []
		for mat_id in mats:
			var need = mats[mat_id]
			var has = _count_item(mat_id)
			mat_text_parts.append("%s %d/%d" % [ItemDatabase.get_item_name(mat_id), has, need])
			if has < need:
				can_craft = false
		var mat_text = " + ".join(mat_text_parts)
		var output_name = ItemDatabase.get_item_name(recipe.get("output_item_id", ""))
		var output_qty = recipe.get("output_quantity", 1)

		var btn = Button.new()
		btn.text = "%s x%d  [%s]" % [output_name, output_qty, mat_text]
		btn.position = Vector2(cp.x + 16, y_offset)
		btn.size = Vector2(388, 30)
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = not can_craft
		if can_craft:
			btn.add_theme_color_override("font_color", Color.GREEN)
		btn.pressed.connect(_on_craft_button.bind(recipe.get("recipe_id", "")))
		btn.visible = craft_open
		hud.add_child(btn)
		craft_buttons.append(btn)
		y_offset += 34
		if y_offset > cp.y + 380:
			break


func _on_station_changed(station: int) -> void:
	current_station = station
	_refresh_craft_buttons()


func _on_craft_button(recipe_id: String) -> void:
	var result = crafting_manager.try_craft(1, recipe_id, current_station)
	if result.get("success", false):
		var recipe = RecipeDatabase.get_recipe(recipe_id)
		var output_id = recipe.get("output_item_id", "")
		_spawn_floating_text(player.position + Vector2(0, -20), "制造: %s" % ItemDatabase.get_item_name(output_id))
		# 检查是否解锁新工作站
		var item_def = ItemDatabase.get_item(output_id)
		var station_type = item_def.get("station_type", -1)
		if station_type > 0 and station_type not in stations_unlocked:
			stations_unlocked.append(station_type)
			_spawn_floating_text(player.position + Vector2(0, -40), "解锁新工作站!")
		_refresh_craft_buttons()
	else:
		_spawn_floating_text(player.position + Vector2(0, -20), "材料不足")


# ========== HUD 辅助 ==========

func _toggle_inventory() -> void:
	inventory_open = !inventory_open
	if inventory_open:
		craft_open = false
		build_mode = false
		craft_panel.visible = false
		craft_title_label.visible = false
		for btn in craft_buttons:
			btn.visible = false
		build_bar.visible = false
		build_label.visible = false
		for btn in build_buttons:
			btn.visible = false
		if ghost_sprite:
			ghost_sprite.visible = false
	inv_panel.visible = inventory_open
	inv_title.visible = inventory_open

func _set_hint(text: String) -> void:
	if hint_label:
		hint_label.text = text

func _close_all_panels() -> void:
	inventory_open = false
	craft_open = false
	build_mode = false
	inv_panel.visible = false
	inv_title.visible = false
	craft_panel.visible = false
	craft_title_label.visible = false
	for btn in craft_buttons:
		btn.visible = false
	build_bar.visible = false
	build_label.visible = false
	for btn in build_buttons:
		btn.visible = false
	if ghost_sprite:
		ghost_sprite.visible = false
	_set_hint("WASD移动 J采集 B背包 C制造 V建造")

func _update_hotbar_selection() -> void:
	for i in range(9):
		if i < hotbar_slots.size():
			if i == hotbar_selected:
				hotbar_slots[i].modulate = Color(1, 1, 1, 0.5)
			else:
				hotbar_slots[i].modulate = Color(0.15, 0.15, 0.15, 0.9)


# ========== 建造系统 ==========

func _toggle_build_mode() -> void:
	build_mode = !build_mode
	if build_mode:
		inventory_open = false
		craft_open = false
		inv_panel.visible = false
		inv_title.visible = false
		craft_panel.visible = false
		craft_title_label.visible = false
		for btn in craft_buttons:
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
		_set_hint("建造模式: J放置 K回收 1-9选方块 V退出")
		print("[Offline] 建造模式开启 — J放置 K回收 1-9选方块 V退出")
	else:
		ghost_sprite.visible = false
		build_bar.visible = false
		build_label.visible = false
		for btn in build_buttons:
			btn.visible = false
		_set_hint("WASD移动 J采集 B背包 C制造 V建造")
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
	for btn in build_buttons:
		btn.queue_free()
	build_buttons.clear()

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
		hud.add_child(btn)
		build_buttons.append(btn)
		y += 26

	build_bar.visible = build_mode
	build_label.visible = build_mode


func _select_block(item_id: String) -> void:
	selected_block_item = item_id
	_refresh_build_selection()


func _is_mouse_over_build_bar(mouse_pos: Vector2) -> bool:
	if not build_bar.visible:
		return false
	var bar_rect = Rect2(build_bar.position, build_bar.size)
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


func _count_item(item_id: String) -> int:
	var inv = item_manager.get_inventory(1)
	if not inv:
		return 0
	var total = 0
	for slot in inv.slots:
		if not slot.is_empty() and slot.get("item_id", "") == item_id:
			total += slot.get("quantity", 0)
	return total


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


# ========== HUD 更新 ==========

func _update_hud() -> void:
	var inv = item_manager.get_inventory(1)

	# === 左上角：位置+时间 ===
	var pos_text = "(%d, %d)" % [int(player.position.x / TILE_SIZE), int(player.position.y / TILE_SIZE)]
	if time_system:
		var h = int(time_system.get_game_hour()) % 24
		var phase_names = {0: "清晨", 1: "白天", 2: "黄昏", 3: "夜晚"}
		var phase = phase_names.get(time_system.current_phase, "?")
		var build_status = " | [建造中]" if build_mode else ""
		corner_tl.text = "第%d天 %02d:00 %s | %s%s" % [time_system.day_number, h, phase, pos_text, build_status]
		if light_rect:
			var light = time_system.get_light_multiplier()
			light_rect.color = Color(0, 0, 0.1, (1.0 - light) * 0.5)

	# === 右上角：附近资源 ===
	var nearby = {}
	for rid in resource_sprites:
		if resource_data.get(rid, {}).get("depleted", false):
			continue
		var dist = player.position.distance_to(resource_sprites[rid].position)
		if dist < 80:
			var name = resource_data[rid].get("name", "?")
			nearby[name] = nearby.get(name, 0) + 1
	if nearby.is_empty():
		corner_tr.text = ""
	else:
		var parts: Array[String] = []
		for n in nearby:
			parts.append("%s x%d" % [n, nearby[n]])
		corner_tr.text = "\n".join(parts)

	# === 底部快捷栏 ===
	if inv:
		for i in range(9):
			if i < inv.slots.size() and not inv.slots[i].is_empty():
				var slot = inv.slots[i]
				var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
				var name = item_def.get("name", slot.get("item_id", ""))
				var qty = slot.get("quantity", 0)
				hotbar_labels[i].text = "%s\n%d" % [name, qty]
				if i < hotbar_icons.size():
					hotbar_icons[i].texture = TextureGen.get_item_icon(slot.get("item_id", ""))
			else:
				hotbar_labels[i].text = ""
				if i < hotbar_icons.size():
					hotbar_icons[i].texture = null

	# === 背包面板 ===
	if inventory_open and inv:
		for i in range(20):
			if i < inv.slots.size() and not inv.slots[i].is_empty():
				var slot = inv.slots[i]
				var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
				var name = item_def.get("name", slot.get("item_id", ""))
				var qty = slot.get("quantity", 0)
				var dur = slot.get("durability", 0)
				var dur_text = " (耐久:%d)" % dur if dur > 0 else ""
				inv_grid_labels[i].text = "%s\nx%d%s" % [name, qty, dur_text]
				inv_grid[i].modulate = Color(0.2, 0.2, 0.2, 0.9) if i == hotbar_selected else Color(0.15, 0.15, 0.15, 0.9)
				if i < inv_grid_icons.size():
					inv_grid_icons[i].texture = TextureGen.get_item_icon(slot.get("item_id", ""))
			else:
				inv_grid_labels[i].text = ""
				inv_grid[i].modulate = Color(0.15, 0.15, 0.15, 0.9)
				if i < inv_grid_icons.size():
					inv_grid_icons[i].texture = null
