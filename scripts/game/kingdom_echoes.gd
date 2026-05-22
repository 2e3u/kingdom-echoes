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
var stations_unlocked: Array = [SharedEnums.CraftStation.HAND]

# HUD 控制器
var hud_controller: HUDController = null

# 采集控制器
var harvest_controller: HarvestController = null

# 建造控制器
var build_controller: BuildController = null


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

	# 创建并初始化 HarvestController
	harvest_controller = HarvestController.new()
	harvest_controller.setup(player, resource_sprites, resource_data, item_manager, hud_controller, _spawn_floating_text)
	harvest_controller.harvest_completed.connect(_on_harvest_completed)

	# 创建并初始化 BuildController
	build_controller = BuildController.new()
	build_controller.setup(player, item_manager, hud_controller, self, stations_unlocked, _spawn_floating_text,
		{"TILE_SIZE": TILE_SIZE, "WORLD_TILES_X": WORLD_TILES_X, "WORLD_TILES_Y": WORLD_TILES_Y})

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

	# 采集
	if not build_controller.build_mode and not hud_controller.inventory_open and not hud_controller.craft_open:
		if Input.is_action_just_pressed("build_place"):
			harvest_controller.try_harvest()
		if harvest_controller.is_harvesting():
			harvest_controller.update(delta)
	elif harvest_controller.is_harvesting():
		harvest_controller.cancel()

	if Input.is_action_just_pressed("inventory"):
		hud_controller.toggle_inventory()
		if hud_controller.inventory_open and build_controller.build_mode:
			build_controller.build_mode = false
			if build_controller.ghost_sprite:
				build_controller.ghost_sprite.visible = false

	# 快捷栏选择 1-9
	for i in range(9):
		if Input.is_key_pressed(KEY_1 + i):
			hud_controller.hotbar_selected = i
			hud_controller.update_hotbar_selection()

	# 昼夜循环
	if time_system:
		time_system._process(delta)

	# 建造预览
	if build_controller.build_mode:
		build_controller.update_preview()

	# HUD 更新 — 轻量部分每帧，图标纹理仅在脏标记为 true 时刷新
	hud_controller.update(build_controller.build_mode)
	if hud_controller.inventory_dirty:
		hud_controller.refresh_slots()


# ========== 采集回调 ==========

func _on_harvest_completed(item_id: String, qty: int) -> void:
	hud_controller.mark_dirty()

# ========== 输入处理 ==========

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hud_controller.close_all()
		if build_controller.build_mode:
			build_controller.toggle()

	if event.is_action_pressed("craft") and not event.is_echo():
		var was_open = hud_controller.craft_open
		if not was_open and build_controller.build_mode:
			build_controller.toggle()
		hud_controller.toggle_craft()
		if was_open and build_controller.build_mode:
			build_controller.toggle()

	if event.is_action_pressed("build") and not event.is_echo():
		build_controller.toggle()

	# 建造模式下滚轮 / 鼠标 / J / K
	if build_controller.build_mode and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			build_controller.cycle_selection(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not build_controller._is_mouse_over_build_bar(mb.position):
				build_controller.try_place()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not build_controller._is_mouse_over_build_bar(mb.position):
				build_controller.try_remove()

	if build_controller.build_mode and event.is_action_pressed("build_place") and not event.is_echo():
		build_controller.try_place()
	if build_controller.build_mode and event.is_action_pressed("build_remove") and not event.is_echo():
		build_controller.try_remove()

	# 建造模式数字键选方块
	if build_controller.build_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var keycode = (event as InputEventKey).keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			var idx = keycode - KEY_1
			var blocks = build_controller.get_available_blocks()
			if idx < blocks.size():
				build_controller.selected_block_item = blocks[idx].item_id
				build_controller._refresh_selection()

	# 非建造模式数字键选快捷栏
	if not build_controller.build_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var keycode = (event as InputEventKey).keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			hud_controller.hotbar_selected = keycode - KEY_1
			hud_controller.update_hotbar_selection()
	# 滚轮切换快捷栏
	if not build_controller.build_mode and not hud_controller.inventory_open and not hud_controller.craft_open and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			hud_controller.hotbar_selected = (hud_controller.hotbar_selected - 1) % 9
			hud_controller.update_hotbar_selection()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hud_controller.hotbar_selected = (hud_controller.hotbar_selected + 1) % 9
			hud_controller.update_hotbar_selection()




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
