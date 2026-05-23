extends Node2D
class_name OfflineGame

## 离线单机模式 — 无限 chunk 世界 + 资源采集 + 背包 + 制造 + 昼夜循环

const TILE_SIZE: int = 64
const CHUNK_VIEW_RADIUS: int = 3  # 玩家周围 7×7 chunk

var player: CharacterBody2D = null
var player_sprite: Sprite2D = null
var camera: Camera2D = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var terrain_root: Node2D = null
var object_root: Node2D = null

# 资源节点（引用 WorldGenerator 内部字典）
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

# Chunk 追踪
var _last_chunk: Vector2i = Vector2i(999999, 999999)
var _loaded_chunks: Array[Vector2i] = []


func _ready() -> void:
	rng.seed = 42
	_create_world_layers()

	# 配置群落（顺序必须匹配 BIOME_IDS）
	# Gemini 生成的纹理优先；缺失的 fallback 到 grass
	var biome_configs: Array[Dictionary] = []
	var gemini_grass = "res://scripts/game/草坪.png"  # Gemini 生成的草地
	for biome_id in WorldGenerator.BIOME_IDS:
		var path = "res://scripts/game/atlas_%s.png" % biome_id
		var variant_count = 16
		var source_rect = Rect2i()
		if not FileAccess.file_exists(path):
			path = gemini_grass if FileAccess.file_exists(gemini_grass) else ""
			variant_count = 1
			source_rect = Rect2i(32, 32, TILE_SIZE, TILE_SIZE)
		biome_configs.append({
			"id": biome_id,
			"atlas_path": path,
			"variant_count": variant_count,
			"source_rect": source_rect,
		})

	# 配置资源
	var resource_defs: Array[Dictionary] = [
		{"id": "tree", "item": "wood", "qty": 3, "name": "树",
		 "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["forest_floor", "grass"], "density": 0.016, "z_index": 2, "scale": 1.5,
		 "texture": TextureGen.get_tree_texture()},
		{"id": "copper_ore", "item": "copper_ore", "qty": 2, "name": "铜矿",
		 "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.WOOD,
		 "biomes": ["stone_path", "sand"], "density": 0.004, "z_index": 1, "scale": 1.5,
		 "texture": TextureGen.get_ore_texture(Color(0.72, 0.42, 0.18), Color(0.95, 0.65, 0.2))},
		{"id": "iron_ore", "item": "iron_ore", "qty": 2, "name": "铁矿",
		 "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.STONE,
		 "biomes": ["stone_path", "dirt"], "density": 0.005, "z_index": 1, "scale": 1.5,
		 "texture": TextureGen.get_ore_texture(Color(0.45, 0.42, 0.48), Color(0.65, 0.62, 0.7))},
		{"id": "stone_node", "item": "stone", "qty": 3, "name": "石头",
		 "harvest_type": -1, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["dirt", "stone_path"], "density": 0.008, "z_index": 1, "scale": 1.5,
		 "texture": TextureGen.get_stone_texture()},
		{"id": "herb_red", "item": "herb_red", "qty": 2, "name": "药草",
		 "harvest_type": SharedEnums.HarvestType.HERB, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["grass", "swamp", "forest_floor"], "density": 0.010, "z_index": 1, "scale": 1.5,
		 "texture": TextureGen.get_herb_texture()},
		{"id": "fiber_plant", "item": "fiber", "qty": 2, "name": "纤维植物",
		 "harvest_type": SharedEnums.HarvestType.FIBER, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["grass", "swamp"], "density": 0.008, "z_index": 1, "scale": 1.5,
		 "texture": TextureGen.get_fiber_texture()},
	]

	var decoration_defs: Array[Dictionary] = _build_decoration_defs()

	# 创建 WorldGenerator
	world_generator = WorldGenerator.new()
	world_generator.setup(rng, TILE_SIZE)
	world_generator.set_biome_configs(biome_configs)
	world_generator.set_resource_defs(resource_defs)
	world_generator.set_decoration_defs(decoration_defs)
	world_generator.init_chunks(terrain_root, object_root)

	# 引用 WorldGenerator 内部字典（共享引用）
	resource_sprites = world_generator.resource_sprites
	resource_data = world_generator.resource_data

	_create_player()
	_setup_camera()
	_init_systems()

	# 初始加载玩家周围的 chunk
	var start_chunk = WorldGenerator.world_position_to_chunk(player.position, TILE_SIZE)
	_update_chunks(start_chunk.x, start_chunk.y)

	# HUD
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	hud_controller = HUDController.new()
	hud_controller.setup(hud, item_manager, player, time_system, resource_sprites, resource_data, crafting_manager, stations_unlocked, _spawn_floating_text)
	hud_controller.create()

	harvest_controller = HarvestController.new()
	harvest_controller.setup(player, resource_sprites, resource_data, item_manager, hud_controller, _spawn_floating_text)
	harvest_controller.harvest_completed.connect(_on_harvest_completed)

	build_controller = BuildController.new()
	build_controller.setup(player, item_manager, hud_controller, object_root, stations_unlocked, _spawn_floating_text,
		{"TILE_SIZE": TILE_SIZE, "WORLD_TILES_X": 99999, "WORLD_TILES_Y": 99999})

	print("[Offline] 无限世界已启动 — WASD移动 J采集 B背包 C制造 V建造")


# ========== Chunk 管理 ==========

func _create_world_layers() -> void:
	terrain_root = Node2D.new()
	terrain_root.name = "TerrainChunks"
	add_child(terrain_root)

	object_root = Node2D.new()
	object_root.name = "WorldObjects"
	object_root.y_sort_enabled = true
	add_child(object_root)


func _update_chunks(cx: int, cy: int) -> void:
	if cx == _last_chunk.x and cy == _last_chunk.y:
		return
	_last_chunk = Vector2i(cx, cy)

	var r = CHUNK_VIEW_RADIUS
	var desired: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			desired.append(Vector2i(cx + dx, cy + dy))

	# 卸载不需要的
	for key in _loaded_chunks:
		if key not in desired:
			world_generator.unload_chunk(key.x, key.y)

	# 加载新的
	for key in desired:
		if key not in _loaded_chunks:
			world_generator.generate_chunk(key.x, key.y)

	_loaded_chunks = desired


# ========== 玩家 ==========

func _create_player() -> void:
	var start_x = 50 * TILE_SIZE
	var start_y = 37 * TILE_SIZE

	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(start_x, start_y)

	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = 22.0
	player.add_child(col)

	player_sprite = Sprite2D.new()
	player_sprite.name = "Sprite"
	player_sprite.centered = true
	player_sprite.texture = TextureGen.get_player_texture()
	player_sprite.scale = Vector2(1.5, 1.5)
	player_sprite.z_index = 5
	player.add_child(player_sprite)

	var name_label = Label.new()
	name_label.text = "玩家"
	name_label.position = Vector2(-20, -22)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	player.add_child(name_label)
	object_root.add_child(player)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.zoom = Vector2(1.3, 1.3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _init_systems() -> void:
	item_manager = ItemManager.new()
	item_manager.name = "ItemManager"
	item_manager.initialize_player_inventory(1)
	add_child(item_manager)

	crafting_manager = CraftingManager.new()
	crafting_manager.name = "CraftingManager"
	crafting_manager.item_manager = item_manager
	add_child(crafting_manager)

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

	# 水域阻挡（不再限制世界边界）
	var target_cell = WorldGenerator.world_position_to_cell(next_pos, TILE_SIZE)
	var target_gx = target_cell.x
	var target_gy = target_cell.y
	if world_generator and world_generator.get_biome_id_at(target_gx, target_gy) != "water":
		player.position = next_pos

	# 更新 chunk
	var chunk = WorldGenerator.world_position_to_chunk(player.position, TILE_SIZE)
	_update_chunks(chunk.x, chunk.y)

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

	# 快捷栏 1-9
	for i in range(9):
		if Input.is_key_pressed(KEY_1 + i):
			hud_controller.hotbar_selected = i
			hud_controller.update_hotbar_selection()

	if time_system:
		time_system._process(delta)

	if build_controller.build_mode:
		build_controller.update_preview()

	hud_controller.update(build_controller.build_mode)
	if hud_controller.inventory_dirty:
		hud_controller.refresh_slots()


func _on_harvest_completed(item_id: String, qty: int) -> void:
	hud_controller.mark_dirty()


# ========== 输入 ==========

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

	if build_controller.build_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var keycode = (event as InputEventKey).keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			var idx = keycode - KEY_1
			var blocks = build_controller.get_available_blocks()
			if idx < blocks.size():
				build_controller.select_block(blocks[idx].item_id)

	if not build_controller.build_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var keycode = (event as InputEventKey).keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			hud_controller.hotbar_selected = keycode - KEY_1
			hud_controller.update_hotbar_selection()

	if not build_controller.build_mode and not hud_controller.inventory_open and not hud_controller.craft_open and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			hud_controller.hotbar_selected = (hud_controller.hotbar_selected - 1) % 9
			hud_controller.update_hotbar_selection()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hud_controller.hotbar_selected = (hud_controller.hotbar_selected + 1) % 9
			hud_controller.update_hotbar_selection()


# ========== 装饰物 ==========

func _build_decoration_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	var deco_specs = [
		{"id": "flower", "biomes": ["grass", "forest_floor"], "density": 0.02, "z_index": 2, "scale": 1.5},
		{"id": "grass_tuft", "biomes": ["grass", "dirt", "swamp"], "density": 0.03, "z_index": 2, "scale": 1.5},
		{"id": "mushroom", "biomes": ["forest_floor", "swamp"], "density": 0.01, "z_index": 2, "scale": 1.5},
		{"id": "pebble", "biomes": ["dirt", "stone_path", "sand"], "density": 0.04, "z_index": 1, "scale": 1.5},
		{"id": "rock_small", "biomes": ["stone_path", "dirt"], "density": 0.015, "z_index": 1, "scale": 1.5},
		{"id": "bush_small", "biomes": ["grass", "forest_floor"], "density": 0.015, "z_index": 3, "scale": 1.5},
		{"id": "berry_bush", "biomes": ["forest_floor", "swamp"], "density": 0.012, "z_index": 3, "scale": 1.5},
		{"id": "leaf_pile", "biomes": ["forest_floor"], "density": 0.025, "z_index": 1, "scale": 1.5},
		{"id": "twig", "biomes": ["forest_floor", "grass", "swamp"], "density": 0.025, "z_index": 1, "scale": 1.5},
	]
	for spec in deco_specs:
		var tex = _load_deco_texture("deco_%s.png" % spec["id"])
		if tex:
			defs.append({
				"id": spec["id"],
				"biomes": spec["biomes"],
				"density": spec["density"],
				"z_index": spec["z_index"],
				"scale": spec.get("scale", 1.0),
				"texture": tex,
			})
	return defs


func _load_deco_texture(path: String) -> Texture2D:
	var full = "res://assets/sprites/%s" % path
	if not FileAccess.file_exists(full):
		return null
	var tex: Texture2D = load(full)
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
