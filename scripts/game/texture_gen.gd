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
