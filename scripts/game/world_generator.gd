extends RefCounted
class_name WorldGenerator

## 世界生成器 — 无限地图：按 chunk 加载/卸载，噪声群落 + 资源 + 装饰

const BIOME_GRASS: int = 0
const BIOME_DIRT: int = 1
const BIOME_SAND: int = 2
const BIOME_SNOW: int = 3
const BIOME_SWAMP: int = 4
const BIOME_FOREST: int = 5
const BIOME_STONE: int = 6
const BIOME_WATER: int = 7

const BIOME_IDS: Array[String] = ["grass", "dirt", "sand", "snow", "swamp", "forest_floor", "stone_path", "water"]

const CHUNK_SIZE: int = 16  # 每 chunk 16×16 格

var _rng: RandomNumberGenerator
var _tile_size: int
var _world_seed: int

var _noise: FastNoiseLite = null
var _active_chunks: Dictionary = {}  # {Vector2i(cx, cy): TileMapLayer}
var resource_sprites: Dictionary = {}  # {id: Sprite2D} — 公开，主游戏引用
var resource_data: Dictionary = {}     # {id: {name, item_id, ...}} — 公开
var _decoration_nodes_by_chunk: Dictionary = {}

var _biome_configs: Array[Dictionary] = []
var _resource_defs: Array[Dictionary] = []
var _decoration_defs: Array[Dictionary] = []

var _terrain_node: Node2D = null
var _object_node: Node2D = null
var _cached_tileset: TileSet = null


func setup(rng: RandomNumberGenerator, tile_size: int, world_w: int = 0, world_h: int = 0) -> void:
	_rng = rng
	_tile_size = tile_size
	_world_seed = rng.randi()

	_noise = FastNoiseLite.new()
	_noise.seed = _world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.015
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5


func set_biome_configs(configs: Array[Dictionary]) -> void:
	_biome_configs = configs


func set_resource_defs(defs: Array[Dictionary]) -> void:
	_resource_defs = defs


func set_decoration_defs(defs: Array[Dictionary]) -> void:
	_decoration_defs = defs


## 给定世界坐标 (gx, gy)，返回群落索引（无状态、纯噪声计算）
func get_biome_at(gx: int, gy: int) -> int:
	var n = _noise.get_noise_2d(float(gx), float(gy))  # [-1, 1]
	var lat_bias = _lat_bias(gy)
	var score = n * 0.6 + lat_bias * 0.4
	score = clampf((score + 1.0) / 2.0, 0.0, 0.999)

	if score < 0.05:   return BIOME_WATER
	if score < 0.15:   return BIOME_SAND
	if score < 0.28:   return BIOME_SWAMP
	if score < 0.40:   return BIOME_DIRT
	if score < 0.58:   return BIOME_GRASS
	if score < 0.72:   return BIOME_FOREST
	if score < 0.85:   return BIOME_STONE
	return BIOME_SNOW


func get_biome_id_at(gx: int, gy: int) -> String:
	var b = get_biome_at(gx, gy)
	if b >= 0 and b < BIOME_IDS.size():
		return BIOME_IDS[b]
	return ""


static func world_position_to_cell(pos: Vector2, tile_size: int) -> Vector2i:
	return Vector2i(floori(pos.x / tile_size), floori(pos.y / tile_size))


static func cell_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / CHUNK_SIZE),
		floori(float(cell.y) / CHUNK_SIZE)
	)


static func world_position_to_chunk(pos: Vector2, tile_size: int) -> Vector2i:
	return cell_to_chunk(world_position_to_cell(pos, tile_size))


## 纬度偏置：高纬→雪/石，低纬→沙/水/沼泽
func _lat_bias(gy: int, world_h: int = 1200) -> float:
	var lat = (float(gy) / world_h) * 2.0 - 1.0  # [-1, 1]
	if lat < -0.3:
		return lerpf(0.3, 1.0, (lat + 0.3) / -0.7)
	elif lat > 0.3:
		return lerpf(-0.3, -1.0, (lat - 0.3) / 0.7)
	return 0.0


# ========== Chunk 管理 ==========

## 初始化：存储父节点引用
func init_chunks(terrain_node: Node2D, object_node: Node2D = null) -> void:
	_terrain_node = terrain_node
	_object_node = object_node if object_node else terrain_node


## 生成一个 chunk 的 TileMapLayer（如果还没加载）
func generate_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)
	if _active_chunks.has(key):
		return

	var tm = _build_chunk_tilemap(cx, cy)
	_terrain_node.add_child(tm)
	_active_chunks[key] = tm

	_spawn_resources_in_chunk(cx, cy)
	_spawn_decorations_in_chunk(cx, cy)


## 卸载一个 chunk
func unload_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)
	if not _active_chunks.has(key):
		return
	var tm: TileMapLayer = _active_chunks[key]

	# 卸载该 chunk 内的资源
	var prefix = "%d_%d_" % [cx, cy]
	var to_remove: Array[String] = []
	for id in resource_sprites:
		if id.begins_with(prefix):
			to_remove.append(id)
	for id in to_remove:
		var sp: Sprite2D = resource_sprites[id]
		sp.queue_free()
		resource_sprites.erase(id)
		resource_data.erase(id)

	if _decoration_nodes_by_chunk.has(key):
		for node in _decoration_nodes_by_chunk[key]:
			if is_instance_valid(node):
				node.queue_free()
		_decoration_nodes_by_chunk.erase(key)

	tm.queue_free()
	_active_chunks.erase(key)


## 卸载所有 chunk
func unload_all_chunks() -> void:
	for key in _active_chunks.keys():
		unload_chunk(key.x, key.y)


# ========== Chunk TileMapLayer 构建 ==========

func _build_chunk_tilemap(cx: int, cy: int) -> TileMapLayer:
	var ts = _build_tileset()
	var tm = TileMapLayer.new()
	tm.name = "Chunk_%d_%d" % [cx, cy]
	tm.tile_set = ts

	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	tm.position = Vector2(base_x * _tile_size, base_y * _tile_size)

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var gx = base_x + x
			var gy = base_y + y
			var biome = get_biome_at(gx, gy)
			if biome < 0 or biome >= _biome_configs.size():
				continue
			var variant_count = _biome_configs[biome].get("variant_count", 1)
			var v = _tile_variant(gx, gy, variant_count)
			tm.set_cell(Vector2i(x, y), biome, Vector2i(v % 4, int(v / 4)))  # 4×4 atlas

	return tm


func _tile_variant(gx: int, gy: int, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	return posmod(hash("%d_%d_%d_tile" % [_world_seed, gx, gy]), variant_count)


func _chunk_seed(cx: int, cy: int, salt: String) -> int:
	return posmod(hash("%d_%d_%s_%d" % [cx, cy, salt, _world_seed]), 2147483647)


func _build_tileset() -> TileSet:
	if _cached_tileset:
		return _cached_tileset
	var ts = TileSet.new()
	ts.tile_size = Vector2i(_tile_size, _tile_size)
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
		var variant_count = cfg.get("variant_count", 1)
		for v in range(variant_count):
			src.create_tile(Vector2i(v % 4, int(v / 4)))
		ts.add_source(src, i)
	_cached_tileset = ts
	return ts


# ========== 资源 & 装饰 (按 chunk) ==========

func _spawn_resources_in_chunk(cx: int, cy: int) -> void:
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE

	# 确定性 RNG — 同 chunk 同种子
	var chunk_rng = RandomNumberGenerator.new()
	chunk_rng.seed = _chunk_seed(cx, cy, "res")

	for d in _resource_defs:
		var biomes: Array = d.get("biomes", [])
		if biomes.is_empty():
			continue
		var density = d.get("density", 0.02)
		var tex = d.get("texture", null)
		if tex == null:
			continue

		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var gx = base_x + x
				var gy = base_y + y
				var biome_id = get_biome_id_at(gx, gy)
				if biome_id not in biomes:
					continue
				if chunk_rng.randf() > density:
					continue

				var pos = Vector2(gx * _tile_size + _tile_size / 2.0, gy * _tile_size + _tile_size / 2.0)
				var id = "%d_%d_%s_%d_%d" % [cx, cy, d["id"], x, y]

				var sprite = Sprite2D.new()
				sprite.position = pos
				sprite.centered = true
				sprite.texture = tex
				sprite.z_index = d.get("z_index", 1)
				var s = d.get("scale", 1.0)
				sprite.scale = Vector2(s, s)
				_object_node.add_child(sprite)

				resource_sprites[id] = sprite
				resource_data[id] = {
					"name": d.get("name", d["id"]),
					"item_id": d["item"],
					"quantity": d.get("qty", 1),
					"harvest_type": d.get("harvest_type", -1),
					"tool_tier": d.get("tool_tier", 0),
					"depleted": false,
				}


func _spawn_decorations_in_chunk(cx: int, cy: int) -> void:
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	var chunk_key = Vector2i(cx, cy)
	var chunk_nodes: Array[Node] = []

	var chunk_rng = RandomNumberGenerator.new()
	chunk_rng.seed = _chunk_seed(cx, cy, "dec")

	for d in _decoration_defs:
		var biomes: Array = d.get("biomes", [])
		if biomes.is_empty():
			continue
		var density = d.get("density", 0.03)
		var tex = d.get("texture", null)
		if tex == null:
			continue
		var z_idx = d.get("z_index", 2)

		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var gx = base_x + x
				var gy = base_y + y
				var biome_id = get_biome_id_at(gx, gy)
				if biome_id not in biomes:
					continue
				if chunk_rng.randf() > density:
					continue

				var offset_x = chunk_rng.randf_range(-_tile_size / 3.0, _tile_size / 3.0)
				var offset_y = chunk_rng.randf_range(-_tile_size / 3.0, _tile_size / 3.0)
				var pos = Vector2(gx * _tile_size + _tile_size / 2.0 + offset_x, gy * _tile_size + _tile_size / 2.0 + offset_y)

				var sprite = Sprite2D.new()
				sprite.position = pos
				sprite.centered = true
				sprite.texture = tex
				sprite.z_index = z_idx
				var ds = d.get("scale", 1.0)
				sprite.scale = Vector2(ds, ds)
				_object_node.add_child(sprite)
				chunk_nodes.append(sprite)

	if not chunk_nodes.is_empty():
		_decoration_nodes_by_chunk[chunk_key] = chunk_nodes
