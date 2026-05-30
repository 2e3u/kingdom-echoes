extends RefCounted
class_name HUDController

## HUDController — 管理所有HUD UI元素：快捷栏、背包、制造、角落信息、采集进度、光照、建造选择栏
## B2修复：inventory_dirty 脏标记延迟图标刷新，避免每帧重生成纹理

# ========== 信号 ==========
signal station_changed(station: int)
signal craft_requested(recipe_id: String, station: int)

# ========== 依赖（通过 setup 注入）==========
var hud: CanvasLayer
var item_manager: ItemManager
var player: CharacterBody2D
var time_system: TimeSystem
var resource_sprites: Dictionary = {}
var resource_data: Dictionary = {}
var crafting_manager: CraftingManager
var stations_unlocked: Array = []
var spawn_text: Callable

# ========== HUD 元素引用 ==========
var hotbar_panel: Panel
var hotbar_slots: Array[Panel] = []
var hotbar_labels: Array[Label] = []
var hotbar_icons: Array[TextureRect] = []
var inv_panel: Panel
var inv_grid: Array[Panel] = []
var inv_grid_labels: Array[Label] = []
var inv_grid_icons: Array[TextureRect] = []
var inv_title: Label
var craft_panel: Panel
var craft_buttons: Array[Button] = []
var craft_title_label: Label
var corner_tl: Label
var minimap_panel: Panel
var minimap_rect: TextureRect
var corner_tr: Label
var hint_label: Label
var harvest_bar_bg: ColorRect
var harvest_bar_fg: ColorRect
var light_rect: ColorRect
var build_bar: Panel
var build_buttons: Array[Button] = []
var build_label: Label
# 物品提示(tooltip)
var tooltip_panel: Panel
var tooltip_label: Label
const CATEGORY_NAMES := ["材料", "工具", "武器", "防具", "消耗品", "饰品"]
const RARITY_NAMES := ["普通", "稀有", "精良", "史诗", "传说"]
const RARITY_COLORS := [Color(0.72, 0.72, 0.72), Color(0.45, 0.85, 0.45), Color(0.45, 0.6, 1.0), Color(0.7, 0.45, 1.0), Color(1.0, 0.65, 0.25)]

# ========== 状态 ==========
var inventory_open: bool = false
var craft_open: bool = false
var current_station: int = SharedEnums.CraftStation.HAND
var hotbar_selected: int = 0
var inventory_dirty: bool = true  # B2修复：脏标记

# ========== 屏幕常量 ==========
const SCREEN_W: int = 1920
const SCREEN_H: int = 1080
const HOTBAR_FRAME_PATH := "res://assets/ui/hotbar_frame.png"
const HOTBAR_WIDTH := 760           # 快捷栏显示宽度
const HOTBAR_INSET_RATIO := 0.035   # 左右内边距占比(微调让图标对齐凹槽)
const HOTBAR_CELL_RATIO := 0.78     # 格子内容大小占格距比例


func setup(
	p_hud: CanvasLayer,
	p_item_manager: ItemManager,
	p_player: CharacterBody2D,
	p_time_system: TimeSystem,
	p_resource_sprites: Dictionary,
	p_resource_data: Dictionary,
	p_crafting_manager: CraftingManager,
	p_stations_unlocked: Array,
	p_spawn_text: Callable,
) -> void:
	hud = p_hud
	item_manager = p_item_manager
	player = p_player
	time_system = p_time_system
	resource_sprites = p_resource_sprites
	resource_data = p_resource_data
	crafting_manager = p_crafting_manager
	stations_unlocked = p_stations_unlocked
	spawn_text = p_spawn_text


# ========== 创建 HUD ==========

func create() -> void:
	# === 底部快捷栏(素材背景 + 10 格) ===
	var frame_tex = load(HOTBAR_FRAME_PATH)
	var bar_w = HOTBAR_WIDTH
	var bar_h = bar_w * 0.14  # 默认比例，下面若有素材则按素材实际比例
	if frame_tex and frame_tex.get_width() > 0:
		bar_h = bar_w * float(frame_tex.get_height()) / float(frame_tex.get_width())
	hotbar_panel = Panel.new()
	hotbar_panel.position = Vector2((SCREEN_W - bar_w) / 2.0, SCREEN_H - bar_h - 6)
	hotbar_panel.size = Vector2(bar_w, bar_h)
	hotbar_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hud.add_child(hotbar_panel)
	if frame_tex:
		var bg = TextureRect.new()
		bg.texture = frame_tex
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # 高清素材用平滑滤镜(项目默认是 nearest 会糊)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar_panel.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 强制填满快捷栏(760×bar_h)，否则会按原图 2508 显示
	# 10 格：等分对齐素材凹槽
	var inset = bar_w * HOTBAR_INSET_RATIO
	var step = (bar_w - inset * 2.0) / 10.0
	var csize = step * HOTBAR_CELL_RATIO
	for i in range(10):
		var cx = inset + (i + 0.5) * step
		var cy = bar_h / 2.0
		var slot = Panel.new()
		slot.size = Vector2(csize, csize)
		slot.position = Vector2(cx - csize / 2.0, cy - csize / 2.0)
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		hotbar_panel.add_child(slot)
		hotbar_slots.append(slot)
		var lbl = Label.new()
		lbl.size = Vector2(csize, csize - 2)
		lbl.position = Vector2(cx - csize / 2.0, cy - csize / 2.0)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar_panel.add_child(lbl)
		hotbar_labels.append(lbl)
		var icon = TextureRect.new()
		icon.size = Vector2(csize * 0.66, csize * 0.66)
		icon.position = Vector2(cx - csize * 0.33, cy - csize * 0.33)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar_panel.add_child(icon)
		hotbar_icons.append(icon)
		slot.mouse_entered.connect(_show_item_tooltip.bind(i, slot))
		slot.mouse_exited.connect(_hide_tooltip)
	update_hotbar_selection()

	# === 背包面板 (B键居中) ===
	var inv_w = 480; var inv_h = 360
	inv_panel = Panel.new()
	inv_panel.position = Vector2((SCREEN_W - inv_w) / 2, (SCREEN_H - inv_h) / 2 - 30)
	inv_panel.size = Vector2(inv_w, inv_h)
	inv_panel.modulate = Color(0.05, 0.05, 0.05, 0.92)
	inv_panel.visible = false
	hud.add_child(inv_panel)

	inv_title = Label.new()
	inv_title.text = "背包"
	inv_title.position = Vector2((SCREEN_W - inv_w) / 2 + 16, (SCREEN_H - inv_h) / 2 - 30 + 10)
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	inv_title.visible = false
	hud.add_child(inv_title)

	# 背包格子 5列x4行
	for row in range(4):
		for col in range(5):
			var s = _make_slot(inv_panel, Vector2(16 + col * 92, 44 + row * 74), Vector2(84, 68),
				Vector2(20 + col * 92, 46 + row * 74), Vector2(76, 64), Vector2(20 + col * 92 + 4, 48 + row * 74 + 4), false, true)
			inv_grid.append(s["slot"])
			inv_grid_labels.append(s["label"])
			inv_grid_icons.append(s["icon"])
			s["slot"].mouse_entered.connect(_show_item_tooltip.bind(row * 5 + col, s["slot"]))
			s["slot"].mouse_exited.connect(_hide_tooltip)

	# === 制造面板 (C键居中) ===
	var cw = 420; var ch = 420
	craft_panel = Panel.new()
	craft_panel.position = Vector2((SCREEN_W - cw) / 2, (SCREEN_H - ch) / 2 - 30)
	craft_panel.size = Vector2(cw, ch)
	craft_panel.modulate = Color(0.05, 0.05, 0.05, 0.92)
	craft_panel.visible = false
	hud.add_child(craft_panel)

	craft_title_label = Label.new()
	craft_title_label.text = "制造 (手工)"
	craft_title_label.position = Vector2((SCREEN_W - cw) / 2 + 16, (SCREEN_H - ch) / 2 - 30 + 10)
	craft_title_label.add_theme_font_size_override("font_size", 20)
	craft_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	craft_title_label.visible = false
	hud.add_child(craft_title_label)
	refresh_craft_buttons()

	# === 左上角：时间+位置 ===
	# 小地图(左上角)
	minimap_panel = Panel.new()
	minimap_panel.position = Vector2(12, 12)
	minimap_panel.size = Vector2(180, 180)
	var msb = StyleBoxFlat.new()
	msb.bg_color = Color(0.05, 0.05, 0.07, 0.9)
	msb.set_border_width_all(2)
	msb.border_color = Color(0.5, 0.45, 0.3)
	msb.set_corner_radius_all(3)
	minimap_panel.add_theme_stylebox_override("panel", msb)
	hud.add_child(minimap_panel)
	minimap_rect = TextureRect.new()
	minimap_rect.position = Vector2(4, 4)
	minimap_rect.size = Vector2(172, 172)
	minimap_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_rect.stretch_mode = TextureRect.STRETCH_SCALE
	minimap_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap_panel.add_child(minimap_rect)

	corner_tl = Label.new()
	corner_tl.position = Vector2(12, 200)
	corner_tl.add_theme_font_size_override("font_size", 15)
	corner_tl.add_theme_color_override("font_color", Color.WHITE)
	corner_tl.text = ""
	hud.add_child(corner_tl)

	# === 右上角：附近资源 ===
	corner_tr = Label.new()
	corner_tr.position = Vector2(SCREEN_W - 300, 10)
	corner_tr.size = Vector2(288, 80)
	corner_tr.add_theme_font_size_override("font_size", 14)
	corner_tr.add_theme_color_override("font_color", Color.WHITE)
	corner_tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner_tr.text = ""
	hud.add_child(corner_tr)

	# === 底部提示 ===
	hint_label = Label.new()
	hint_label.position = Vector2(16, SCREEN_H - 24)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint_label.text = "WASD移动  J采集  B背包  C制造  V建造  ESC关闭"
	hud.add_child(hint_label)

	# === 采集进度条 ===
	harvest_bar_bg = ColorRect.new()
	harvest_bar_bg.size = Vector2(200, 14)
	harvest_bar_bg.position = Vector2((SCREEN_W - 200) / 2, 60)
	harvest_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	harvest_bar_bg.visible = false
	hud.add_child(harvest_bar_bg)

	harvest_bar_fg = ColorRect.new()
	harvest_bar_fg.size = Vector2(0, 10)
	harvest_bar_fg.position = Vector2((SCREEN_W - 200) / 2 + 2, 62)
	harvest_bar_fg.color = Color(0.3, 0.8, 0.3)
	harvest_bar_fg.visible = false
	hud.add_child(harvest_bar_fg)

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

	_build_tooltip()


# ========== 物品提示 tooltip ==========

func _build_tooltip() -> void:
	tooltip_panel = Panel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.5, 0.5, 0.55)
	sb.set_corner_radius_all(4)
	tooltip_panel.add_theme_stylebox_override("panel", sb)
	tooltip_panel.z_index = 200
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label = Label.new()
	tooltip_label.position = Vector2(10, 8)
	tooltip_label.add_theme_font_size_override("font_size", 13)
	tooltip_panel.add_child(tooltip_label)
	hud.add_child(tooltip_panel)


## 悬停背包/快捷栏格子时，显示对应物品的名称、类型、稀有度与关键属性。
func _show_item_tooltip(idx: int, slot_node: Control) -> void:
	if tooltip_panel == null or item_manager == null:
		return
	var inv = item_manager.get_inventory(1)
	if inv == null or idx >= inv.slots.size():
		_hide_tooltip()
		return
	var sd = inv.slots[idx]
	if not (sd is Dictionary) or sd.is_empty() or not sd.has("item_id"):
		_hide_tooltip()
		return
	var item = ItemDatabase.get_item(sd["item_id"])
	if item.is_empty():
		_hide_tooltip()
		return
	var rarity = int(item.get("rarity", 0))
	var cat = int(item.get("category", 0))
	var lines: Array = []
	lines.append(str(item.get("name", "?")))
	var cat_name = CATEGORY_NAMES[cat] if cat < CATEGORY_NAMES.size() else "?"
	var rar_name = RARITY_NAMES[rarity] if rarity < RARITY_NAMES.size() else "?"
	lines.append("%s · %s" % [cat_name, rar_name])
	if item.has("use_effect") and item["use_effect"] is Dictionary:
		var ue = item["use_effect"]
		if str(ue.get("type", "")) == "heal":
			lines.append("使用：恢复 %d 生命" % int(ue.get("value", 0)))
	if item.has("stats") and item["stats"] is Dictionary and item["stats"].has("damage"):
		lines.append("伤害 %d" % int(item["stats"]["damage"]))
	lines.append("叠加上限 %d" % int(item.get("stack_max", 1)))
	tooltip_label.text = "\n".join(lines)
	var rc: Color = RARITY_COLORS[rarity] if rarity < RARITY_COLORS.size() else Color.WHITE
	tooltip_label.add_theme_color_override("font_color", rc)
	tooltip_panel.size = Vector2(210, 16 + lines.size() * 18)
	tooltip_panel.global_position = slot_node.global_position + Vector2(0, -tooltip_panel.size.y - 6)
	tooltip_panel.visible = true


func _hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false


# ========== 每帧轻量更新（不含图标纹理）==========

func update(p_build_mode: bool) -> void:
	var inv = item_manager.get_inventory(1)

	# === 左上角：位置+时间 ===
	var pos_text = "(%d, %d)" % [int(player.position.x / 32), int(player.position.y / 32)]
	if time_system:
		var h = int(time_system.get_game_hour()) % 24
		var phase_names = {0: "清晨", 1: "白天", 2: "黄昏", 3: "夜晚"}
		var phase = phase_names.get(time_system.current_phase, "?")
		var build_status = " | [建造中]" if p_build_mode else ""
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


# ========== 图标纹理刷新（仅在脏标记为 true 时调用）==========

func refresh_slots() -> void:
	var inv = item_manager.get_inventory(1)

	# === 底部快捷栏 ===
	if inv:
		for i in range(10):
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

	# === 背包面板（仅在打开时更新）===
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

	inventory_dirty = false


func mark_dirty() -> void:
	inventory_dirty = true


# ========== 面板管理 ==========

func toggle_inventory() -> void:
	inventory_open = !inventory_open
	if inventory_open:
		craft_open = false
		craft_panel.visible = false
		craft_title_label.visible = false
		for btn in craft_buttons:
			btn.visible = false
		build_bar.visible = false
		build_label.visible = false
		for btn in build_buttons:
			btn.visible = false
	inv_panel.visible = inventory_open
	inv_title.visible = inventory_open
	mark_dirty()


func toggle_craft() -> void:
	craft_open = !craft_open
	if craft_open:
		inventory_open = false
		inv_panel.visible = false
		inv_title.visible = false
	else:
		close_all()
	craft_panel.visible = craft_open
	craft_title_label.visible = craft_open
	for btn in craft_buttons:
		btn.visible = craft_open
	if craft_open:
		refresh_craft_buttons()
	mark_dirty()


func close_all() -> void:
	inventory_open = false
	craft_open = false
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
	set_hint("WASD移动 J采集 B背包 C制造 V建造")
	mark_dirty()


func set_hint(text: String) -> void:
	if hint_label:
		hint_label.text = text


# ========== 快捷栏 ==========

func update_hotbar_selection() -> void:
	for i in range(10):
		if i >= hotbar_slots.size():
			continue
		if i == hotbar_selected:
			var sel = StyleBoxFlat.new()
			sel.bg_color = Color(0.9, 0.63, 0.29, 0.18)   # 暖橙微底
			sel.set_border_width_all(2)
			sel.border_color = Color(0.95, 0.7, 0.35)      # 暖橙描边
			sel.set_corner_radius_all(3)
			hotbar_slots[i].add_theme_stylebox_override("panel", sel)
		else:
			hotbar_slots[i].add_theme_stylebox_override("panel", StyleBoxEmpty.new())


# ========== 采集进度条 ==========

func show_harvest_bar(visible: bool) -> void:
	harvest_bar_bg.visible = visible
	harvest_bar_fg.visible = visible
	if not visible:
		harvest_bar_fg.size.x = 0


func update_harvest_bar(progress: float) -> void:
	harvest_bar_fg.size.x = progress * 196


# ========== 制造面板 ==========

func refresh_craft_buttons() -> void:
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
	station_changed.emit(station)
	refresh_craft_buttons()


func _on_craft_button(recipe_id: String) -> void:
	var result = crafting_manager.try_craft(1, recipe_id, current_station)
	if result.get("success", false):
		var recipe = RecipeDatabase.get_recipe(recipe_id)
		var output_id = recipe.get("output_item_id", "")
		spawn_text.call(player.position + Vector2(0, -20), "制造: %s" % ItemDatabase.get_item_name(output_id))
		# 检查是否解锁新工作站
		var item_def = ItemDatabase.get_item(output_id)
		var station_type = item_def.get("station_type", -1)
		if station_type > 0 and station_type not in stations_unlocked:
			stations_unlocked.append(station_type)
			spawn_text.call(player.position + Vector2(0, -40), "解锁新工作站!")
		refresh_craft_buttons()
		craft_requested.emit(recipe_id, current_station)
		mark_dirty()
	else:
		spawn_text.call(player.position + Vector2(0, -20), "材料不足")


func _count_item(item_id: String) -> int:
	var inv = item_manager.get_inventory(1)
	if not inv:
		return 0
	var total = 0
	for slot in inv.slots:
		if not slot.is_empty() and slot.get("item_id", "") == item_id:
			total += slot.get("quantity", 0)
	return total


# ========== 信号访问器 ==========

func get_station_changed_signal() -> Signal:
	return station_changed


func get_craft_signal() -> Signal:
	return craft_requested


# ========== 物品格子构建 ==========

## 创建一个物品格子（背景面板 + 数量文字 + 图标），快捷栏和背包共用。
## 返回 {"slot", "label", "icon"} 三个节点，供调用方存入各自的数组。
func _make_slot(parent: Control, slot_pos: Vector2, slot_size: Vector2,
		label_pos: Vector2, label_size: Vector2, icon_pos: Vector2,
		label_centered: bool, label_autowrap: bool) -> Dictionary:
	var slot = Panel.new()
	slot.position = slot_pos
	slot.size = slot_size
	slot.modulate = Color(0.15, 0.15, 0.15, 0.9)
	parent.add_child(slot)

	var lbl = Label.new()
	lbl.position = label_pos
	lbl.size = label_size
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	if label_centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_autowrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)

	var icon = TextureRect.new()
	icon.position = icon_pos
	icon.size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	parent.add_child(icon)

	return {"slot": slot, "label": lbl, "icon": icon}
