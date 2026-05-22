extends RefCounted
class_name BuildController

## BuildController — 建造模式管理：方塊預覽、放置、回收、選擇
## B1修復：_update_ghost_preview 直接使用緩存紋理，不再每幀重建 ImageTexture

# ========== 依赖（通过 setup 注入）==========
var player: CharacterBody2D
var item_manager: ItemManager
var hud_controller: HUDController
var scene_root: Node2D
var stations_unlocked: Array
var spawn_text: Callable
var world_constants: Dictionary  # {"TILE_SIZE": 32, "WORLD_TILES_X": 80, "WORLD_TILES_Y": 60}

# ========== 状态 ==========
var build_mode: bool = false
var selected_block_item: String = ""
var ghost_sprite: Sprite2D = null
var placed_blocks: Dictionary = {}


func setup(p_player, p_item_manager, p_hud_controller, p_scene_root, p_stations_unlocked, p_spawn_text, p_world_constants) -> void:
	player = p_player
	item_manager = p_item_manager
	hud_controller = p_hud_controller
	scene_root = p_scene_root
	stations_unlocked = p_stations_unlocked
	spawn_text = p_spawn_text
	world_constants = p_world_constants


func is_active() -> bool:
	return build_mode


# ========== 建造開關 ==========

func toggle() -> void:
	build_mode = !build_mode
	if build_mode:
		hud_controller.close_all()
		if not ghost_sprite:
			ghost_sprite = Sprite2D.new()
			ghost_sprite.name = "BuildGhost"
			ghost_sprite.centered = true
			ghost_sprite.z_index = 100
			ghost_sprite.modulate = Color(1, 1, 1, 0.55)
			scene_root.add_child(ghost_sprite)
		_refresh_selection()
		ghost_sprite.visible = true
		spawn_text.call(player.position + Vector2(0, -30), "[建造模式] J放置 K回收")
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


# ========== 可選方塊列表 ==========

func get_available_blocks() -> Array:
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


# ========== 方塊選擇 UI ==========

func _refresh_selection() -> void:
	for btn in hud_controller.build_buttons:
		btn.queue_free()
	hud_controller.build_buttons.clear()

	var blocks = get_available_blocks()
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
		btn.pressed.connect(select_block.bind(b.item_id))
		btn.visible = build_mode
		hud_controller.hud.add_child(btn)
		hud_controller.build_buttons.append(btn)
		y += 26

	hud_controller.build_bar.visible = build_mode
	hud_controller.build_label.visible = build_mode


func select_block(item_id: String) -> void:
	selected_block_item = item_id
	_refresh_selection()


# ========== 建造欄滑鼠檢測 ==========

func _is_mouse_over_build_bar(mouse_pos: Vector2) -> bool:
	if not hud_controller.build_bar.visible:
		return false
	var bar_rect = Rect2(hud_controller.build_bar.position, hud_controller.build_bar.size)
	return bar_rect.has_point(mouse_pos)


# ========== 滾輪切換方塊 ==========

func cycle_selection(direction: int) -> void:
	var blocks = get_available_blocks()
	if blocks.is_empty():
		return
	var idx = -1
	for i in range(blocks.size()):
		if blocks[i].item_id == selected_block_item:
			idx = i
			break
	idx = (idx + direction) % blocks.size()
	selected_block_item = blocks[idx].item_id
	_refresh_selection()


# ========== 幽靈預覽（B1 修復）==========

func update_preview() -> void:
	if not ghost_sprite or selected_block_item.is_empty():
		return
	var TILE_SIZE: int = world_constants.TILE_SIZE
	var WORLD_TILES_X: int = world_constants.WORLD_TILES_X
	var WORLD_TILES_Y: int = world_constants.WORLD_TILES_Y

	var mouse_pos = scene_root.get_global_mouse_position()
	var grid_pos = (mouse_pos / TILE_SIZE).floor() * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	# 限制在世界范围内
	grid_pos.x = clamp(grid_pos.x, TILE_SIZE, (WORLD_TILES_X - 1) * TILE_SIZE)
	grid_pos.y = clamp(grid_pos.y, TILE_SIZE, (WORLD_TILES_Y - 1) * TILE_SIZE)
	ghost_sprite.position = grid_pos

	# B1 FIX: 直接使用緩存紋理，不再每幀提取 Image 並創建新的 ImageTexture
	ghost_sprite.texture = TextureGen.get_block_texture(selected_block_item)

	# 检查是否被占用（红色表示不可放置）
	var grid_key = "%d_%d" % [int(grid_pos.x), int(grid_pos.y)]
	if placed_blocks.has(grid_key):
		ghost_sprite.modulate = Color(1, 0.3, 0.3, 0.55)
	else:
		ghost_sprite.modulate = Color(1, 1, 1, 0.55)


# ========== 放置方塊 ==========

func try_place() -> void:
	if selected_block_item.is_empty():
		return
	var TILE_SIZE: int = world_constants.TILE_SIZE
	var WORLD_TILES_X: int = world_constants.WORLD_TILES_X
	var WORLD_TILES_Y: int = world_constants.WORLD_TILES_Y

	var grid_pos: Vector2
	if ghost_sprite and ghost_sprite.visible:
		grid_pos = ghost_sprite.position
	else:
		var mouse_pos = scene_root.get_global_mouse_position()
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
		spawn_text.call(player.position + Vector2(0, -20), "缺少方块!")
		return

	var item_def = ItemDatabase.get_item(selected_block_item)
	var block_type = item_def.get("block_type", 0)
	var sprite = Sprite2D.new()
	sprite.name = "Block_%s" % grid_key
	sprite.position = grid_pos
	sprite.centered = true
	sprite.z_index = 1
	sprite.texture = TextureGen.get_block_texture(selected_block_item)
	scene_root.add_child(sprite)
	placed_blocks[grid_key] = {"item_id": selected_block_item, "sprite": sprite}

	# 工作站解锁对应制造站
	if block_type == SharedEnums.BlockType.WORKSTATION:
		var station_type = item_def.get("station_type", -1)
		if station_type > 0 and station_type not in stations_unlocked:
			stations_unlocked.append(station_type)
			spawn_text.call(grid_pos + Vector2(0, -20), "解锁工作站!")

	spawn_text.call(grid_pos + Vector2(0, -16), "放置: %s" % item_def.get("name", selected_block_item))
	_refresh_selection()


# ========== 回收方塊 ==========

func try_remove() -> void:
	var TILE_SIZE: int = world_constants.TILE_SIZE
	var grid_pos: Vector2
	if ghost_sprite and ghost_sprite.visible:
		grid_pos = ghost_sprite.position
	else:
		var mouse_pos = scene_root.get_global_mouse_position()
		grid_pos = (mouse_pos / TILE_SIZE).floor() * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	var grid_key = "%d_%d" % [int(grid_pos.x), int(grid_pos.y)]
	if not placed_blocks.has(grid_key):
		return
	var block_info = placed_blocks[grid_key]
	var sprite: Sprite2D = block_info.sprite
	if is_instance_valid(sprite):
		sprite.queue_free()
	spawn_text.call(grid_pos + Vector2(0, -16), "回收: %s" % ItemDatabase.get_item_name(block_info.item_id))
	item_manager.add_item(1, block_info.item_id, 1)
	placed_blocks.erase(grid_key)
	_refresh_selection()
