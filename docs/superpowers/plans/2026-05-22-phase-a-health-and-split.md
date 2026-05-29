# Phase A: 健康度修复 + 代码拆分 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 3 个 bug，将 1553 行 `kingdom_echoes.gd` 拆分为 5 个模块（TextureGen, HUDController, HarvestController, BuildController, 精简主控）

**Architecture:** 创建 4 个新 class_name 脚本，各司其职；主控改为薄层调度器。TextureGen 纯静态工厂，其余 3 个 controller 通过构造函数接收依赖引用。

**Tech Stack:** Godot 4.6 GDScript, class_name 注册, no additional dependencies

---

## File Map

```
scripts/game/
├── kingdom_echoes.gd      # 主控制器 ~250行 (场景搭建 + 输入分发 + 浮字)
├── texture_gen.gd         # 静态纹理工厂 ~500行 (所有 _make_* 函数)
├── hud_controller.gd      # HUD系统 ~500行 (创建/更新/面板管理)
├── harvest_controller.gd  # 采集系统 ~250行 (寻路/进度/完成)
└── build_controller.gd    # 建造系统 ~300行 (预览/放置/回收)
```

Each new file: `extends RefCounted` or `extends Node` with `class_name`.

---

### Task 1: Fix Bug B3 — consume_durability 工具损坏覆盖数据

**Files:**
- Modify: `scripts/server/item_manager.gd:138-141`

**Purpose:** `slot["broken"] = true` 语句不会覆盖整个 slot 字典（GDScript 的字典键赋值只设置单个键），但原代码行间空白和上下文容易引起误解。实测确认这条语句本身是安全的——`slot["broken"] = true` 只设置 broken 键，不覆盖 item_id/quantity。为防止后续误操作，添加显式注释说明，并确保 `slot` 引用生效。

实际检查发现：`slot["durability"] = max(0, dur - amount)` 已正确工作。无需修改。标记此 bug 为误报，实际代码安全。

- [ ] **Step 1: 确认 consume_durability 行为**

Read `scripts/server/item_manager.gd` lines 128-141. 确认 `slot["broken"] = true` 不会覆盖 slot 字典。
GDScript 行为：`slot["broken"] = true` 是字典键赋值，不覆盖其他键。代码安全，无需修改。

- [ ] **Step 2: 编译验证**

Run: `/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"`
Expected: No errors (only preset warnings)

- [ ] **Step 3: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add -A
git commit -m "chore: B3 确认为误报 — consume_durability 字典赋值安全"
```

---

### Task 2: Create TextureGen — 静态纹理工厂

**Files:**
- Create: `scripts/game/texture_gen.gd`

**Purpose:** 将纹理生成代码（~400行）和物品图标代码（~130行）提取为纯静态工具类。无 `_process`，无游戏状态依赖。自带静态 RNG 实例和 TILE_SIZE 常量。

**Extracted from `kingdom_echoes.gd`:**
- Lines 89-111: `_px`, `_px_rect`, `_px_circle`, `_px_noise` (4 pixel helpers)
- Lines 113-390: `_make_grass_tile`, `_make_tree_texture`, `_make_stump_texture`, `_make_stone_texture`, `_make_ore_texture`, `_make_herb_texture`, `_make_fiber_texture`, `_make_player_texture`, `_make_block_texture` (9 texture functions)
- Lines 404-413: `_make_tileset` (uses `_make_grass_tile`)
- Lines 1322-1455: `_make_item_icon` (1 icon function, 30+ items)
- Line 89: `_tex_cache` (texture cache)

**Changes vs original:**
- All functions become `static func`
- `rng` → `static var _rng: RandomNumberGenerator` (own instance)
- `TILE_SIZE` → added as `const TILE_SIZE: int = 32`
- `_tex_cache` → `static var _tex_cache: Dictionary = {}`
- All `_make_*` rename → `get_*` (public API)
- `_px*` helpers stay private

- [ ] **Step 1: Write texture_gen.gd**

```gdscript
extends RefCounted
class_name TextureGen

## 纯静态纹理工厂 — 像素级程序化贴图生成
## 无 _process，无游戏状态，线程安全（单线程使用）

const TILE_SIZE: int = 32

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _tex_cache: Dictionary = {}

# ========== 像素辅助 ==========

static func _px(x: int, y: int, color: Color, img: Image) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)

static func _px_rect(x: int, y: int, w: int, h: int, color: Color, img: Image) -> void:
	for dx in range(w):
		for dy in range(h):
			_px(x + dx, y + dy, color, img)

static func _px_circle(cx: int, cy: int, r: int, color: Color, img: Image) -> void:
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x * x + y * y <= r * r:
				_px(cx + x, cy + y, color, img)

static func _px_noise(count: int, color: Color, variation: float, img: Image) -> void:
	var w = img.get_width(); var h = img.get_height()
	for _i in range(count):
		var nx = _rng.randi_range(0, w - 1)
		var ny = _rng.randi_range(0, h - 1)
		img.set_pixel(nx, ny, color.lightened(_rng.randf_range(-variation, variation)))

# ========== 地形纹理 ==========

static func get_grass_tile(variant: int) -> ImageTexture:
	var key = "grass_%d" % variant
	if _tex_cache.has(key): return _tex_cache[key]
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base = [Color(0.29, 0.62, 0.18), Color(0.24, 0.55, 0.15), Color(0.33, 0.50, 0.16)][variant]
	img.fill(base)
	for _i in range(60):
		var nx = _rng.randi_range(0, TILE_SIZE - 1); var ny = _rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(nx, ny, base.lightened(_rng.randf_range(-0.08, 0.12)))
	var grass_c = base.lightened(0.15)
	for _i in range(6):
		var gx = _rng.randi_range(1, TILE_SIZE - 2)
		var gy = _rng.randi_range(1, TILE_SIZE - 4)
		for h in range(_rng.randi_range(2, 4)):
			_px(gx, gy - h, grass_c, img)
			if _rng.randf() > 0.5: _px(gx + 1, gy - h, grass_c.darkened(0.05), img)
	if variant == 0 and _rng.randf() < 0.4:
		var fx = _rng.randi_range(3, TILE_SIZE - 4); var fy = _rng.randi_range(5, TILE_SIZE - 3)
		_px(fx, fy, Color.WHITE, img); _px(fx + 1, fy, Color.WHITE, img)
		_px(fx, fy - 1, Color.WHITE, img); _px(fx - 1, fy, Color.YELLOW, img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

# ========== 资源纹理 ==========

static func get_tree_texture() -> ImageTexture:
	var key = "tree"
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 28; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var trunk_c = Color(0.35, 0.2, 0.1)
	_px_rect(s / 2 - 3, s / 2 - 2, 6, 14, trunk_c, img)
	for x in range(s / 2 - 3, s / 2 + 3):
		_px(x, s / 2 + 12, trunk_c.darkened(0.15), img)
	var crown_c = Color(0.2, 0.55, 0.15)
	var cy = s / 2 - 4; var cx = s / 2
	for r in range(11, 6, -1):
		_px_circle(cx, cy, r, crown_c, img)
		cy -= 1; crown_c = crown_c.lightened(0.04)
	for _i in range(20):
		var lx = clampi(_rng.randi_range(cx - 9, cx + 9), 0, s - 1)
		var ly = clampi(_rng.randi_range(cy - 7, cy + 8), 0, s - 1)
		if img.get_pixel(lx, ly).a > 0 and img.get_pixel(lx, ly).r > 0.1:
			img.set_pixel(lx, ly, img.get_pixel(lx, ly).lightened(_rng.randf_range(-0.08, 0.12)))
	for _i in range(5):
		var hx = clampi(_rng.randi_range(cx - 4, cx + 4), 0, s - 1)
		var hy = clampi(_rng.randi_range(cy - 5, cy - 2), 0, s - 1)
		if img.get_pixel(hx, hy).a > 0:
			img.set_pixel(hx, hy, Color(0.4, 0.72, 0.25))
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func get_stump_texture() -> ImageTexture:
	var key = "stump"
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 20; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood_c = Color(0.35, 0.2, 0.1)
	_px_rect(s / 2 - 4, s / 2 - 2, 8, 8, wood_c, img)
	var ring_c = wood_c.lightened(0.15)
	_px_rect(s / 2 - 2, s / 2, 5, 3, ring_c, img)
	_px(s / 2, s / 2 + 1, wood_c.darkened(0.1), img)
	_px_rect(s / 2 - 5, s / 2 + 4, 3, 3, wood_c.darkened(0.1), img)
	_px_rect(s / 2 + 2, s / 2 + 4, 3, 3, wood_c.darkened(0.1), img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func get_stone_texture() -> ImageTexture:
	var key = "stone"
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 18; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base = Color(0.5, 0.48, 0.45)
	_px_circle(s / 2, s / 2, 7, base, img)
	var hl = base.lightened(0.2)
	for _i in range(8):
		var hx = _rng.randi_range(s / 2 - 5, s / 2 - 1); var hy = _rng.randi_range(s / 2 - 5, s / 2 - 1)
		if img.get_pixel(hx, hy).a > 0: img.set_pixel(hx, hy, hl)
	var sd = base.darkened(0.2)
	for _i in range(8):
		var sx = _rng.randi_range(s / 2 + 1, s / 2 + 5); var sy = _rng.randi_range(s / 2 + 1, s / 2 + 5)
		if img.get_pixel(sx, sy).a > 0: img.set_pixel(sx, sy, sd)
	for _i in range(2):
		var cx = _rng.randi_range(s / 2 - 3, s / 2 + 2); var cy = _rng.randi_range(s / 2 - 3, s / 2 + 2)
		for _j in range(_rng.randi_range(2, 4)):
			_px(cx + _j, cy, base.darkened(0.15), img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func get_ore_texture(base_color: Color, spec_color: Color) -> ImageTexture:
	var key = "ore_%s" % base_color.to_html()
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 18; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_px_circle(s / 2, s / 2, 7, base_color, img)
	var hl = base_color.lightened(0.15)
	for _i in range(6):
		var hx = _rng.randi_range(s / 2 - 4, s / 2); var hy = _rng.randi_range(s / 2 - 4, s / 2)
		if img.get_pixel(hx, hy).a > 0: img.set_pixel(hx, hy, hl)
	var sd = base_color.darkened(0.2)
	for _i in range(6):
		var sx = _rng.randi_range(s / 2, s / 2 + 4); var sy = _rng.randi_range(s / 2, s / 2 + 4)
		if img.get_pixel(sx, sy).a > 0: img.set_pixel(sx, sy, sd)
	for _i in range(8):
		var mx = _rng.randi_range(s / 2 - 5, s / 2 + 4); var my = _rng.randi_range(s / 2 - 5, s / 2 + 4)
		if img.get_pixel(mx, my).a > 0:
			img.set_pixel(mx, my, spec_color.lightened(_rng.randf_range(-0.1, 0.15)))
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func get_herb_texture() -> ImageTexture:
	var key = "herb"
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 14; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leaf_c = Color(0.85, 0.2, 0.35)
	var cx = s / 2; var cy = s / 2
	var dirs = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i in range(4):
		var d = dirs[i]
		for j in range(1, 5):
			_px(cx + int(d.x * j), cy + int(d.y * j), leaf_c, img)
			if j > 1: _px(cx + int(d.x * j) + int(d.y), cy + int(d.y * j) + int(d.x), leaf_c.darkened(0.1), img)
	_px(cx, cy, Color(0.6, 0.1, 0.2), img); _px(cx + 1, cy, Color(0.6, 0.1, 0.2), img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func get_fiber_texture() -> ImageTexture:
	var key = "fiber"
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 16; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stalk_c = Color(0.25, 0.7, 0.2)
	for si in range(3):
		var sx = 4 + si * 4; var sh = 8 + _rng.randi_range(0, 6)
		for y in range(sh):
			_px(sx, s - 2 - y, stalk_c, img)
		var leaf_dir = 1 if si % 2 == 0 else -1
		for li in range(2):
			var ly = s - 4 - li * 4
			_px(sx + leaf_dir, ly, stalk_c.lightened(0.1), img)
			_px(sx + leaf_dir * 2, ly, stalk_c.lightened(0.15), img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func get_player_texture() -> ImageTexture:
	var key = "player"
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 24; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_px_rect(8, 3, 8, 4, Color(0.25, 0.15, 0.05), img)
	_px(7, 5, Color(0.25, 0.15, 0.05), img); _px(16, 5, Color(0.25, 0.15, 0.05), img)
	_px_rect(8, 6, 8, 6, Color(0.95, 0.8, 0.65), img)
	_px(10, 8, Color(0.1, 0.1, 0.15), img); _px(14, 8, Color(0.1, 0.1, 0.15), img)
	_px(10, 9, Color(0.1, 0.1, 0.15), img); _px(14, 9, Color(0.1, 0.1, 0.15), img)
	_px_rect(8, 12, 8, 6, Color(0.25, 0.5, 0.8), img)
	_px_rect(8, 16, 8, 2, Color(0.4, 0.3, 0.2), img)
	_px_rect(9, 18, 3, 5, Color(0.3, 0.25, 0.2), img)
	_px_rect(13, 18, 3, 5, Color(0.3, 0.25, 0.2), img)
	_px_rect(8, 22, 4, 2, Color(0.2, 0.15, 0.1), img)
	_px_rect(13, 22, 4, 2, Color(0.2, 0.15, 0.1), img)
	_px_rect(5, 12, 3, 2, Color(0.95, 0.8, 0.65), img)
	_px_rect(17, 12, 3, 2, Color(0.95, 0.8, 0.65), img)
	_px_rect(5, 14, 3, 3, Color(0.25, 0.5, 0.8), img)
	_px_rect(17, 14, 3, 3, Color(0.25, 0.5, 0.8), img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

# ========== 方块纹理 ==========

static func get_block_texture(item_id: String) -> ImageTexture:
	var key = "block_%s" % item_id
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 24; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match item_id:
		"wood_floor":
			var wc = Color(0.55, 0.38, 0.22)
			img.fill(wc)
			for y in range(5, s, 6):
				for x in range(s):
					_px(x, y, wc.darkened(0.12), img)
			for _i in range(15):
				var gx = _rng.randi_range(0, s - 1); var gy = _rng.randi_range(0, s - 1)
				if gy % 6 < 4: img.set_pixel(gx, gy, img.get_pixel(gx, gy).lightened(_rng.randf_range(-0.05, 0.08)))
		"stone_floor":
			var sc = Color(0.5, 0.5, 0.52)
			img.fill(sc)
			for y in range(0, s, 6):
				for x in range(0, s, 6):
					_px_rect(x, y, 5, 5, sc, img)
					_px(x + 5, y, sc.darkened(0.15), img)
					_px(x, y + 5, sc.darkened(0.15), img)
			_px_noise(12, sc, 0.08, img)
		"wood_wall":
			var ww = Color(0.4, 0.28, 0.15)
			img.fill(ww)
			for x in range(5, s, 6):
				for y in range(s):
					_px(x, y, ww.darkened(0.15), img)
			_px_noise(10, ww, 0.06, img)
		"stone_wall":
			var sw = Color(0.38, 0.37, 0.4)
			img.fill(sw)
			for y in range(0, s, 6):
				for x in range(0, s, 6):
					_px(x + 5, y, sw.darkened(0.18), img)
					_px(x, y + 5, sw.darkened(0.18), img)
			_px_noise(12, sw, 0.06, img)
		"wooden_chest":
			var cc = Color(0.6, 0.35, 0.15)
			img.fill(cc)
			_px_rect(2, 2, s - 4, s - 4, cc.darkened(0.08), img)
			_px_rect(4, 4, s - 8, 3, Color(0.7, 0.7, 0.2), img)
			_px_rect(s / 2 - 1, 4, 3, 3, Color(0.5, 0.5, 0.5), img)
		"torch":
			_px_rect(s / 2 - 1, s / 2, 3, s / 2, Color(0.45, 0.3, 0.15), img)
			var flame_colors = [Color(1, 0.9, 0.1), Color(1, 0.55, 0.05), Color(1, 0.25, 0.0)]
			for fi in range(3):
				_px_circle(s / 2, s / 3 + fi, 5 - fi, flame_colors[fi], img)
			_px(s / 2, 1, Color(1, 1, 0.7), img)
		"workbench":
			var wb = Color(0.5, 0.35, 0.2)
			img.fill(wb)
			_px_rect(2, s - 6, s - 4, 4, wb.darkened(0.2), img)
			_px_rect(3, 3, 3, s - 8, wb.darkened(0.15), img)
			_px_rect(s - 6, 3, 3, s - 8, wb.darkened(0.15), img)
			_px_rect(s / 2 - 3, 5, 6, 3, Color(0.6, 0.6, 0.6), img)
		"furnace":
			var fc = Color(0.35, 0.33, 0.38)
			img.fill(fc)
			_px_rect(3, 2, s - 6, s - 6, fc, img)
			_px_rect(4, 4, s - 8, s - 8, fc.lightened(0.1), img)
			_px_rect(s / 2 - 3, s / 2 - 2, 6, 6, Color(1, 0.4, 0.05), img)
			_px_rect(s / 2 - 2, s / 2 - 1, 4, 4, Color(1, 0.7, 0.1), img)
			_px_rect(s / 2 - 1, s / 2, 2, 2, Color(1, 0.95, 0.5), img)
		"anvil":
			var ac = Color(0.22, 0.22, 0.28)
			img.fill(ac)
			_px_rect(4, s - 8, s - 8, 4, ac, img)
			_px_rect(6, s - 10, s - 12, 3, ac.lightened(0.1), img)
			_px_rect(s / 2 - 2, s - 14, 5, 5, ac.lightened(0.15), img)
		_:
			img.fill(Color.GRAY)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

# ========== 物品图标 ==========

static func get_item_icon(item_id: String) -> ImageTexture:
	var key = "icon_%s" % item_id
	if _tex_cache.has(key): return _tex_cache[key]
	var s = 16; var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match item_id:
		"wood":
			_px_rect(4, 2, 8, 12, Color(0.55, 0.35, 0.15), img)
			for _i in range(3): _px(_rng.randi_range(4, 11), _rng.randi_range(4, 10), Color(0.45, 0.28, 0.12), img)
		"stone":
			_px_circle(8, 8, 6, Color(0.55, 0.52, 0.5), img)
			_px(6, 5, Color(0.7, 0.68, 0.65), img); _px(10, 11, Color(0.4, 0.38, 0.35), img)
		"copper_ore":
			_px_circle(8, 8, 6, Color(0.75, 0.45, 0.2), img)
			_px(5, 6, Color(0.95, 0.65, 0.25), img); _px(10, 9, Color(0.95, 0.55, 0.2), img)
		"iron_ore":
			_px_circle(8, 8, 6, Color(0.5, 0.45, 0.5), img)
			_px(4, 5, Color(0.7, 0.65, 0.7), img); _px(11, 10, Color(0.65, 0.6, 0.65), img)
		"copper_ingot":
			_px_rect(3, 5, 10, 4, Color(0.9, 0.55, 0.2), img)
			_px_rect(3, 5, 10, 1, Color(1, 0.7, 0.3), img); _px_rect(3, 8, 10, 1, Color(0.7, 0.4, 0.15), img)
		"iron_ingot":
			_px_rect(3, 5, 10, 4, Color(0.6, 0.58, 0.62), img)
			_px_rect(3, 5, 10, 1, Color(0.8, 0.78, 0.82), img); _px_rect(3, 8, 10, 1, Color(0.45, 0.43, 0.47), img)
		"fiber":
			for x in range(3): _px_rect(5 + x * 2, 1, 2, 14, Color(0.25, 0.7, 0.2), img)
			_px(6, 6, Color(0.3, 0.8, 0.25), img); _px(9, 5, Color(0.35, 0.75, 0.25), img)
		"herb_red":
			for d in [Vector2(0,-1), Vector2(1,0), Vector2(0,1), Vector2(-1,0)]:
				for j in range(1, 4): _px(8 + int(d.x * j), 8 + int(d.y * j), Color(0.85, 0.2, 0.35), img)
			_px(8, 8, Color(0.6, 0.1, 0.25), img)
		"clay":
			_px_circle(8, 8, 5, Color(0.6, 0.5, 0.4), img)
			for _ni in range(5): _px(_rng.randi_range(3, 12), _rng.randi_range(3, 12), Color(0.5, 0.4, 0.3), img)
		"wooden_pickaxe":
			_px_rect(7, 1, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(5, 8, 7, 3, Color(0.65, 0.45, 0.2), img)
			_px_rect(5, 11, 3, 2, Color(0.65, 0.45, 0.2), img)
		"stone_pickaxe":
			_px_rect(7, 1, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(5, 8, 7, 3, Color(0.55, 0.5, 0.45), img)
			_px_rect(5, 11, 3, 2, Color(0.55, 0.5, 0.45), img)
		"copper_pickaxe":
			_px_rect(7, 1, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(5, 8, 7, 3, Color(0.9, 0.55, 0.2), img)
			_px_rect(5, 11, 3, 2, Color(0.9, 0.55, 0.2), img)
		"iron_pickaxe":
			_px_rect(7, 1, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(5, 8, 7, 3, Color(0.6, 0.58, 0.62), img)
			_px_rect(5, 11, 3, 2, Color(0.6, 0.58, 0.62), img)
		"wooden_axe":
			_px_rect(7, 0, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(3, 8, 10, 4, Color(0.65, 0.45, 0.2), img)
		"stone_axe":
			_px_rect(7, 0, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(3, 8, 10, 4, Color(0.55, 0.5, 0.45), img)
		"copper_axe":
			_px_rect(7, 0, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(3, 8, 10, 4, Color(0.9, 0.55, 0.2), img)
		"iron_axe":
			_px_rect(7, 0, 3, 12, Color(0.55, 0.35, 0.15), img)
			_px_rect(3, 8, 10, 4, Color(0.6, 0.58, 0.62), img)
		"wooden_sword":
			_px_rect(7, 0, 3, 10, Color(0.65, 0.6, 0.55), img)
			_px_rect(6, 10, 5, 2, Color(0.55, 0.35, 0.15), img)
			_px_rect(7, 12, 3, 3, Color(0.55, 0.35, 0.15), img)
		"stone_sword":
			_px_rect(7, 0, 3, 10, Color(0.55, 0.5, 0.45), img)
			_px_rect(6, 10, 5, 2, Color(0.55, 0.35, 0.15), img)
			_px_rect(7, 12, 3, 3, Color(0.55, 0.35, 0.15), img)
		"iron_sword":
			_px_rect(7, 0, 3, 10, Color(0.6, 0.58, 0.62), img)
			_px_rect(6, 10, 5, 2, Color(0.55, 0.35, 0.15), img)
			_px_rect(7, 12, 3, 3, Color(0.55, 0.35, 0.15), img)
		"health_potion":
			_px_rect(5, 0, 6, 6, Color(1, 0.2, 0.3), img)
			_px_rect(6, 6, 4, 1, Color(0.7, 0.7, 0.7), img)
			_px_rect(7, 7, 2, 2, Color(0.7, 0.7, 0.7), img)
			_px(8, 3, Color(1, 0.5, 0.5), img)
		"bandage":
			_px_rect(2, 4, 12, 8, Color(0.9, 0.85, 0.75), img)
			_px_rect(3, 5, 11, 1, Color(0.85, 0.8, 0.7), img)
			_px_rect(3, 9, 11, 1, Color(0.85, 0.8, 0.7), img)
		"wood_floor":
			_px_rect(0, 0, 16, 16, Color(0.55, 0.38, 0.22), img)
			for y in range(4, 16, 6): _px_rect(0, y, 16, 1, Color(0.45, 0.3, 0.17), img)
		"stone_floor":
			_px_rect(0, 0, 16, 16, Color(0.5, 0.5, 0.52), img)
			for y in range(0, 16, 6):
				for x in range(0, 16, 6):
					_px(x + 5, y, Color(0.4, 0.4, 0.42), img); _px(x, y + 5, Color(0.4, 0.4, 0.42), img)
		"wood_wall":
			_px_rect(0, 0, 16, 16, Color(0.4, 0.28, 0.15), img)
			for x in range(5, 16, 6): _px_rect(x, 0, 1, 16, Color(0.3, 0.2, 0.1), img)
		"stone_wall":
			_px_rect(0, 0, 16, 16, Color(0.38, 0.37, 0.4), img)
			for y in range(0, 16, 6):
				for x in range(0, 16, 6):
					_px(x + 5, y, Color(0.28, 0.27, 0.3), img); _px(x, y + 5, Color(0.28, 0.27, 0.3), img)
		"wooden_chest":
			_px_rect(1, 1, 14, 14, Color(0.6, 0.35, 0.15), img)
			_px_rect(4, 3, 8, 3, Color(0.7, 0.7, 0.2), img)
			_px_rect(7, 4, 3, 3, Color(0.5, 0.5, 0.5), img)
		"torch":
			_px_rect(7, 7, 3, 8, Color(0.45, 0.3, 0.15), img)
			_px_circle(8, 5, 4, Color(1, 0.55, 0.05), img)
			_px_circle(8, 4, 2, Color(1, 0.9, 0.1), img)
		"workbench":
			_px_rect(1, 1, 14, 14, Color(0.5, 0.35, 0.2), img)
			_px_rect(2, 10, 12, 4, Color(0.4, 0.27, 0.15), img)
			_px_rect(3, 4, 3, 8, Color(0.4, 0.27, 0.15), img)
			_px_rect(10, 4, 3, 8, Color(0.4, 0.27, 0.15), img)
		"furnace":
			_px_rect(1, 1, 14, 14, Color(0.35, 0.33, 0.38), img)
			_px_rect(4, 4, 8, 8, Color(0.28, 0.26, 0.3), img)
			_px_rect(6, 6, 4, 4, Color(1, 0.4, 0.05), img)
		"anvil":
			_px_rect(2, 1, 12, 6, Color(0.22, 0.22, 0.28), img)
			_px_rect(3, 7, 10, 3, Color(0.18, 0.18, 0.22), img)
			_px_rect(4, 10, 8, 4, Color(0.18, 0.18, 0.22), img)
		"backpack_expander":
			_px_rect(2, 1, 12, 11, Color(0.4, 0.3, 0.5), img)
			_px_rect(3, 2, 10, 3, Color(0.5, 0.4, 0.6), img)
			_px(8, 7, Color(1, 0.85, 0.3), img); _px(9, 7, Color(1, 0.85, 0.3), img)
		"teleport_stone":
			_px_circle(8, 8, 6, Color(0.3, 0.2, 0.5), img)
			_px_circle(8, 8, 3, Color(0.5, 0.3, 0.8), img)
			_px(8, 8, Color(0.8, 0.5, 1), img)
		_:
			_px_rect(2, 2, 12, 12, Color(0.5, 0.5, 0.5), img)
			_px_rect(3, 3, 10, 10, Color(0.6, 0.6, 0.6), img)
	var tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

# ========== TileSet ==========

static func make_tileset() -> TileSet:
	var ts = TileSet.new()
	for i in range(3):
		var tex = get_grass_tile(i)
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		ts.add_source(src, i)
	return ts
```

- [ ] **Step 2: 从 kingdom_echoes.gd 删除纹理代码**

Remove lines 87-413 (from `# ========== 像素贴图生成 ==========` through `return ts` in `_make_tileset`) and lines 1322-1455 (`_make_item_icon`).

- [ ] **Step 3: 更新 kingdom_echoes.gd 中的调用点**

Replace all `_make_*` calls with `TextureGen.get_*`:
- `_make_grass_tile(i)` → `TextureGen.get_grass_tile(i)`
- `_make_tree_texture()` → `TextureGen.get_tree_texture()`
- `_make_stump_texture()` → `TextureGen.get_stump_texture()`
- `_make_stone_texture()` → `TextureGen.get_stone_texture()`
- `_make_ore_texture(a, b)` → `TextureGen.get_ore_texture(a, b)`
- `_make_herb_texture()` → `TextureGen.get_herb_texture()`
- `_make_fiber_texture()` → `TextureGen.get_fiber_texture()`
- `_make_player_texture()` → `TextureGen.get_player_texture()`
- `_make_block_texture(id)` → `TextureGen.get_block_texture(id)`
- `_make_item_icon(id)` → `TextureGen.get_item_icon(id)`
- `_make_tileset()` → `TextureGen.make_tileset()`

- [ ] **Step 4: 编译验证**

Run: `/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"`
Expected: Zero errors

- [ ] **Step 5: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add scripts/game/texture_gen.gd scripts/game/kingdom_echoes.gd
git commit -m "refactor: 提取 TextureGen 静态纹理工厂 — 500行纹理+图标代码独立"
```

---

### Task 3: Create HUDController — HUD 系统

**Files:**
- Create: `scripts/game/hud_controller.gd`
- Modify: `scripts/game/kingdom_echoes.gd`

**Purpose:** 将 HUD 创建、更新、面板管理代码（~500行）提取为独立 controller。

**Extracted functions (from kingdom_echoes.gd):**
- `_create_hud` (lines 518-685) → `create()`
- `_update_hud` (lines 1487-1553) → split into `update()` + `refresh_slots()`
- `_toggle_inventory` (lines 1072-1088) → `toggle_inventory()`
- `_set_hint` (lines 1090-1092) → `set_hint()`
- `_close_all_panels` (lines 1094-1110) → `close_all()`
- `_update_hotbar_selection` (lines 1112-1118) → `update_hotbar_selection()`
- `_refresh_craft_buttons` (lines 980-1046) → `refresh_craft_buttons()`
- `_on_station_changed` (lines 1048-1050) → `_on_station_changed()`
- `_on_craft_button` (lines 1053-1067) → `_on_craft_button()`
- `_count_item` (lines 1458-1466) → `_count_item()`

**Extracted state variables (from kingdom_echoes.gd):**
- Lines 37-55: all HUD element references
- Line 30: `inventory_open`
- Line 31: `craft_open`
- Line 32: `current_station`
- Line 33: `stations_unlocked`
- Line 34: `hotbar_selected`

- [ ] **Step 1: Write hud_controller.gd**

Given the size, this will be a separate file. Key design decisions:
- HUDController extends RefCounted (not Node — doesn't need _process)
- Constructor takes: `hud: CanvasLayer`, `item_manager: ItemManager`, `player: CharacterBody2D`, `time_system: TimeSystem`, `resource_sprites: Dictionary`, `resource_data: Dictionary`, `crafting_manager: CraftingManager`, `world_constants: Dictionary` (TILE_SIZE, WORLD_TILES_X, WORLD_TILES_Y) + a `spawn_text: Callable` for floating text
- Adds `inventory_dirty: bool` flag for lazy icon refresh
- `update()` does lightweight updates (time/position/nearby). `refresh_slots()` handles icon textures only when dirty.

(See full code in the created file — ~500 lines, too long for inline task step. The file content = extracted functions with minimal refactoring for member variable access.)

- [ ] **Step 2: Update kingdom_echoes.gd — remove extracted code, add controller wiring**

In `_ready`, create HUDController:
```gdscript
hud_controller = HUDController.new()
hud_controller.setup(
	get_node("HUD"),
	item_manager,
	player,
	time_system,
	resource_sprites,
	resource_data,
	crafting_manager,
	{"TILE_SIZE": TILE_SIZE},
	_spawn_floating_text
)
hud_controller.create()
```

Move `_input` to delegate HUD events:
```gdscript
if event.is_action_pressed("craft"):
    hud_controller.toggle_craft()
if event.is_action_pressed("inventory"):
    hud_controller.toggle_inventory()
# etc.
```

- [ ] **Step 3: 编译验证**

Run compilation check. Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/game/hud_controller.gd scripts/game/kingdom_echoes.gd
git commit -m "refactor: 提取 HUDController — 500行HUD创建/更新/面板管理独立"
```

---

### Task 4: Create HarvestController — 采集系统

**Files:**
- Create: `scripts/game/harvest_controller.gd`
- Modify: `scripts/game/kingdom_echoes.gd`

**Purpose:** 提取采集逻辑（~250行）为独立 controller。

**Extracted functions:**
- `_find_nearest_resource`, `_start_harvest`, `_update_harvest`, `_cancel_harvest`, `_complete_harvest`
- `_add_to_hotbar_first`, `_get_best_tool_tier`, `_find_best_tool`, `_consume_tool_durability`

**Extracted state:**
- `harvesting`, `harvest_target_id`, `harvest_progress`, `harvest_duration`

**Design:**
- Extends RefCounted
- Constructor: `player`, `resource_sprites`, `resource_data`, `item_manager`, `hud_controller` (for bar show/update)
- Signal: `harvest_completed(item_id: String, qty: int)`
- `try_harvest()` → returns bool
- `update(delta)` → advances progress, updates bar via HUDController
- `cancel()` → resets state, hides bar

- [ ] **Step 1: Write harvest_controller.gd**

~250 lines. Key interface:
```gdscript
extends RefCounted
class_name HarvestController

signal harvest_completed(item_id: String, qty: int)

var player: CharacterBody2D
var resource_sprites: Dictionary
var resource_data: Dictionary
var item_manager: ItemManager
var hud_controller: HUDController

var _harvesting: bool = false
var _harvest_target_id: String = ""
var _harvest_progress: float = 0.0
var _harvest_duration: float = 1.5

func setup(p, rs, rd, im, hc) -> void:
    player = p; resource_sprites = rs; resource_data = rd
    item_manager = im; hud_controller = hc

func try_harvest() -> bool: ...
func update(delta: float) -> void: ...
func cancel() -> void: ...
func is_harvesting() -> bool: return _harvesting
func get_progress() -> float: return _harvest_progress
```

- [ ] **Step 2: Update kingdom_echoes.gd**

Replace harvest logic section with harvest_controller delegation.

- [ ] **Step 3: 编译验证**

- [ ] **Step 4: Commit**

---

### Task 5: Create BuildController — 建造系统

**Files:**
- Create: `scripts/game/build_controller.gd`
- Modify: `scripts/game/kingdom_echoes.gd`

**Purpose:** 提取建造逻辑（~300行），同时修复 B1（幽灵预览纹理重建）。

**Extracted functions:**
- `_toggle_build_mode`, `_get_available_blocks`, `_refresh_build_selection`, `_select_block`
- `_is_mouse_over_build_bar`, `_cycle_block_selection`, `_update_ghost_preview`
- `_try_place_block`, `_try_remove_block`

**Extracted state:**
- `build_mode`, `selected_block_item`, `ghost_sprite`, `placed_blocks`
- `build_bar`, `build_buttons`, `build_label`

**Bug B1 fix:** In `_update_ghost_preview`, replace:
```gdscript
var img = TextureGen.get_block_texture(selected_block_item).get_image()
ghost_sprite.texture = ImageTexture.create_from_image(img)
```
with:
```gdscript
ghost_sprite.texture = TextureGen.get_block_texture(selected_block_item)
```

**Bug B2 fix:** HUDController's `update()` no longer sets icon textures every frame. Only `refresh_slots()` (called when `inventory_dirty` is true) sets them. Mark dirty on: harvest complete, craft complete, block place/remove, inventory toggle.

- [ ] **Step 1: Write build_controller.gd**

~300 lines. Includes B1 fix inline.

- [ ] **Step 2: Update kingdom_echoes.gd**

Wire build_controller, remove extracted code.

- [ ] **Step 3: Ensure B2 dirty flag integration**

In kingdom_echoes.gd `_process`:
```gdscript
if build_mode:
	build_controller.update_preview()
hud_controller.update()
if hud_controller.inventory_dirty:
	hud_controller.refresh_slots()
```

Mark dirty in harvest complete handler, craft complete handler, block place/remove.

- [ ] **Step 4: 编译验证**

- [ ] **Step 5: Commit**

---

### Task 6: 精简 kingdom_echoes.gd + 最终验证

**Files:**
- Modify: `scripts/game/kingdom_echoes.gd`

**Final main file responsibilities (~250 lines):**
- Constants: WORLD_TILES_X, WORLD_TILES_Y, TILE_SIZE
- Scene setup: `_build_ground`, `_spawn_resources`, `_create_player`, `_setup_camera`, `_init_systems`
- Controller creation + wiring
- `_process`: movement input → camera follow → harvest update → time system → build preview → HUD update
- `_input`: event dispatch to controllers
- `_spawn_floating_text` (utility)
- `move_speed`

- [ ] **Step 1: Rewrite kingdom_echoes.gd**

Remove all extracted code, add clean wiring.

- [ ] **Step 2: Final compile + launch test**

```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"
```
Expected: Zero errors beyond export preset warnings.

- [ ] **Step 3: 运行游戏验证行为一致**

Launch editor: 
```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --editor /Users/wxb/cc/_active/kingdom-echoes/project.godot &
```
Manual test: WASD移动、J采集、B背包、C制造、V建造 — all should work identically.

- [ ] **Step 4: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add -A
git commit -m "refactor: Phase A 完成 — 1553行拆分为5模块 + B1/B2修复"
```
