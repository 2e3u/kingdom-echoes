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
var harvest_cooldown: float = 0.0
var inventory_open: bool = false
var craft_open: bool = false

# HUD 元素
var hud: CanvasLayer = null
var hud_bg: Panel = null
var hud_labels: Array[Label] = []
var inv_panel: Panel = null
var inv_labels: Array[Label] = []
var craft_panel: Panel = null
var craft_buttons: Array[Button] = []
var craft_title_label: Label = null
var craft_scroll: int = 0

# 昼夜灯光
var light_rect: ColorRect = null


func _ready() -> void:
	rng.seed = 42
	_build_ground()
	_spawn_resources()
	_create_player()
	_setup_camera()
	_init_systems()
	_create_hud()
	print("[Offline] 离线模式已启动 — WASD 移动, E 采集, I 背包, C 制造")


# ========== 地形 ==========

func _build_ground() -> void:
	var tm = TileMap.new()
	tm.name = "Ground"
	tm.tile_set = _make_tileset()
	for x in range(-10, WORLD_TILES_X + 10):
		for y in range(-10, WORLD_TILES_Y + 10):
			var biome = int((sin(x * 0.12) * cos(y * 0.1) + 1.0) * 1.5)
			tm.set_cell(0, Vector2i(x, y), biome, Vector2i(0, 0))
	add_child(tm)


func _make_tileset() -> TileSet:
	var ts = TileSet.new()
	var colors = [
		Color(0.28, 0.58, 0.18), Color(0.22, 0.52, 0.16), Color(0.32, 0.48, 0.14),
	]
	for i in range(3):
		var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(colors[i])
		for _j in range(30):
			var rx = rng.randi_range(0, TILE_SIZE - 1)
			var ry = rng.randi_range(0, TILE_SIZE - 1)
			img.set_pixel(rx, ry, colors[i].lightened(rng.randf_range(-0.06, 0.1)))
		var src = TileSetAtlasSource.new()
		src.texture = ImageTexture.create_from_image(img)
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		ts.add_source(src, i)
	return ts


# ========== 资源生成 ==========

func _spawn_resources() -> void:
	var defs = [
		{"id": "tree", "item": "wood", "qty": 3, "color": Color.SADDLE_BROWN, "count": 100, "size": 22},
		{"id": "copper_ore", "item": "copper_ore", "qty": 2, "color": Color(0.8, 0.5, 0.2), "count": 40, "size": 14},
		{"id": "iron_ore", "item": "iron_ore", "qty": 2, "color": Color(0.5, 0.5, 0.55), "count": 25, "size": 16},
		{"id": "stone_node", "item": "stone", "qty": 3, "color": Color.DIM_GRAY, "count": 50, "size": 16},
		{"id": "herb_red", "item": "herb_red", "qty": 2, "color": Color(0.85, 0.2, 0.35), "count": 60, "size": 10},
		{"id": "fiber_plant", "item": "fiber", "qty": 2, "color": Color(0.2, 0.75, 0.25), "count": 70, "size": 12},
	]
	var res_layer = Node2D.new()
	res_layer.name = "Resources"
	add_child(res_layer)

	for d in defs:
		for _i in range(d.count):
			var pos = Vector2(
				rng.randf_range(4, WORLD_TILES_X - 4) * TILE_SIZE,
				rng.randf_range(4, WORLD_TILES_Y - 4) * TILE_SIZE,
			)
			var id = "%s_%d" % [d.id, resource_sprites.size()]
			var sprite = Sprite2D.new()
			sprite.position = pos
			sprite.centered = true
			var img = Image.create(d.size, d.size, false, Image.FORMAT_RGBA8)
			img.fill(d.color)
			sprite.texture = ImageTexture.create_from_image(img)
			res_layer.add_child(sprite)
			resource_sprites[id] = sprite
			resource_data[id] = {"name": ItemDatabase.get_item_name(d.item), "item_id": d.item, "quantity": d.qty, "depleted": false}


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
	var img = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.5, 0.9))
	for x in range(8, 20):
		for y in range(6, 22):
			img.set_pixel(x, y, Color(0.2, 0.45, 0.85))
	img.set_pixel(10, 10, Color.WHITE); img.set_pixel(17, 10, Color.WHITE)
	img.set_pixel(10, 11, Color.WHITE); img.set_pixel(17, 11, Color.WHITE)
	player_sprite.texture = ImageTexture.create_from_image(img)
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
	camera.zoom = Vector2(0.75, 0.75)
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

	# 顶部信息栏
	hud_bg = Panel.new()
	hud_bg.position = Vector2(8, 8)
	hud_bg.size = Vector2(280, 130)
	hud_bg.modulate = Color(0, 0, 0, 0.55)
	hud.add_child(hud_bg)

	var texts = [
		"[b]王国残响 — 离线模式[/b]",
		"位置: --",
		"附近: --",
		"时间: --",
		"背包: 0 种物品",
		"WASD=移动  E=采集  I=背包  C=制造面板",
	]
	for i in range(6):
		var lbl = Label.new()
		lbl.position = Vector2(16, 14 + i * 18)
		lbl.text = texts[i]
		lbl.add_theme_font_size_override("font_size", 12 if i == 0 else 11)
		lbl.add_theme_color_override("font_color", Color.WHITE if i > 0 else Color(1, 0.85, 0.3))
		hud.add_child(lbl)
		hud_labels.append(lbl)

	# 背包面板（默认隐藏）
	inv_panel = Panel.new()
	inv_panel.position = Vector2(300, 8)
	inv_panel.size = Vector2(320, 320)
	inv_panel.modulate = Color(0, 0, 0, 0.7)
	inv_panel.visible = false
	hud.add_child(inv_panel)

	var inv_title = Label.new()
	inv_title.text = "[b]背包[/b]"
	inv_title.position = Vector2(316, 14)
	inv_title.add_theme_font_size_override("font_size", 14)
	inv_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	inv_title.visible = false
	hud.add_child(inv_title)
	inv_labels.append(inv_title)

	for i in range(15):
		var lbl = Label.new()
		lbl.position = Vector2(316, 36 + i * 18)
		lbl.text = ""
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.visible = false
		hud.add_child(lbl)
		inv_labels.append(lbl)

	# 制造面板（默认隐藏）
	craft_panel = Panel.new()
	craft_panel.position = Vector2(300, 8)
	craft_panel.size = Vector2(360, 400)
	craft_panel.modulate = Color(0, 0, 0, 0.75)
	craft_panel.visible = false
	hud.add_child(craft_panel)

	craft_title_label = Label.new()
	craft_title_label.text = "[b]制造 (手工)[/b]  材料足够=绿色"
	craft_title_label.position = Vector2(316, 14)
	craft_title_label.add_theme_font_size_override("font_size", 14)
	craft_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	craft_title_label.visible = false
	hud.add_child(craft_title_label)
	_refresh_craft_buttons()

	# 昼夜光效叠加层
	light_rect = ColorRect.new()
	light_rect.size = Vector2(4000, 3000)
	light_rect.position = Vector2(-1000, -1000)
	light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(light_rect)


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

	if harvest_cooldown > 0:
		harvest_cooldown -= delta

	# 交互
	if Input.is_action_just_pressed("interact") and harvest_cooldown <= 0:
		_try_harvest()

	if Input.is_action_just_pressed("ui_accept"):
		inventory_open = !inventory_open
		craft_open = false
		inv_panel.visible = inventory_open
		craft_panel.visible = false
		for lbl in inv_labels:
			lbl.visible = inventory_open
		for btn in craft_buttons:
			btn.visible = false
		if craft_title_label:
			craft_title_label.visible = false

	# 昼夜循环
	if time_system:
		time_system._process(delta)

	_update_hud()


# ========== 采集 ==========

func _try_harvest() -> void:
	var nearest_id = ""
	var nearest_dist = 55.0
	for rid in resource_sprites:
		if resource_data.get(rid, {}).get("depleted", false):
			continue
		var dist = player.position.distance_to(resource_sprites[rid].position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = rid

	if nearest_id.is_empty():
		return

	harvest_cooldown = 0.5
	var res = resource_data[nearest_id]
	res["depleted"] = true
	var sprite: Sprite2D = resource_sprites[nearest_id]
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)

	var item_id = res.get("item_id", "")
	var qty = res.get("quantity", 1)
	item_manager.add_item(1, item_id, qty)
	_spawn_floating_text(sprite.position, "+%d %s" % [qty, res.get("name", item_id)])

	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
			res["depleted"] = false
	)


# ========== 制造面板 ==========

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		inventory_open = false
		craft_open = false
		inv_panel.visible = false
		craft_panel.visible = false
		for lbl in inv_labels:
			lbl.visible = false
		for btn in craft_buttons:
			btn.visible = false
		if craft_title_label:
			craft_title_label.visible = false

	if event.is_action_pressed("ui_text_completion_replace") and not event.is_echo():
		craft_open = !craft_open
		inventory_open = false
		inv_panel.visible = false
		craft_panel.visible = craft_open
		for lbl in inv_labels:
			lbl.visible = false
		for btn in craft_buttons:
			btn.visible = craft_open
		if craft_title_label:
			craft_title_label.visible = craft_open
		if craft_open:
			_refresh_craft_buttons()


func _refresh_craft_buttons() -> void:
	for btn in craft_buttons:
		btn.queue_free()
	craft_buttons.clear()

	var recipes = RecipeDatabase.get_recipes_for_station(SharedEnums.CraftStation.HAND)
	var inv = item_manager.get_inventory(1)
	var y_offset = 40

	for i in range(recipes.size()):
		var recipe = recipes[i]
		if i < craft_scroll:
			continue
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
		btn.position = Vector2(316, y_offset)
		btn.size = Vector2(330, 24)
		btn.add_theme_font_size_override("font_size", 9)
		btn.disabled = not can_craft
		if can_craft:
			btn.add_theme_color_override("font_color", Color.GREEN)
		btn.pressed.connect(_on_craft_button.bind(recipe.get("recipe_id", "")))
		btn.visible = craft_open
		hud.add_child(btn)
		craft_buttons.append(btn)
		y_offset += 28
		if y_offset > 370 - 28:
			break


func _on_craft_button(recipe_id: String) -> void:
	var result = crafting_manager.try_craft(1, recipe_id, SharedEnums.CraftStation.HAND)
	if result.get("success", false):
		var recipe = RecipeDatabase.get_recipe(recipe_id)
		_spawn_floating_text(player.position + Vector2(0, -20), "制造: %s" % ItemDatabase.get_item_name(recipe.get("output_item_id", "")))
		_refresh_craft_buttons()
	else:
		_spawn_floating_text(player.position + Vector2(0, -20), "材料不足")


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
	if hud_labels.size() < 6:
		return

	# 位置
	hud_labels[0].text = "位置: (%d, %d)" % [int(player.position.x / TILE_SIZE), int(player.position.y / TILE_SIZE)]

	# 附近资源
	var nearby = {}
	for rid in resource_sprites:
		if resource_data.get(rid, {}).get("depleted", false):
			continue
		var dist = player.position.distance_to(resource_sprites[rid].position)
		if dist < 80:
			var name = resource_data[rid].get("name", "?")
			nearby[name] = nearby.get(name, 0) + 1
	var nearby_text = "无"
	if not nearby.is_empty():
		var parts: Array[String] = []
		for n in nearby:
			parts.append("%s x%d" % [n, nearby[n]])
		nearby_text = ", ".join(parts)
	hud_labels[1].text = "附近: %s" % nearby_text

	# 时间
	if time_system:
		var h = int(time_system.get_game_hour()) % 24
		var phase_names = {0: "清晨", 1: "白天", 2: "黄昏", 3: "夜晚"}
		var phase = phase_names.get(time_system.current_phase, "?")
		hud_labels[2].text = "时间: 第%d天 %02d:00 %s" % [time_system.day_number, h, phase]

		# 昼夜光效
		if light_rect:
			var light = time_system.get_light_multiplier()
			light_rect.color = Color(0, 0, 0.1, (1.0 - light) * 0.5)

	# 背包
	var inv = item_manager.get_inventory(1)
	var item_count = 0
	var total_qty = 0
	if inv:
		for slot in inv.slots:
			if not slot.is_empty():
				item_count += 1
				total_qty += slot.get("quantity", 0)
	hud_labels[3].text = "背包: %d 种 / %d 件" % [item_count, total_qty]

	# 采集冷却
	hud_labels[4].text = "采集: %s" % ("就绪" if harvest_cooldown <= 0 else "冷却中...")

	# 更新背包面板
	if inventory_open and inv:
		_update_inventory_panel(inv)


func _update_inventory_panel(inv) -> void:
	var idx = 1
	var max_show = 14
	for i in range(inv.slots.size()):
		var slot = inv.slots[i]
		if slot.is_empty():
			continue
		if idx <= max_show and idx < inv_labels.size():
			var item_def = ItemDatabase.get_item(slot.get("item_id", ""))
			var name = item_def.get("name", slot.get("item_id", ""))
			var qty = slot.get("quantity", 0)
			var dur = slot.get("durability", 0)
			var broken = " [损坏]" if slot.get("broken", false) else ""
			var dur_text = " (耐久:%d)" % dur if dur > 0 else ""
			inv_labels[idx].text = "  %s x%d%s%s" % [name, qty, dur_text, broken]
		idx += 1
	for i in range(idx, min(max_show + 1, inv_labels.size())):
		inv_labels[i].text = ""
