extends RefCounted
class_name WorldGenerator

## 世界生成器 — 噪声群落分布 + TileSet构建 + 资源/装饰放置

const BIOME_GRASS: int = 0
const BIOME_DIRT: int = 1
const BIOME_SAND: int = 2
const BIOME_SNOW: int = 3
const BIOME_SWAMP: int = 4
const BIOME_FOREST: int = 5
const BIOME_STONE: int = 6
const BIOME_WATER: int = 7

const BIOME_IDS: Array[String] = ["grass", "dirt", "sand", "snow", "swamp", "forest_floor", "stone_path", "water"]

var _rng: RandomNumberGenerator
var _tile_size: int
var _world_w: int
var _world_h: int

var biome_grid: Array = []           # biome_grid[y][x] = int (biome constant)
var resource_sprites: Dictionary = {}
var resource_data: Dictionary = {}
var decoration_nodes: Array = []

var _biome_configs: Array[Dictionary] = []
var _resource_defs: Array[Dictionary] = []
var _decoration_defs: Array[Dictionary] = []


func setup(rng: RandomNumberGenerator, tile_size: int, world_w: int, world_h: int) -> void:
	_rng = rng
	_tile_size = tile_size
	_world_w = world_w
	_world_h = world_h


func set_biome_configs(configs: Array[Dictionary]) -> void:
	_biome_configs = configs


func set_resource_defs(defs: Array[Dictionary]) -> void:
	_resource_defs = defs


func set_decoration_defs(defs: Array[Dictionary]) -> void:
	_decoration_defs = defs


func get_biome_at(grid_x: int, grid_y: int) -> String:
	if grid_x < 0 or grid_y < 0 or grid_x >= _world_w or grid_y >= _world_h:
		return ""
	var b = biome_grid[grid_y][grid_x] if grid_y < biome_grid.size() else -1
	if b >= 0 and b < BIOME_IDS.size():
		return BIOME_IDS[b]
	return ""


# ========== 噪声生成 ==========

func _generate_biome_grid() -> void:
	biome_grid.clear()

	# FastNoiseLite — Simplex 2D
	var noise = FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.015
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	for y in range(_world_h):
		var row: Array[int] = []
		var lat = (float(y) / _world_h) * 2.0 - 1.0  # [-1, 1]

		# 纬度偏置
		var lat_bias: float
		if lat < -0.3:
			lat_bias = lerpf(0.3, 1.0, (lat + 0.3) / -0.7)   # 高纬：雪地+石路
		elif lat > 0.3:
			lat_bias = lerpf(-0.3, -1.0, (lat - 0.3) / 0.7)   # 低纬：沙漠+水+沼泽
		else:
			lat_bias = 0.0                                        # 中纬：均匀

		for x in range(_world_w):
			var n = noise.get_noise_2d(float(x), float(y))  # [-1, 1]
			var score = n * 0.6 + lat_bias * 0.4              # 混合
			score = clampf((score + 1.0) / 2.0, 0.0, 0.999) # 映射到 [0, 1)

			var biome: int
			if score < 0.05:
				biome = BIOME_WATER
			elif score < 0.15:
				biome = BIOME_SAND
			elif score < 0.28:
				biome = BIOME_SWAMP
			elif score < 0.40:
				biome = BIOME_DIRT
			elif score < 0.58:
				biome = BIOME_GRASS
			elif score < 0.72:
				biome = BIOME_FOREST
			elif score < 0.85:
				biome = BIOME_STONE
			else:
				biome = BIOME_SNOW
			row.append(biome)
		biome_grid.append(row)

	# 边界过渡带：±1 格内 50% 用邻居群落
	_blend_edges()


func _blend_edges() -> void:
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(_world_h):
		for x in range(_world_w):
			var me = biome_grid[y][x]
			var blend = false
			for d in dirs:
				var nx = x + d.x; var ny = y + d.y
				if nx >= 0 and ny >= 0 and nx < _world_w and ny < _world_h:
					if biome_grid[ny][nx] != me:
						blend = true
						break
			if blend and _rng.randf() < 0.5:
				var valid: Array[int] = []
				for d in dirs:
					var nx = x + d.x; var ny = y + d.y
					if nx >= 0 and ny >= 0 and nx < _world_w and ny < _world_h:
						var nb = biome_grid[ny][nx]
						if nb != me and nb not in valid:
							valid.append(nb)
				if not valid.is_empty():
					biome_grid[y][x] = valid[_rng.randi_range(0, valid.size() - 1)]


# ========== TileSet + TileMap ==========

func _build_tilemap() -> TileMap:
	var tile_set = _build_tileset()

	var tm = TileMap.new()
	tm.name = "Ground"
	tm.tile_set = tile_set

	for y in range(_world_h):
		for x in range(_world_w):
			var biome = biome_grid[y][x]
			if biome < 0 or biome >= _biome_configs.size():
				continue
			var variant_count = _biome_configs[biome].get("variant_count", 1)
			var v = _rng.randi_range(0, variant_count - 1) if variant_count > 1 else 0
			tm.set_cell(0, Vector2i(x, y), biome, Vector2i(v, 0))

	return tm


func _build_tileset() -> TileSet:
	var ts = TileSet.new()
	for i in range(_biome_configs.size()):
		var cfg = _biome_configs[i]
		var atlas_path = cfg.get("atlas_path", "")
		if atlas_path.is_empty():
			continue
		var tex: Texture2D = load(atlas_path)
		if tex == null:
			push_error("WorldGenerator: Failed to load atlas: %s" % atlas_path)
			continue
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(_tile_size, _tile_size)
		ts.add_source(src, i)
	return ts


# ========== 资源生成 ==========

func _spawn_resources(parent_node: Node2D) -> void:
	resource_sprites.clear()
	resource_data.clear()

	for d in _resource_defs:
		var biomes: Array = d.get("biomes", [])
		if biomes.is_empty():
			continue
		var density = d.get("density", 0.02)
		var tex = d.get("texture", null)
		if tex == null:
			push_warning("WorldGenerator: skipping resource '%s' — no texture" % d.get("id", "?"))
			continue

		for y in range(_world_h):
			for x in range(_world_w):
				var b = biome_grid[y][x]
				var biome_id = BIOME_IDS[b]
				if biome_id not in biomes:
					continue
				if _rng.randf() > density:
					continue

				var pos = Vector2(x * _tile_size + _tile_size / 2.0, y * _tile_size + _tile_size / 2.0)
				var id = "%s_%d_%d" % [d["id"], x, y]

				var sprite = Sprite2D.new()
				sprite.position = pos
				sprite.centered = true
				sprite.texture = tex
				sprite.z_index = d.get("z_index", 1)
				parent_node.add_child(sprite)

				resource_sprites[id] = sprite
				resource_data[id] = {
					"name": d.get("name", d["id"]),
					"item_id": d["item"],
					"quantity": d.get("qty", 1),
					"harvest_type": d.get("harvest_type", -1),
					"tool_tier": d.get("tool_tier", 0),
					"depleted": false,
				}


# ========== 装饰物 ==========

func _spawn_decorations(parent_node: Node2D) -> void:
	decoration_nodes.clear()

	for d in _decoration_defs:
		var biomes: Array = d.get("biomes", [])
		if biomes.is_empty():
			continue
		var density = d.get("density", 0.03)
		var tex = d.get("texture", null)
		if tex == null:
			push_warning("WorldGenerator: skipping decoration '%s' — no texture" % d.get("id", "?"))
			continue
		var z_idx = d.get("z_index", 2)

		for y in range(_world_h):
			for x in range(_world_w):
				var b = biome_grid[y][x]
				var biome_id = BIOME_IDS[b]
				if biome_id not in biomes:
					continue
				if _rng.randf() > density:
					continue

				var offset_x = _rng.randf_range(-_tile_size / 3.0, _tile_size / 3.0)
				var offset_y = _rng.randf_range(-_tile_size / 3.0, _tile_size / 3.0)
				var pos = Vector2(x * _tile_size + _tile_size / 2.0 + offset_x, y * _tile_size + _tile_size / 2.0 + offset_y)

				var sprite = Sprite2D.new()
				sprite.position = pos
				sprite.centered = true
				sprite.texture = tex
				sprite.z_index = z_idx
				parent_node.add_child(sprite)
				decoration_nodes.append(sprite)


# ========== 入口 ==========

func generate(parent_node: Node2D) -> void:
	assert(_rng != null, "WorldGenerator: setup() must be called before generate()")
	_generate_biome_grid()
	var tilemap = _build_tilemap()
	parent_node.add_child(tilemap)
	_spawn_resources(parent_node)
	_spawn_decorations(parent_node)
