extends Node2D
class_name OfflineGame

## 离线单机模式 — 完整游戏循环（无需服务端）
## 包含：地形、资源采集、背包、制造、昼夜循环

const WORLD_TILES_X: int = 100
const WORLD_TILES_Y: int = 75
const TILE_SIZE: int = 48

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

# 世界生成器
var world_generator: WorldGenerator = null


func _ready() -> void:
	rng.seed = 42

	# 配置群落（对应 atlas PNG 路径 — 顺序必须匹配 BIOME_IDS）
	var biome_configs: Array[Dictionary] = []
	for biome_id in WorldGenerator.BIOME_IDS:
		biome_configs.append({
			"id": biome_id,
			"atlas_path": "res://assets/sprites/atlas_%s.png" % biome_id,
			"variant_count": 9,
		})

	# 配置资源（按群落分布 + 密度）
	var resource_defs: Array[Dictionary] = [
		{"id": "tree", "item": "wood", "qty": 3, "name": "树",
		 "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["forest_floor", "grass"], "density": 0.016, "z_index": 2,
		 "texture": TextureGen.get_tree_texture()},
		{"id": "copper_ore", "item": "copper_ore", "qty": 2, "name": "铜矿",
		 "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.WOOD,
		 "biomes": ["stone_path", "sand"], "density": 0.004, "z_index": 1,
		 "texture": TextureGen.get_ore_texture(Color(0.72, 0.42, 0.18), Color(0.95, 0.65, 0.2))},
		{"id": "iron_ore", "item": "iron_ore", "qty": 2, "name": "铁矿",
		 "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.STONE,
		 "biomes": ["stone_path", "dirt"], "density": 0.005, "z_index": 1,
		 "texture": TextureGen.get_ore_texture(Color(0.45, 0.42, 0.48), Color(0.65, 0.62, 0.7))},
		{"id": "stone_node", "item": "stone", "qty": 3, "name": "石头",
		 "harvest_type": -1, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["dirt", "stone_path"], "density": 0.008, "z_index": 1,
		 "texture": TextureGen.get_stone_texture()},
		{"id": "herb_red", "item": "herb_red", "qty": 2, "name": "药草",
		 "harvest_type": SharedEnums.HarvestType.HERB, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["grass", "swamp", "forest_floor"], "density": 0.010, "z_index": 1,
		 "texture": TextureGen.get_herb_texture()},
		{"id": "fiber_plant", "item": "fiber", "qty": 2, "name": "纤维植物",
		 "harvest_type": SharedEnums.HarvestType.FIBER, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["grass", "swamp"], "density": 0.008, "z_index": 1,
		 "texture": TextureGen.get_fiber_texture()},
	]

	# 装饰物（等待 Task 5 ComfyUI 生成）
	var decoration_defs: Array[Dictionary] = _build_decoration_defs()

	# 创建 WorldGenerator 并生成世界
	world_generator = WorldGenerator.new()
	world_generator.setup(rng, TILE_SIZE, WORLD_TILES_X, WORLD_TILES_Y)
	world_generator.set_biome_configs(biome_configs)
	world_generator.set_resource_defs(resource_defs)
	world_generator.set_decoration_defs(decoration_defs)
	world_generator.generate(self)

	# 从 WorldGenerator 获取资源引用
	resource_sprites = world_generator.resource_sprites
	resource_data = world_generator.resource_data

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
	var next_pos = player.position + dir * move_speed * delta
	next_pos.x = clamp(next_pos.x, 64, (WORLD_TILES_X - 2) * TILE_SIZE)
	next_pos.y = clamp(next_pos.y, 64, (WORLD_TILES_Y - 2) * TILE_SIZE)

	# 水域阻挡
	var target_gx = int(next_pos.x / TILE_SIZE)
	var target_gy = int(next_pos.y / TILE_SIZE)
	if world_generator and world_generator.get_biome_at(target_gx, target_gy) != "water":
		player.position = next_pos

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
			build_controller.toggle()

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
		var was_build = build_controller.build_mode
		if not was_open and was_build:
			build_controller.toggle()
		hud_controller.toggle_craft()
		if was_open and was_build:
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
				build_controller.select_block(blocks[idx].item_id)

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




# ========== 装饰物辅助 ==========

func _build_decoration_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	var deco_specs = [
		{"id": "flower", "biomes": ["grass", "forest_floor"], "density": 0.02, "z_index": 2},
		{"id": "grass_tuft", "biomes": ["grass", "dirt", "swamp"], "density": 0.03, "z_index": 2},
		{"id": "mushroom", "biomes": ["forest_floor", "swamp"], "density": 0.01, "z_index": 2},
		{"id": "pebble", "biomes": ["dirt", "stone_path", "sand"], "density": 0.04, "z_index": 1},
		{"id": "rock_small", "biomes": ["stone_path", "dirt"], "density": 0.015, "z_index": 1},
		{"id": "bush_small", "biomes": ["grass", "forest_floor"], "density": 0.015, "z_index": 3},
		{"id": "berry_bush", "biomes": ["forest_floor", "swamp"], "density": 0.012, "z_index": 3},
		{"id": "leaf_pile", "biomes": ["forest_floor"], "density": 0.025, "z_index": 1},
		{"id": "twig", "biomes": ["forest_floor", "grass", "swamp"], "density": 0.025, "z_index": 1},
	]
	for spec in deco_specs:
		var tex = _load_deco_texture("deco_%s.png" % spec["id"])
		if tex:
			defs.append({
				"id": spec["id"],
				"biomes": spec["biomes"],
				"density": spec["density"],
				"z_index": spec["z_index"],
				"texture": tex,
			})
	return defs


func _load_deco_texture(path: String) -> ImageTexture:
	var full = "res://assets/sprites/%s" % path
	if not FileAccess.file_exists(full):
		return null
	var img = Image.load_from_file(full)
	if img == null or img.is_empty():
		return null
	var tex = ImageTexture.create_from_image(img)
	return tex


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
