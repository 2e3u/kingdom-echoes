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
# 默认植被间距系数：>1 让泊松散布的植被间距变大、密度降低。
# 作为地被植被(花/草/树枝/石头等)的缺省"点缀级"稀疏度；3.0 ≈ 数量降到原来的约 1/9。
# 单个植被可在自身定义里用 "spacing_scale" 覆盖此默认值（例如树木用更小的值保持茂密）。
var vegetation_spacing_scale: float = 3.0  # 默认值；运行时由 OfflineGame 的 @export 覆盖
const OVERLAY_CELL_SIZE: int = 2
const TERRAIN_PAINT_GODOT_CONNECT: int = 0
const TERRAIN_PAINT_GLOBAL_NEIGHBORS: int = 1
const TERRAIN_MASK_LEFT: int = 1 << 0
const TERRAIN_MASK_BOTTOM_LEFT: int = 1 << 1
const TERRAIN_MASK_BOTTOM: int = 1 << 2
const TERRAIN_MASK_BOTTOM_RIGHT: int = 1 << 3
const TERRAIN_MASK_RIGHT: int = 1 << 4
const TERRAIN_MASK_TOP_RIGHT: int = 1 << 5
const TERRAIN_MASK_TOP: int = 1 << 6
const TERRAIN_MASK_TOP_LEFT: int = 1 << 7
const RIVER_DOMAIN_WARP: float = 42.0
const RIVER_MAIN_BASE_THRESHOLD: float = 0.0012
const RIVER_MAIN_THRESHOLD_VARIATION: float = 0.0019
const RIVER_BRANCH_BASE_THRESHOLD: float = 0.0007
const RIVER_BRANCH_THRESHOLD_VARIATION: float = 0.0010
const RIVER_BRANCH_PARENT_DISTANCE: float = 0.055
const RIVER_CHANNEL_RADIUS: int = 0
const RIVER_BRIDGE_MAX_GAP: int = 3
const RIVER_BASIN_WIDTH: int = 384
const RIVER_MAIN_HALF_WIDTH: float = 2.6
const RIVER_MAIN_WIDTH_VARIATION: float = 0.9
const RIVER_BRANCH_HALF_WIDTH: float = 0.95
const RIVER_BRANCH_WIDTH_VARIATION: float = 0.45
const RIVER_BRANCH_INTERVAL: int = 96
const RIVER_BRANCH_REACH_MIN: float = 96.0
const RIVER_BRANCH_REACH_MAX: float = 176.0
const RIVER_BRANCH_JOIN_CHANCE: float = 0.78

var _rng: RandomNumberGenerator
var _tile_size: int
var _world_seed: int

var _noise: FastNoiseLite = null
var _overlay_noise: FastNoiseLite = null
var _river_noise: FastNoiseLite = null
var _river_width_noise: FastNoiseLite = null
var _river_branch_noise: FastNoiseLite = null
var _river_warp_noise: FastNoiseLite = null
var _biome_noises: Array[FastNoiseLite] = []
var _ecology_noises: Dictionary = {}
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
var _terrain_tileset: TileSet = null
var _terrain_set: int = 0
var _base_terrain_id: int = -1
var _overlay_terrain_ids_by_biome: Dictionary = {}
var _full_terrain_tiles: Dictionary = {}
var _terrain_tiles_by_neighbor_mask: Dictionary = {}
var _overlay_uses_terrain_connect: bool = false
var _terrain_paint_mode: int = TERRAIN_PAINT_GODOT_CONNECT
var _river_terrain_id: int = -1
var _cluster_sample_cache: Dictionary = {}
var _region_noise_cache: Dictionary = {}
var _spawn_noise_cache: Dictionary = {}
var _direct_river_cell_cache: Dictionary = {}
var _river_cell_cache: Dictionary = {}
var _water_cell_cache: Dictionary = {}
var _river_bank_distance_cache: Dictionary = {}
var _main_river_distance_cache: Dictionary = {}
var _tributary_distance_cache: Dictionary = {}


func setup(rng: RandomNumberGenerator, tile_size: int, world_w: int = 0, world_h: int = 0) -> void:
	_rng = rng
	_tile_size = tile_size
	_world_seed = rng.randi()
	_direct_river_cell_cache.clear()
	_river_cell_cache.clear()
	_water_cell_cache.clear()
	_river_bank_distance_cache.clear()
	_main_river_distance_cache.clear()
	_tributary_distance_cache.clear()

	_noise = FastNoiseLite.new()
	_noise.seed = _world_seed
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.0048
	_noise.fractal_octaves = 5
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.52

	_biome_noises.clear()
	for i in range(BIOME_IDS.size()):
		var biome_noise = FastNoiseLite.new()
		biome_noise.seed = _world_seed + 1009 + i * 7919
		biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		biome_noise.frequency = 0.0075
		biome_noise.fractal_octaves = 4
		biome_noise.fractal_lacunarity = 2.0
		biome_noise.fractal_gain = 0.50
		_biome_noises.append(biome_noise)

	_overlay_noise = FastNoiseLite.new()
	_overlay_noise.seed = _world_seed + 137
	_overlay_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_overlay_noise.frequency = 0.018
	_overlay_noise.fractal_octaves = 4
	_overlay_noise.fractal_lacunarity = 2.0
	_overlay_noise.fractal_gain = 0.42

	_river_noise = FastNoiseLite.new()
	_river_noise.seed = _world_seed + 29017
	_river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_river_noise.frequency = 0.0042
	_river_noise.fractal_octaves = 5
	_river_noise.fractal_lacunarity = 2.0
	_river_noise.fractal_gain = 0.50

	_river_width_noise = FastNoiseLite.new()
	_river_width_noise.seed = _world_seed + 38011
	_river_width_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_river_width_noise.frequency = 0.013
	_river_width_noise.fractal_octaves = 3
	_river_width_noise.fractal_lacunarity = 2.0
	_river_width_noise.fractal_gain = 0.45

	_river_branch_noise = FastNoiseLite.new()
	_river_branch_noise.seed = _world_seed + 47017
	_river_branch_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_river_branch_noise.frequency = 0.0085
	_river_branch_noise.fractal_octaves = 4
	_river_branch_noise.fractal_lacunarity = 2.0
	_river_branch_noise.fractal_gain = 0.48

	_river_warp_noise = FastNoiseLite.new()
	_river_warp_noise.seed = _world_seed + 59023
	_river_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_river_warp_noise.frequency = 0.0035
	_river_warp_noise.fractal_octaves = 3
	_river_warp_noise.fractal_lacunarity = 2.0
	_river_warp_noise.fractal_gain = 0.52

	_ecology_noises = {
		"temperature": _create_ecology_noise(_world_seed + 3109, 0.0026, 4, 0.48),
		"moisture": _create_ecology_noise(_world_seed + 7127, 0.0032, 4, 0.52),
		"soil_depth": _create_ecology_noise(_world_seed + 11003, 0.0041, 3, 0.46),
	}


func set_biome_configs(configs: Array[Dictionary]) -> void:
	_biome_configs = configs


func set_resource_defs(defs: Array[Dictionary]) -> void:
	_resource_defs = defs


func set_decoration_defs(defs: Array[Dictionary]) -> void:
	_decoration_defs = defs


func set_terrain_tileset(tile_set: TileSet, terrain_set: int, terrain_ids_by_biome: Dictionary) -> void:
	_terrain_tileset = tile_set
	_terrain_set = terrain_set
	_force_corners_and_sides_terrain_mode()
	_base_terrain_id = -1
	_overlay_terrain_ids_by_biome = terrain_ids_by_biome
	_river_terrain_id = int(terrain_ids_by_biome.get(BIOME_WATER, -1))
	_overlay_uses_terrain_connect = true
	_rebuild_full_terrain_tiles()
	_cached_tileset = null


func set_layered_terrain_tileset(tile_set: TileSet, terrain_set: int, base_terrain_id: int, overlay_terrain_ids_by_biome: Dictionary, overlay_uses_terrain_connect: bool = false) -> void:
	_terrain_tileset = tile_set
	_terrain_set = terrain_set
	_force_corners_and_sides_terrain_mode()
	_base_terrain_id = base_terrain_id
	_overlay_terrain_ids_by_biome = overlay_terrain_ids_by_biome
	_river_terrain_id = int(overlay_terrain_ids_by_biome.get(BIOME_WATER, -1))
	_overlay_uses_terrain_connect = overlay_uses_terrain_connect
	_rebuild_full_terrain_tiles()
	_cached_tileset = null


func set_terrain_paint_mode(mode: int) -> void:
	if mode != TERRAIN_PAINT_GODOT_CONNECT and mode != TERRAIN_PAINT_GLOBAL_NEIGHBORS:
		push_warning("WorldGenerator: Unknown terrain paint mode: %d" % mode)
		return
	_terrain_paint_mode = mode


func _force_corners_and_sides_terrain_mode() -> void:
	if _terrain_tileset == null:
		return
	if _terrain_set < 0 or _terrain_set >= _terrain_tileset.get_terrain_sets_count():
		return
	if _terrain_tileset.get_terrain_set_mode(_terrain_set) != TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
		_terrain_tileset.set_terrain_set_mode(_terrain_set, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)


## 给定世界坐标 (gx, gy)，返回群落索引（温度×湿度 Whittaker 分类 + 纬度偏置）
func get_biome_at(gx: int, gy: int) -> int:
	var ecology = _sample_ecology_layers(gx, gy)
	var temp = ecology["temperature"] + _lat_bias(gy)
	ecology["temperature"] = clampf(temp, 0.0, 1.0)
	return _select_biome_for_ecology(ecology, gx, gy)


func _create_ecology_noise(seed: int, frequency: float, octaves: int, gain: float) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = gain
	return noise


func _sample_ecology_layers(gx: int, gy: int) -> Dictionary:
	var elevation = _sample_base_elevation(gx, gy)
	var local_relief = _sample_local_relief(gx, gy)
	var temperature = _normalized_ecology_noise("temperature", gx, gy)
	var moisture = _normalized_ecology_noise("moisture", gx, gy)
	var soil_depth = _normalized_ecology_noise("soil_depth", gx, gy)
	moisture = clampf(moisture + maxf(0.35 - elevation, 0.0) * 0.22 - maxf(elevation - 0.72, 0.0) * 0.18, 0.0, 1.0)
	soil_depth = clampf(soil_depth + moisture * 0.10 - elevation * 0.22 - absf(local_relief - 0.5) * 0.08, 0.0, 1.0)
	return {
		"temperature": temperature,
		"moisture": moisture,
		"soil_depth": soil_depth,
		"elevation": elevation,
	}


func _sample_base_elevation(gx: int, gy: int) -> float:
	if _noise == null:
		return 0.5
	var macro = (_noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	var relief = _sample_local_relief(gx, gy)
	return clampf((macro - 0.5) * 1.85 + 0.5 + (relief - 0.5) * 0.10, 0.0, 1.0)


func _sample_local_relief(gx: int, gy: int) -> float:
	if _overlay_noise == null:
		return 0.5
	return clampf((_overlay_noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5, 0.0, 1.0)


func _normalized_ecology_noise(layer: String, gx: int, gy: int) -> float:
	var noise: FastNoiseLite = _ecology_noises.get(layer, null)
	if noise == null:
		return 0.5
	var normalized = (noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	return clampf((normalized - 0.5) * 2.35 + 0.5, 0.0, 1.0)


func _select_biome_for_ecology(ecology: Dictionary, gx: int = 0, gy: int = 0) -> int:
	var best_biome = BIOME_GRASS
	var best_score = -INF
	for biome in range(BIOME_IDS.size()):
		var score = _score_biome_for_ecology(biome, ecology)
		score += _get_biome_patch_noise(biome, gx, gy)
		score += (_hash_float("macro_biome_jitter", gx, gy, biome) - 0.5) * 0.045
		if score > best_score:
			best_score = score
			best_biome = biome
	return best_biome


func _get_biome_patch_noise(biome: int, gx: int, gy: int) -> float:
	if biome < 0 or biome >= _biome_noises.size():
		return 0.0
	var noise: FastNoiseLite = _biome_noises[biome]
	if noise == null:
		return 0.0
	return noise.get_noise_2d(float(gx), float(gy)) * 0.085


func _score_biome_for_ecology(biome: int, ecology: Dictionary) -> float:
	var targets = _get_biome_ecology_targets(biome)
	var temperature = float(ecology.get("temperature", 0.5))
	var moisture = float(ecology.get("moisture", 0.5))
	var soil_depth = float(ecology.get("soil_depth", 0.5))
	var elevation = float(ecology.get("elevation", 0.5))
	var score = 1.0
	score -= absf(temperature - targets["temperature"]) * float(targets.get("temperature_weight", 1.0))
	score -= absf(moisture - targets["moisture"]) * float(targets.get("moisture_weight", 1.0))
	score -= absf(soil_depth - targets["soil_depth"]) * float(targets.get("soil_weight", 1.0))
	score -= absf(elevation - targets["elevation"]) * float(targets.get("elevation_weight", 1.0))
	return score + float(targets.get("bias", 0.0))


func _get_biome_ecology_targets(biome: int) -> Dictionary:
	match biome:
		BIOME_DIRT:
			return {"temperature": 0.68, "moisture": 0.22, "soil_depth": 0.30, "elevation": 0.50, "bias": -0.02}
		BIOME_SAND:
			return {"temperature": 0.84, "moisture": 0.10, "soil_depth": 0.18, "elevation": 0.42, "moisture_weight": 1.25, "elevation_weight": 0.65, "bias": 0.07}
		BIOME_SNOW:
			return {"temperature": 0.08, "moisture": 0.50, "soil_depth": 0.35, "elevation": 0.72, "temperature_weight": 1.55, "elevation_weight": 1.10, "bias": 0.02}
		BIOME_SWAMP:
			return {"temperature": 0.72, "moisture": 0.88, "soil_depth": 0.88, "elevation": 0.24, "moisture_weight": 1.3, "soil_weight": 1.15, "elevation_weight": 1.20, "bias": 0.02}
		BIOME_FOREST:
			return {"temperature": 0.48, "moisture": 0.72, "soil_depth": 0.82, "elevation": 0.46, "soil_weight": 1.15, "elevation_weight": 0.85, "bias": 0.01}
		BIOME_STONE:
			return {"temperature": 0.22, "moisture": 0.18, "soil_depth": 0.06, "elevation": 0.88, "soil_weight": 1.65, "elevation_weight": 2.00, "bias": 0.04}
		BIOME_WATER:
			return {"temperature": 0.50, "moisture": 0.96, "soil_depth": 0.50, "elevation": 0.08, "temperature_weight": 0.45, "moisture_weight": 1.85, "soil_weight": 0.25, "elevation_weight": 2.50, "bias": 0.02}
		_:
			return {"temperature": 0.55, "moisture": 0.50, "soil_depth": 0.55, "elevation": 0.44, "bias": -0.04}


func get_biome_id_at(gx: int, gy: int) -> String:
	var b = get_biome_at(gx, gy)
	if b >= 0 and b < BIOME_IDS.size():
		return BIOME_IDS[b]
	return ""


func is_water_cell(gx: int, gy: int) -> bool:
	var key = Vector2i(gx, gy)
	if _water_cell_cache.has(key):
		return bool(_water_cell_cache[key])
	var is_water = _is_river_cell(gx, gy) or get_biome_at(gx, gy) == BIOME_WATER
	_water_cell_cache[key] = is_water
	return is_water


func get_river_bank_distance(gx: int, gy: int, max_distance: int = 6) -> int:
	var cache_key = "%d_%d_%d" % [gx, gy, max_distance]
	if _river_bank_distance_cache.has(cache_key):
		return int(_river_bank_distance_cache[cache_key])
	if is_water_cell(gx, gy):
		_river_bank_distance_cache[cache_key] = 0
		return 0
	var search_radius = max(0, max_distance)
	for radius in range(1, search_radius + 1):
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				if max(abs(ox), abs(oy)) != radius:
					continue
				if is_water_cell(gx + ox, gy + oy):
					_river_bank_distance_cache[cache_key] = radius
					return radius
	_river_bank_distance_cache[cache_key] = search_radius + 1
	return search_radius + 1


func get_debug_ecology_value(layer: String, gx: int, gy: int) -> float:
	match layer:
		"temperature", "moisture", "soil_depth", "elevation":
			return float(_sample_ecology_layers(gx, gy).get(layer, 0.5))
		"forest_raw":
			return _get_region_noise_value(_get_forest_debug_region_noise(), gx, gy)
		"forest_suitability":
			return _get_shaped_region_spawn_multiplier(_get_forest_debug_region_noise(), gx, gy)
		"tree_density":
			var ecology = _sample_ecology_layers(gx, gy)
			var tree_preference = {"temperature": 0.48, "moisture": 0.66, "soil_depth": 0.80, "tolerance": 0.34, "min_multiplier": 0.08}
			var region = _get_shaped_region_spawn_multiplier(_get_forest_debug_region_noise(), gx, gy)
			var ecology_fit = _get_ecology_spawn_multiplier({"ecology": tree_preference}, ecology)
			return clampf(region * ecology_fit, 0.0, 1.0)
		_:
			return 0.0


func _get_forest_debug_region_noise() -> Dictionary:
	return {"group": "forest", "frequency": 0.018, "threshold": 0.54, "softness": 0.105, "power": 1.45, "octaves": 4, "gain": 0.56}


static func world_position_to_cell(pos: Vector2, tile_size: int) -> Vector2i:
	return Vector2i(floori(pos.x / tile_size), floori(pos.y / tile_size))


static func cell_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / CHUNK_SIZE),
		floori(float(cell.y) / CHUNK_SIZE)
	)


static func world_position_to_chunk(pos: Vector2, tile_size: int) -> Vector2i:
	return cell_to_chunk(world_position_to_cell(pos, tile_size))


## 纬度偏置：gy ↑（南）→ 暖（正），gy ↓（北）→ 冷（负）
func _lat_bias(gy: int) -> float:
	return clampf(float(gy) / 10000.0, -0.55, 0.55)


# ========== Chunk 管理 ==========

## 初始化：存储父节点引用
func init_chunks(terrain_node: Node2D, object_node: Node2D = null) -> void:
	_terrain_node = terrain_node
	_object_node = object_node if object_node else terrain_node


	## 生成一个 chunk 的 TileMapLayer（如果还没加载）
func generate_chunk(cx: int, cy: int, spawn_content: bool = true) -> void:
	var key = Vector2i(cx, cy)
	if _active_chunks.has(key):
		return

	apply_chunk_terrain_data(build_chunk_terrain_data(cx, cy))

	if spawn_content:
		populate_chunk_content(cx, cy)


func build_chunk_terrain_data(cx: int, cy: int) -> Dictionary:
	if _terrain_tileset:
		return _build_layered_chunk_terrain_data(cx, cy)
	return _build_chunk_tilemap_data(cx, cy)


func make_chunk_terrain_context() -> Dictionary:
	var biome_variant_counts: Array[int] = []
	for cfg in _biome_configs:
		biome_variant_counts.append(int(cfg.get("variant_count", 1)))
	return {
		"world_seed": _world_seed,
		"tile_size": _tile_size,
		"biome_variant_counts": biome_variant_counts,
		"has_layered_terrain": _terrain_tileset != null,
		"base_terrain_id": _base_terrain_id,
		"overlay_terrain_ids_by_biome": _overlay_terrain_ids_by_biome.duplicate(true),
		"river_terrain_id": _river_terrain_id,
		"terrain_paint_mode": _terrain_paint_mode,
		"overlay_uses_terrain_connect": _overlay_uses_terrain_connect,
		"terrain_tiles_by_neighbor_mask": _terrain_tiles_by_neighbor_mask.duplicate(true),
		"full_terrain_tiles": _full_terrain_tiles.duplicate(true),
	}


func apply_chunk_terrain_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var key: Vector2i = data.get("key", Vector2i.ZERO)
	if _active_chunks.has(key):
		return
	if data.get("mode", "") == "layered":
		var layered_chunk = _create_layered_chunk_from_data(data)
		_terrain_node.add_child(layered_chunk)
		_active_chunks[key] = layered_chunk
		return
	var tm = _create_chunk_tilemap_from_data(data)
	_terrain_node.add_child(tm)
	_active_chunks[key] = tm


func populate_chunk_content(cx: int, cy: int) -> void:
	populate_chunk_resources(cx, cy)
	populate_chunk_decorations(cx, cy)


func get_resource_definition_count() -> int:
	return _resource_defs.size()


func get_decoration_definition_count() -> int:
	return _decoration_defs.size()


func populate_chunk_resources(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)
	if not _active_chunks.has(key):
		return
	for i in range(_resource_defs.size()):
		populate_chunk_resource_definition(cx, cy, i)


func populate_chunk_decorations(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)
	if not _active_chunks.has(key):
		return
	for i in range(_decoration_defs.size()):
		populate_chunk_decoration_definition(cx, cy, i)


func populate_chunk_resource_definition(cx: int, cy: int, definition_index: int) -> void:
	var key = Vector2i(cx, cy)
	if not _active_chunks.has(key):
		return
	if definition_index < 0 or definition_index >= _resource_defs.size():
		return
	_spawn_resource_definition_in_chunk(cx, cy, _resource_defs[definition_index])


func populate_chunk_decoration_definition(cx: int, cy: int, definition_index: int) -> void:
	var key = Vector2i(cx, cy)
	if not _active_chunks.has(key):
		return
	if definition_index < 0 or definition_index >= _decoration_defs.size():
		return
	var chunk_nodes: Array[Node] = []
	_spawn_decoration_definition_in_chunk(cx, cy, _decoration_defs[definition_index], chunk_nodes)
	if chunk_nodes.is_empty():
		return
	if not _decoration_nodes_by_chunk.has(key):
		_decoration_nodes_by_chunk[key] = []
	_decoration_nodes_by_chunk[key].append_array(chunk_nodes)


## 卸载一个 chunk
func unload_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)
	if not _active_chunks.has(key):
		return

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

	if _terrain_tileset:
		var terrain_chunk = _active_chunks[key] as Node
		if is_instance_valid(terrain_chunk):
			if terrain_chunk.get_parent():
				terrain_chunk.get_parent().remove_child(terrain_chunk)
			terrain_chunk.queue_free()
		_active_chunks.erase(key)
	else:
		var tm: TileMapLayer = _active_chunks[key]
		tm.queue_free()
		_active_chunks.erase(key)


## 卸载所有 chunk
func unload_all_chunks() -> void:
	for key in _active_chunks.keys():
		unload_chunk(key.x, key.y)


# ========== Chunk TileMapLayer 构建 ==========

func _build_chunk_tilemap_data(cx: int, cy: int) -> Dictionary:
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	var cells: Array[Dictionary] = []

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var gx = base_x + x
			var gy = base_y + y
			var biome = get_biome_at(gx, gy)
			if biome < 0 or biome >= _biome_configs.size():
				continue
			var variant_count = _biome_configs[biome].get("variant_count", 1)
			var v = _tile_variant(gx, gy, variant_count)
			cells.append({
				"cell": Vector2i(x, y),
				"source_id": biome,
				"atlas_coords": Vector2i(v % 4, int(v / 4)),
			})

	return {
		"mode": "single",
		"key": Vector2i(cx, cy),
		"name": "Chunk_%d_%d" % [cx, cy],
		"position": Vector2(base_x * _tile_size, base_y * _tile_size),
		"cells": cells,
	}


func _create_chunk_tilemap_from_data(data: Dictionary) -> TileMapLayer:
	var tm = TileMapLayer.new()
	tm.name = data.get("name", "Chunk")
	tm.tile_set = _build_tileset()
	tm.position = data.get("position", Vector2.ZERO)
	for cell_data in data.get("cells", []):
		tm.set_cell(cell_data["cell"], int(cell_data["source_id"]), cell_data["atlas_coords"])
	return tm


func _build_chunk_tilemap(cx: int, cy: int) -> TileMapLayer:
	return _create_chunk_tilemap_from_data(_build_chunk_tilemap_data(cx, cy))


func _build_layered_chunk_terrain_data(cx: int, cy: int) -> Dictionary:
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	var base_cells: Array[Vector2i] = []
	var overlay_cells_by_terrain: Dictionary = {}
	var overlay_tiles: Array[Dictionary] = []
	var use_global_neighbors = _terrain_paint_mode == TERRAIN_PAINT_GLOBAL_NEIGHBORS

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var local_cell = Vector2i(x, y)
			var gx = base_x + x
			var gy = base_y + y
			if _base_terrain_id >= 0:
				base_cells.append(local_cell)
			var terrain_id = _get_overlay_terrain_at(gx, gy)
			if terrain_id < 0:
				continue
			if use_global_neighbors:
				var tile = _get_global_neighbor_terrain_tile(terrain_id, gx, gy)
				if tile.is_empty():
					if not overlay_cells_by_terrain.has(terrain_id):
						overlay_cells_by_terrain[terrain_id] = []
					overlay_cells_by_terrain[terrain_id].append(local_cell)
				else:
					overlay_tiles.append({
						"cell": local_cell,
						"source_id": tile["source_id"],
						"atlas_coords": tile["atlas_coords"],
						"alternative": tile["alternative"],
					})
				continue
			if not overlay_cells_by_terrain.has(terrain_id):
				overlay_cells_by_terrain[terrain_id] = []
			overlay_cells_by_terrain[terrain_id].append(local_cell)

	return {
		"mode": "layered",
		"key": Vector2i(cx, cy),
		"name": "Chunk_%d_%d" % [cx, cy],
		"position": Vector2(base_x * _tile_size, base_y * _tile_size),
		"base_cells": base_cells,
		"base_terrain_id": _base_terrain_id,
		"overlay_cells_by_terrain": overlay_cells_by_terrain,
		"overlay_tiles": overlay_tiles,
		"overlay_uses_terrain_connect": _overlay_uses_terrain_connect,
		"use_global_neighbors": use_global_neighbors,
	}


func _create_layered_chunk_from_data(data: Dictionary) -> Node2D:
	var chunk = Node2D.new()
	chunk.name = data.get("name", "Chunk")
	chunk.position = data.get("position", Vector2.ZERO)

	var base_layer = TileMapLayer.new()
	base_layer.name = "BaseGrass"
	base_layer.tile_set = _terrain_tileset
	base_layer.z_index = -1
	chunk.add_child(base_layer)

	var overlay_layer = TileMapLayer.new()
	overlay_layer.name = "TerrainOverlay"
	overlay_layer.tile_set = _terrain_tileset
	chunk.add_child(overlay_layer)

	var base_cells: Array = data.get("base_cells", [])
	var base_terrain_id = int(data.get("base_terrain_id", -1))
	if not base_cells.is_empty():
		_paint_cells_with_terrain(base_layer, base_cells, base_terrain_id, false)

	for tile in data.get("overlay_tiles", []):
		overlay_layer.set_cell(tile["cell"], tile["source_id"], tile["atlas_coords"], tile["alternative"])

	var overlay_cells_by_terrain: Dictionary = data.get("overlay_cells_by_terrain", {})
	for terrain_id in overlay_cells_by_terrain:
		_paint_cells_with_terrain(overlay_layer, overlay_cells_by_terrain[terrain_id], terrain_id, bool(data.get("overlay_uses_terrain_connect", false)))

	return chunk


func _build_layered_chunk_tilemaps(cx: int, cy: int) -> Node2D:
	return _create_layered_chunk_from_data(_build_layered_chunk_terrain_data(cx, cy))


func _paint_global_neighbor_terrain_cell(tm: TileMapLayer, cell: Vector2i, terrain_id: int) -> void:
	_paint_global_neighbor_terrain_cell_at(tm, cell, terrain_id, cell.x, cell.y)


func _paint_global_neighbor_terrain_cell_at(tm: TileMapLayer, cell: Vector2i, terrain_id: int, gx: int, gy: int) -> void:
	var tile = _get_global_neighbor_terrain_tile(terrain_id, gx, gy)
	if tile.is_empty():
		_paint_cells_with_terrain(tm, [cell], terrain_id, true)
		return
	tm.set_cell(cell, tile["source_id"], tile["atlas_coords"], tile["alternative"])


func _paint_cells_with_terrain(tm: TileMapLayer, cells: Array, terrain_id: int, use_terrain_connect: bool) -> void:
	if cells.is_empty():
		return
	if use_terrain_connect or not _full_terrain_tiles.has(terrain_id):
		tm.set_cells_terrain_connect(cells, _terrain_set, terrain_id, true)
		return

	var tile: Dictionary = _full_terrain_tiles[terrain_id]
	for cell in cells:
		tm.set_cell(cell, tile["source_id"], tile["atlas_coords"], tile["alternative"])


func _rebuild_full_terrain_tiles() -> void:
	_full_terrain_tiles.clear()
	_terrain_tiles_by_neighbor_mask.clear()
	if _terrain_tileset == null:
		return
	for i in range(_terrain_tileset.get_source_count()):
		var source_id = _terrain_tileset.get_source_id(i)
		var source = _terrain_tileset.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue
		var atlas_source = source as TileSetAtlasSource
		for j in range(atlas_source.get_tiles_count()):
			var atlas_coords = atlas_source.get_tile_id(j)
			for n in range(atlas_source.get_alternative_tiles_count(atlas_coords)):
				var alternative = atlas_source.get_alternative_tile_id(atlas_coords, n)
				var tile_data = atlas_source.get_tile_data(atlas_coords, alternative)
				if tile_data.terrain_set != _terrain_set or tile_data.terrain < 0:
					continue
				var tile = {
					"source_id": source_id,
					"atlas_coords": atlas_coords,
					"alternative": alternative,
				}
				var mask = _get_tile_data_neighbor_mask(tile_data)
				if not _terrain_tiles_by_neighbor_mask.has(tile_data.terrain):
					_terrain_tiles_by_neighbor_mask[tile_data.terrain] = {}
				_terrain_tiles_by_neighbor_mask[tile_data.terrain][mask] = tile
				if _is_full_terrain_tile(tile_data):
					_full_terrain_tiles[tile_data.terrain] = tile


func _is_full_terrain_tile(tile_data: TileData) -> bool:
	var terrain = tile_data.terrain
	var neighbors = [
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	]
	for neighbor in neighbors:
		if tile_data.get_terrain_peering_bit(neighbor) != terrain:
			return false
	return true



func _get_global_neighbor_terrain_tile(terrain_id: int, gx: int, gy: int) -> Dictionary:
	var mask = _get_global_terrain_neighbor_mask(terrain_id, gx, gy)
	var tiles_by_mask: Dictionary = _terrain_tiles_by_neighbor_mask.get(terrain_id, {})
	if tiles_by_mask.has(mask):
		return tiles_by_mask[mask]
	return _full_terrain_tiles.get(terrain_id, {})


func _get_global_terrain_neighbor_mask(terrain_id: int, gx: int, gy: int) -> int:
	var mask = 0
	if _get_overlay_terrain_at(gx - 1, gy) == terrain_id:
		mask |= TERRAIN_MASK_LEFT
	if _get_overlay_terrain_at(gx - 1, gy + 1) == terrain_id:
		mask |= TERRAIN_MASK_BOTTOM_LEFT
	if _get_overlay_terrain_at(gx, gy + 1) == terrain_id:
		mask |= TERRAIN_MASK_BOTTOM
	if _get_overlay_terrain_at(gx + 1, gy + 1) == terrain_id:
		mask |= TERRAIN_MASK_BOTTOM_RIGHT
	if _get_overlay_terrain_at(gx + 1, gy) == terrain_id:
		mask |= TERRAIN_MASK_RIGHT
	if _get_overlay_terrain_at(gx + 1, gy - 1) == terrain_id:
		mask |= TERRAIN_MASK_TOP_RIGHT
	if _get_overlay_terrain_at(gx, gy - 1) == terrain_id:
		mask |= TERRAIN_MASK_TOP
	if _get_overlay_terrain_at(gx - 1, gy - 1) == terrain_id:
		mask |= TERRAIN_MASK_TOP_LEFT
	return _normalize_terrain_neighbor_mask(mask)


func _get_tile_data_neighbor_mask(tile_data: TileData) -> int:
	var terrain = tile_data.terrain
	var mask = 0
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == terrain:
		mask |= TERRAIN_MASK_LEFT
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == terrain:
		mask |= TERRAIN_MASK_BOTTOM_LEFT
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == terrain:
		mask |= TERRAIN_MASK_BOTTOM
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == terrain:
		mask |= TERRAIN_MASK_BOTTOM_RIGHT
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == terrain:
		mask |= TERRAIN_MASK_RIGHT
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == terrain:
		mask |= TERRAIN_MASK_TOP_RIGHT
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == terrain:
		mask |= TERRAIN_MASK_TOP
	if tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == terrain:
		mask |= TERRAIN_MASK_TOP_LEFT
	return _normalize_terrain_neighbor_mask(mask)


func _normalize_terrain_neighbor_mask(mask: int) -> int:
	var has_left = (mask & TERRAIN_MASK_LEFT) != 0
	var has_bottom_left = (mask & TERRAIN_MASK_BOTTOM_LEFT) != 0
	var has_bottom = (mask & TERRAIN_MASK_BOTTOM) != 0
	var has_bottom_right = (mask & TERRAIN_MASK_BOTTOM_RIGHT) != 0
	var has_right = (mask & TERRAIN_MASK_RIGHT) != 0
	var has_top_right = (mask & TERRAIN_MASK_TOP_RIGHT) != 0
	var has_top = (mask & TERRAIN_MASK_TOP) != 0
	var has_top_left = (mask & TERRAIN_MASK_TOP_LEFT) != 0
	if has_bottom_left and not (has_bottom and has_left):
		mask &= ~TERRAIN_MASK_BOTTOM_LEFT
	if has_bottom_right and not (has_bottom and has_right):
		mask &= ~TERRAIN_MASK_BOTTOM_RIGHT
	if has_top_right and not (has_top and has_right):
		mask &= ~TERRAIN_MASK_TOP_RIGHT
	if has_top_left and not (has_top and has_left):
		mask &= ~TERRAIN_MASK_TOP_LEFT
	return mask


func _get_overlay_terrain_at(gx: int, gy: int) -> int:
	if _river_terrain_id >= 0 and _is_river_cell(gx, gy):
		return _river_terrain_id
	var biome = get_biome_at(gx, gy)
	if biome == BIOME_WATER and _overlay_terrain_ids_by_biome.get(BIOME_WATER, -1) == _river_terrain_id:
		return -1
	return _overlay_terrain_ids_by_biome.get(biome, -1)


func _is_river_cell(gx: int, gy: int) -> bool:
	var key = Vector2i(gx, gy)
	if _river_cell_cache.has(key):
		return bool(_river_cell_cache[key])
	var is_river = _is_direct_river_cell(gx, gy) or _is_river_bridge_cell(gx, gy)
	_river_cell_cache[key] = is_river
	return is_river


func _is_direct_river_cell(gx: int, gy: int) -> bool:
	var key = Vector2i(gx, gy)
	if _direct_river_cell_cache.has(key):
		return bool(_direct_river_cell_cache[key])
	for oy in range(-RIVER_CHANNEL_RADIUS, RIVER_CHANNEL_RADIUS + 1):
		for ox in range(-RIVER_CHANNEL_RADIUS, RIVER_CHANNEL_RADIUS + 1):
			if _is_river_core_cell(gx + ox, gy + oy):
				_direct_river_cell_cache[key] = true
				return true
	_direct_river_cell_cache[key] = false
	return false


func _is_river_bridge_cell(gx: int, gy: int) -> bool:
	for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
		if _has_direct_river_on_both_sides(gx, gy, direction):
			return true
	return false


func _is_river_cardinal_support_cell(gx: int, gy: int) -> bool:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _is_direct_river_cell(gx + direction.x, gy + direction.y):
			return true
	return false


func _has_direct_river_on_both_sides(gx: int, gy: int, direction: Vector2i) -> bool:
	var before_distance = 0
	var after_distance = 0
	for distance in range(1, RIVER_BRIDGE_MAX_GAP + 2):
		if _is_direct_river_cell(gx - direction.x * distance, gy - direction.y * distance):
			before_distance = distance
		if _is_direct_river_cell(gx + direction.x * distance, gy + direction.y * distance):
			after_distance = distance
		if before_distance > 0 and after_distance > 0:
			return before_distance + after_distance <= RIVER_BRIDGE_MAX_GAP + 1
	return false


func _is_river_core_cell(gx: int, gy: int) -> bool:
	if _river_noise == null or _river_width_noise == null or _river_branch_noise == null or _river_warp_noise == null:
		return false
	if _get_main_river_distance(gx, gy) <= _get_main_river_half_width(gx, gy):
		return true
	return _get_tributary_distance(gx, gy) <= _get_branch_river_half_width(gx, gy)


func _get_main_river_distance(gx: int, gy: int) -> float:
	var key = Vector2i(gx, gy)
	if _main_river_distance_cache.has(key):
		return float(_main_river_distance_cache[key])
	var basin = floori(float(gx) / float(RIVER_BASIN_WIDTH))
	var best_distance = INF
	for offset in range(-1, 2):
		var candidate_basin = basin + offset
		var river_x = _get_main_river_x(candidate_basin, float(gy))
		best_distance = minf(best_distance, absf(float(gx) - river_x))
	_main_river_distance_cache[key] = best_distance
	return best_distance


func _get_main_river_x(basin: int, y: float) -> float:
	var basin_center = float(basin * RIVER_BASIN_WIDTH)
	var broad_meander = _river_noise.get_noise_2d(float(basin) * 317.0 + 91.0, y) * 70.0
	var fine_meander = _river_warp_noise.get_noise_2d(float(basin) * 503.0 - 37.0, y) * 26.0
	return basin_center + broad_meander + fine_meander


func _get_main_river_half_width(gx: int, gy: int) -> float:
	var width_sample = (_river_width_noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	return RIVER_MAIN_HALF_WIDTH + width_sample * RIVER_MAIN_WIDTH_VARIATION


func _get_tributary_distance(gx: int, gy: int) -> float:
	var key = Vector2i(gx, gy)
	if _tributary_distance_cache.has(key):
		return float(_tributary_distance_cache[key])
	var basin = floori(float(gx) / float(RIVER_BASIN_WIDTH))
	var branch_row = floori(float(gy) / float(RIVER_BRANCH_INTERVAL))
	var best_distance = INF
	for basin_offset in range(-1, 2):
		for row_offset in range(-1, 2):
			var candidate_basin = basin + basin_offset
			var candidate_row = branch_row + row_offset
			if _hash_float("river_branch_join", candidate_basin, candidate_row) > RIVER_BRANCH_JOIN_CHANCE:
				continue
			var junction_y = _get_tributary_junction_y(candidate_basin, candidate_row)
			var junction_x = _get_main_river_x(candidate_basin, junction_y)
			var side = -1.0 if _hash_float("river_branch_side", candidate_basin, candidate_row) < 0.5 else 1.0
			var reach = lerpf(RIVER_BRANCH_REACH_MIN, RIVER_BRANCH_REACH_MAX, _hash_float("river_branch_reach", candidate_basin, candidate_row))
			var source = Vector2(
				junction_x + side * reach,
				junction_y + lerpf(-42.0, 42.0, _hash_float("river_branch_source_y", candidate_basin, candidate_row))
			)
			var bend = Vector2(
				(source.x + junction_x) * 0.5 + side * lerpf(-18.0, 26.0, _hash_float("river_branch_bend_x", candidate_basin, candidate_row)),
				(source.y + junction_y) * 0.5 + lerpf(-34.0, 34.0, _hash_float("river_branch_bend_y", candidate_basin, candidate_row))
			)
			var point = Vector2(float(gx), float(gy))
			best_distance = minf(best_distance, _distance_to_segment_if_near(point, source, bend, 12.0))
			best_distance = minf(best_distance, _distance_to_segment_if_near(point, bend, Vector2(junction_x, junction_y), 12.0))
	_tributary_distance_cache[key] = best_distance
	return best_distance


func _get_tributary_junction_y(basin: int, row: int) -> float:
	return float(row * RIVER_BRANCH_INTERVAL) + lerpf(-24.0, 24.0, _hash_float("river_branch_junction_y", basin, row))


func _get_branch_river_half_width(gx: int, gy: int) -> float:
	var width_sample = (_river_width_noise.get_noise_2d(float(gx) + 2117.0, float(gy) - 1693.0) + 1.0) * 0.5
	return RIVER_BRANCH_HALF_WIDTH + width_sample * RIVER_BRANCH_WIDTH_VARIATION


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return point.distance_to(a)
	var t = clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _distance_to_segment_if_near(point: Vector2, a: Vector2, b: Vector2, margin: float) -> float:
	var min_x = minf(a.x, b.x) - margin
	var max_x = maxf(a.x, b.x) + margin
	var min_y = minf(a.y, b.y) - margin
	var max_y = maxf(a.y, b.y) + margin
	if point.x < min_x or point.x > max_x or point.y < min_y or point.y > max_y:
		return INF
	return _distance_to_segment(point, a, b)


func _get_river_warped_point(gx: int, gy: int) -> Vector2:
	var x = float(gx)
	var y = float(gy)
	var warp_x = _river_warp_noise.get_noise_2d(x, y) * RIVER_DOMAIN_WARP
	var warp_y = _river_warp_noise.get_noise_2d(x + 4096.0, y - 2048.0) * RIVER_DOMAIN_WARP
	return Vector2(x + warp_x, y + warp_y)


func _get_main_river_threshold(gx: int, gy: int) -> float:
	var width_sample = (_river_width_noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	return RIVER_MAIN_BASE_THRESHOLD + width_sample * RIVER_MAIN_THRESHOLD_VARIATION


func _get_branch_river_threshold(gx: int, gy: int) -> float:
	var width_sample = (_river_width_noise.get_noise_2d(float(gx) + 2117.0, float(gy) - 1693.0) + 1.0) * 0.5
	return RIVER_BRANCH_BASE_THRESHOLD + width_sample * RIVER_BRANCH_THRESHOLD_VARIATION


func _tile_variant(gx: int, gy: int, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	return _hash_index(variant_count, "tile", gx, gy)


func _chunk_seed(cx: int, cy: int, salt: String) -> int:
	return posmod(hash("%d_%d_%s_%d" % [cx, cy, salt, _world_seed]), 2147483647)


func _hash_index(modulo: int, salt: String, a: int = 0, b: int = 0, c: int = 0) -> int:
	if modulo <= 0:
		return 0
	return posmod(hash("%d_%s_%d_%d_%d" % [_world_seed, salt, a, b, c]), modulo)


func _hash_float(salt: String, a: int = 0, b: int = 0, c: int = 0) -> float:
	return float(_hash_index(1000000, salt, a, b, c)) / 999999.0


func _candidate_hash_float(salt: String, a: int = 0, b: int = 0, c: int = 0) -> float:
	var rng = RandomNumberGenerator.new()
	rng.seed = posmod(hash([_world_seed, salt, a, b, c]), 2147483647)
	return rng.randf()


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
		var source_rect: Rect2i = cfg.get("source_rect", Rect2i())
		if source_rect.size.x > 0 and source_rect.size.y > 0:
			tex = _crop_texture(tex, source_rect)
			if tex == null:
				push_error("WorldGenerator: Failed to crop atlas: %s" % atlas_path)
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


func _crop_texture(tex: Texture2D, source_rect: Rect2i) -> Texture2D:
	var image = tex.get_image()
	if image == null:
		return null
	var bounds = Rect2i(Vector2i.ZERO, image.get_size())
	source_rect = source_rect.intersection(bounds)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return null
	var cropped = image.get_region(source_rect)
	return ImageTexture.create_from_image(cropped)



# ========== 资源 & 装饰 (按 chunk) ==========

func _spawn_resources_in_chunk(cx: int, cy: int) -> void:
	for d in _resource_defs:
		_spawn_resource_definition_in_chunk(cx, cy, d)


func _spawn_resource_definition_in_chunk(cx: int, cy: int, definition: Dictionary) -> void:
	var biomes: Array = definition.get("biomes", [])
	if biomes.is_empty():
		return
	var textures = _get_resource_textures(definition)
	if textures.is_empty():
		return
	if definition.get("placement_mode", "") == "poisson_grid":
		_spawn_resource_poisson_grid(cx, cy, definition)
	else:
		_spawn_resource_per_tile(cx, cy, definition)


func _spawn_resource_per_tile(cx: int, cy: int, definition: Dictionary) -> void:
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	var biomes: Array = definition.get("biomes", [])
	var textures = _get_resource_textures(definition)
	var placement_step = max(1, int(definition.get("placement_step", 1)))

	for y in range(0, CHUNK_SIZE, placement_step):
		for x in range(0, CHUNK_SIZE, placement_step):
			var gx = base_x + x
			var gy = base_y + y
			if get_biome_id_at(gx, gy) not in biomes:
				continue
			if not _should_spawn_definition_at(definition, gx, gy, "res"):
				continue
			var pos = _get_spawn_position(definition, gx, gy, "res")
			var texture_index = _hash_index(textures.size(), "%s_texture" % definition["id"], gx, gy)
			var id = "%d_%d_%s_%d_%d" % [cx, cy, definition["id"], x, y]
			_spawn_resource_sprite(id, definition, textures[texture_index], pos)


func _spawn_resource_poisson_grid(cx: int, cy: int, definition: Dictionary) -> void:
	var biomes: Array = definition.get("biomes", [])
	var textures = _get_resource_textures(definition)
	if textures.is_empty():
		return
	var spacing = max(1.0, float(definition.get("grid_cell_size", 192.0))) * float(definition.get("spacing_scale", vegetation_spacing_scale))
	var grid_density = clampf(float(definition.get("grid_density", definition.get("density", 0.3))), 0.0, 1.0)
	if grid_density <= 0.0:
		return
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	var min_px = Vector2(float(base_x * _tile_size), float(base_y * _tile_size))
	var max_px = min_px + Vector2(float(CHUNK_SIZE * _tile_size), float(CHUNK_SIZE * _tile_size))
	var chunk_pixel_size = float(CHUNK_SIZE * _tile_size)
	var target_count = max(1, ceili((chunk_pixel_size * chunk_pixel_size) / (spacing * spacing)))
	var candidate_multiplier = max(1, int(definition.get("candidate_multiplier", 8)))
	var candidate_count = target_count * candidate_multiplier
	var min_distance_factor = clampf(float(definition.get("min_distance_factor", 0.65)), 0.0, 2.0)
	var min_distance_sq = pow(spacing * min_distance_factor, 2.0)
	var candidates: Array[Dictionary] = []

	for attempt in range(candidate_count):
		var pos = Vector2(
			lerpf(min_px.x, max_px.x - 0.001, _candidate_hash_float("res_candidate_x_%s" % definition["id"], cx, cy, attempt)),
			lerpf(min_px.y, max_px.y - 0.001, _candidate_hash_float("res_candidate_y_%s" % definition["id"], cx, cy, attempt))
		)
		var gx = floori(pos.x / float(_tile_size))
		var gy = floori(pos.y / float(_tile_size))
		if get_biome_id_at(gx, gy) not in biomes:
			continue
		var ecology = _sample_ecology_layers(gx, gy)
		var density = grid_density
		density *= _get_region_spawn_multiplier(definition, gx, gy, "res")
		density *= _get_ecology_spawn_multiplier(definition, ecology)
		density *= _get_water_spawn_multiplier(definition, gx, gy)
		density = clampf(density, 0.0, 1.0)
		if density <= 0.0:
			continue
		if _candidate_hash_float("res_candidate_gate_%s" % definition["id"], cx, cy, attempt) >= density:
			continue
		candidates.append({
			"pos": pos,
			"attempt": attempt,
			"score": density * 0.75 + _candidate_hash_float("res_candidate_score_%s" % definition["id"], cx, cy, attempt) * 0.25,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)

	var accepted_positions: Array[Vector2] = []
	for candidate in candidates:
		var pos: Vector2 = candidate["pos"]
		var too_close = false
		for accepted_pos in accepted_positions:
			var distance_sq = pos.distance_squared_to(accepted_pos)
			if distance_sq < min_distance_sq:
				too_close = true
				break
		if too_close:
			continue
		accepted_positions.append(pos)
		var attempt = int(candidate["attempt"])
		var texture_index = _hash_index(textures.size(), "%s_texture" % definition["id"], cx, cy, attempt)
		var id = "%d_%d_%s_candidate_%d" % [cx, cy, definition["id"], attempt]
		_spawn_resource_sprite(id, definition, textures[texture_index], pos)
		if accepted_positions.size() >= target_count:
			break


func _spawn_resource_sprite(id: String, definition: Dictionary, texture: Texture2D, pos: Vector2) -> void:
	var sprite = Sprite2D.new()
	sprite.position = pos
	sprite.texture = texture
	sprite.z_index = definition.get("z_index", 1)
	var s = definition.get("scale", 1.0)
	sprite.scale = Vector2(s, s)
	_apply_resource_anchor(sprite, definition)
	if definition.get("shadow", false):
		_attach_cast_shadow(sprite)
	_add_resource_collision(sprite, definition)
	_object_node.add_child(sprite)

	resource_sprites[id] = sprite
	resource_data[id] = {
		"name": definition.get("name", definition["id"]),
		"item_id": definition["item"],
		"quantity": definition.get("qty", 1),
		"harvest_type": definition.get("harvest_type", -1),
		"tool_tier": definition.get("tool_tier", 0),
		"depleted": false,
	}


func _get_resource_textures(definition: Dictionary) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if definition.has("textures"):
		for tex in definition.get("textures", []):
			if tex is Texture2D:
				result.append(tex)
	if result.is_empty() and definition.get("texture", null) is Texture2D:
		result.append(definition["texture"])
	return result


func _get_spawn_position(definition: Dictionary, gx: int, gy: int, salt: String) -> Vector2:
	var jitter = clampf(float(definition.get("position_jitter", 0.0)), 0.0, 0.49)
	var offset_x = 0.0
	var offset_y = 0.0
	if jitter > 0.0:
		var span = float(_tile_size) * jitter
		offset_x = lerpf(-span, span, _hash_float("%s_%s_pos_x" % [salt, definition.get("id", "item")], gx, gy))
		offset_y = lerpf(-span, span, _hash_float("%s_%s_pos_y" % [salt, definition.get("id", "item")], gx, gy))
	return Vector2(gx * _tile_size + _tile_size / 2.0 + offset_x, gy * _tile_size + _tile_size / 2.0 + offset_y)


func _should_spawn_definition_at(definition: Dictionary, gx: int, gy: int, salt: String) -> bool:
	var density = _get_definition_spawn_density(definition, gx, gy, salt)
	if density <= 0.0:
		return false
	return _hash_float("%s_%s_spawn" % [salt, definition.get("id", "item")], gx, gy) <= density


func _get_definition_spawn_density(definition: Dictionary, gx: int, gy: int, salt: String) -> float:
	var density = 0.0
	if definition.get("clustered", false):
		density = _get_clustered_spawn_density(definition, gx, gy, salt)
	else:
		density = clampf(float(definition.get("density", 0.0)), 0.0, 1.0)
	var ecology = _sample_ecology_layers(gx, gy)
	density *= _get_region_spawn_multiplier(definition, gx, gy, salt)
	density *= _get_ecology_spawn_multiplier(definition, ecology)
	density *= _get_water_spawn_multiplier(definition, gx, gy)
	return clampf(density, 0.0, 1.0)


func _get_water_spawn_multiplier(definition: Dictionary, gx: int, gy: int) -> float:
	var has_water_rules = (
		definition.has("water_clearance")
		or definition.has("water_falloff")
		or definition.has("allow_near_water")
		or definition.has("allow_on_water")
		or definition.has("block_on_water")
	)
	if not has_water_rules:
		return 1.0
	if bool(definition.get("allow_on_water", false)):
		return 1.0
	if is_water_cell(gx, gy):
		return 0.0
	if bool(definition.get("allow_near_water", false)):
		return 1.0

	var clearance = max(0, int(definition.get("water_clearance", 0)))
	var falloff = max(clearance, int(definition.get("water_falloff", clearance)))
	if clearance <= 0 and falloff <= 0:
		return 1.0

	var distance = get_river_bank_distance(gx, gy, falloff)
	if distance <= clearance:
		return 0.0
	if distance > falloff:
		return 1.0
	if falloff == clearance:
		return 1.0
	return _smootherstep(float(distance - clearance) / float(falloff - clearance))


func _get_region_spawn_multiplier(definition: Dictionary, gx: int, gy: int, salt: String) -> float:
	var multiplier = 1.0
	var config: Dictionary = definition.get("region_noise", {})
	if not config.is_empty():
		multiplier *= _get_shaped_region_spawn_multiplier(config, gx, gy)
	# avoid_region_noise: 在指定区域（如另一种树林）越强的地方，本物种越被抑制，
	# 从而让不同种类的树木各自聚成独立的树林而非混杂在一起。
	var avoid: Dictionary = definition.get("avoid_region_noise", {})
	if not avoid.is_empty():
		multiplier *= 1.0 - _get_shaped_region_spawn_multiplier(avoid, gx, gy)
	return clampf(multiplier, 0.0, 1.0)


func _get_shaped_region_spawn_multiplier(config: Dictionary, gx: int, gy: int) -> float:
	var group = str(config.get("group", "region"))
	var frequency = max(0.0001, float(config.get("frequency", 0.018)))
	var threshold = clampf(float(config.get("threshold", 0.50)), 0.0, 1.0)
	var softness = max(0.001, float(config.get("softness", 0.18)))
	var min_multiplier = clampf(float(config.get("min_multiplier", 0.0)), 0.0, 1.0)
	var power = max(0.05, float(config.get("power", 1.0)))
	var noise = _get_region_noise(group, frequency, int(config.get("octaves", 3)), float(config.get("gain", 0.52)))
	var value = _get_region_noise_value_from_noise(noise, gx, gy)
	var suitability = inverse_lerp(threshold - softness, threshold + softness, value)
	suitability = _smootherstep(suitability)
	suitability = pow(clampf(suitability, 0.0, 1.0), power)
	return lerpf(min_multiplier, 1.0, suitability)


func _get_region_noise_value(config: Dictionary, gx: int, gy: int) -> float:
	var group = str(config.get("group", "region"))
	var frequency = max(0.0001, float(config.get("frequency", 0.018)))
	var noise = _get_region_noise(group, frequency, int(config.get("octaves", 3)), float(config.get("gain", 0.52)))
	return _get_region_noise_value_from_noise(noise, gx, gy)


func _get_region_noise_value_from_noise(noise: FastNoiseLite, gx: int, gy: int) -> float:
	return clampf((noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5, 0.0, 1.0)


func _smootherstep(value: float) -> float:
	var t = clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _get_region_noise(group: String, frequency: float, octaves: int, gain: float) -> FastNoiseLite:
	var key = "%s_%.5f_%d_%.3f" % [group, frequency, octaves, gain]
	if _region_noise_cache.has(key):
		return _region_noise_cache[key]
	var noise = FastNoiseLite.new()
	noise.seed = posmod(hash("%d_region_%s" % [_world_seed, key]), 2147483647)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = frequency
	noise.fractal_octaves = max(1, octaves)
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = clampf(gain, 0.0, 1.0)
	_region_noise_cache[key] = noise
	return noise


func _get_ecology_spawn_multiplier(definition: Dictionary, ecology: Dictionary) -> float:
	var preference: Dictionary = definition.get("ecology", {})
	if preference.is_empty():
		return 1.0

	var default_tolerance = max(0.001, float(preference.get("tolerance", 0.35)))
	var min_multiplier = clampf(float(preference.get("min_multiplier", 0.0)), 0.0, 1.0)
	var weighted_suitability = 0.0
	var weight_sum = 0.0
	var gate_factor = 1.0  # 否决层（gate）的乘积：任一关键层不适宜则整体趋零

	for layer in ["temperature", "moisture", "soil_depth", "elevation"]:
		if not preference.has(layer):
			continue
		var tolerance = default_tolerance
		var weight = 1.0
		var target = 0.5
		var is_gate = false
		if preference[layer] is Dictionary:
			var layer_preference: Dictionary = preference[layer]
			target = float(layer_preference.get("target", 0.5))
			tolerance = max(0.001, float(layer_preference.get("tolerance", default_tolerance)))
			weight = max(0.0, float(layer_preference.get("weight", 1.0)))
			is_gate = bool(layer_preference.get("gate", false))
		else:
			target = float(preference[layer])
		var current = float(ecology.get(layer, 0.5))
		var suitability = clampf(1.0 - absf(current - target) / tolerance, 0.0, 1.0)
		if is_gate:
			# 否决层（如温度决定树种、海拔决定林线）：用乘法，不适宜则把整体压向零
			gate_factor *= suitability
		else:
			weighted_suitability += suitability * weight
			weight_sum += weight

	var average_suitability = 1.0 if weight_sum <= 0.0 else weighted_suitability / weight_sum
	return lerpf(min_multiplier, 1.0, average_suitability) * gate_factor


func _get_clustered_spawn_density(definition: Dictionary, gx: int, gy: int, salt: String) -> float:
	var density = clampf(float(definition.get("scatter_density", definition.get("density", 0.0))), 0.0, 1.0)
	var cell_size = max(1, int(definition.get("cluster_cell_size", 96)))
	var chance = clampf(float(definition.get("cluster_chance", 0.35)), 0.0, 1.0)
	var min_radius = max(1.0, float(definition.get("cluster_radius_min", 12.0)))
	var max_radius = max(min_radius, float(definition.get("cluster_radius_max", 32.0)))
	var cluster_density = clampf(float(definition.get("cluster_density", 0.2)), 0.0, 1.0)
	var falloff_power = max(0.05, float(definition.get("cluster_falloff", 0.75)))
	var center_cell = Vector2i(floori(float(gx) / float(cell_size)), floori(float(gy) / float(cell_size)))
	var search_radius = int(ceil(max_radius / float(cell_size))) + 1

	for oy in range(-search_radius, search_radius + 1):
		for ox in range(-search_radius, search_radius + 1):
			var cluster_cell = center_cell + Vector2i(ox, oy)
			var cluster_salt = _get_cluster_salt(definition, salt)
			var sample = _get_cluster_sample(cluster_cell, cell_size, cluster_salt)
			if sample["chance"] > chance:
				continue
			var radius = lerpf(min_radius, max_radius, sample["radius"])
			var dx = float(gx) - sample["center_x"]
			var dy = float(gy) - sample["center_y"]
			var distance_sq = dx * dx + dy * dy
			var radius_sq = radius * radius
			if distance_sq > radius_sq:
				continue
			var distance = sqrt(distance_sq)
			var local_density = cluster_density * pow(1.0 - distance / radius, falloff_power)
			density = max(density, local_density)

	return clampf(density, 0.0, 1.0)


func _get_cluster_salt(definition: Dictionary, salt: String) -> String:
	var cluster_group = str(definition.get("cluster_group", ""))
	if not cluster_group.is_empty():
		return "eco_%s_cluster" % cluster_group
	return "%s_%s_cluster" % [salt, definition.get("id", "item")]


func _get_cluster_sample(cluster_cell: Vector2i, cell_size: int, salt: String) -> Dictionary:
	var key = "%s_%d_%d_%d" % [salt, cell_size, cluster_cell.x, cluster_cell.y]
	if _cluster_sample_cache.has(key):
		return _cluster_sample_cache[key]
	var jitter_x = _hash_float("%s_x" % salt, cluster_cell.x, cluster_cell.y)
	var jitter_y = _hash_float("%s_y" % salt, cluster_cell.x, cluster_cell.y)
	var sample = {
		"center_x": float(cluster_cell.x * cell_size) + jitter_x * float(cell_size),
		"center_y": float(cluster_cell.y * cell_size) + jitter_y * float(cell_size),
		"chance": _hash_float("%s_chance" % salt, cluster_cell.x, cluster_cell.y),
		"radius": _hash_float("%s_radius" % salt, cluster_cell.x, cluster_cell.y),
	}
	_cluster_sample_cache[key] = sample
	return sample


func _apply_resource_anchor(sprite: Sprite2D, definition: Dictionary) -> void:
	if definition.get("anchor", "center") != "bottom":
		sprite.centered = true
		return
	sprite.centered = false
	if sprite.texture == null:
		return
	var size = sprite.texture.get_size()
	sprite.offset = Vector2(-size.x / 2.0, -size.y)


## 给 bottom 锚点的物体(如树)加剪影斜投影子：从脚底向屏幕下方铺、向右倾斜，
## 模拟日光从左上方照下来。参数可按需微调(透明度/倾斜/压扁)。
func _attach_cast_shadow(host: Sprite2D) -> void:
	if host.texture == null:
		return
	var shadow = Sprite2D.new()
	shadow.name = "CastShadow"
	shadow.texture = host.texture
	shadow.centered = host.centered
	shadow.offset = host.offset
	shadow.modulate = Color(0, 0, 0, 0.26)
	shadow.z_index = -1
	shadow.scale = Vector2(1.0, -0.55)  # 初始值；运行时由太阳角度动态更新
	shadow.skew = 0.6
	host.add_child(shadow)
	host.move_child(shadow, 0)


## 按太阳角度批量更新所有投影阴影的倾斜(skew)、长度(length)与浓淡(alpha)。
## 由 OfflineGame 每隔一小段时间调用，实现日出→正午→日落的阴影流动。
func update_cast_shadows(skew: float, length: float, alpha: float) -> void:
	for id in resource_sprites:
		var host = resource_sprites[id]
		if not is_instance_valid(host):
			continue
		var sh = host.get_node_or_null("CastShadow")
		if sh:
			sh.skew = skew
			sh.scale = Vector2(1.0, -length)
			sh.modulate.a = alpha


func _add_resource_collision(sprite: Sprite2D, definition: Dictionary) -> void:
	var radius = float(definition.get("collision_radius", 0.0))
	if radius <= 0.0:
		return

	var body = StaticBody2D.new()
	body.name = "TrunkBody"
	body.position = definition.get("collision_offset", Vector2.ZERO)

	var shape = CircleShape2D.new()
	shape.radius = radius

	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	body.add_child(collision)
	sprite.add_child(body)

func _spawn_decorations_in_chunk(cx: int, cy: int) -> void:
	var chunk_key = Vector2i(cx, cy)
	var chunk_nodes: Array[Node] = []

	for d in _decoration_defs:
		_spawn_decoration_definition_in_chunk(cx, cy, d, chunk_nodes)

	if not chunk_nodes.is_empty():
		_decoration_nodes_by_chunk[chunk_key] = chunk_nodes


func _spawn_decoration_definition_in_chunk(cx: int, cy: int, definition: Dictionary, chunk_nodes: Array[Node]) -> void:
	var biomes: Array = definition.get("biomes", [])
	if biomes.is_empty():
		return
	var textures = _get_resource_textures(definition)
	if textures.is_empty():
		return
	if definition.get("placement_mode", "") == "poisson_grid":
		_spawn_deco_poisson_grid(cx, cy, definition, chunk_nodes)
	else:
		_spawn_deco_per_tile(cx, cy, definition, chunk_nodes)


func _spawn_deco_poisson_grid(cx: int, cy: int, definition: Dictionary, chunk_nodes: Array) -> void:
	var biomes: Array = definition.get("biomes", [])
	var textures = _get_resource_textures(definition)
	if textures.is_empty():
		return
	var cell_size = max(1, int(round(float(definition.get("grid_cell_size", 128)) * float(definition.get("spacing_scale", vegetation_spacing_scale)))))
	var grid_density = clampf(float(definition.get("grid_density", 0.3)), 0.0, 1.0)
	var spawn_group = "dec_%s" % definition["id"]
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE

	var start_cx = base_x / cell_size
	var start_cy = base_y / cell_size
	var end_cx = float(base_x + CHUNK_SIZE - 1) / cell_size
	var end_cy = float(base_y + CHUNK_SIZE - 1) / cell_size

	for cell_y in range(floori(start_cy) - 1, floori(end_cy) + 2):
		for cell_x in range(floori(start_cx) - 1, floori(end_cx) + 2):
			var sample_gx = roundi((cell_x + 0.5) * cell_size)
			var sample_gy = roundi((cell_y + 0.5) * cell_size)
			if get_biome_id_at(sample_gx, sample_gy) not in biomes:
				continue

			var spawn_hash = _hash_float("dg_%s" % spawn_group, cell_x, cell_y)
			var ecology = _sample_ecology_layers(sample_gx, sample_gy)
			var eco_mult = _get_ecology_spawn_multiplier(definition, ecology)
			var region_mult = _get_region_spawn_multiplier(definition, sample_gx, sample_gy, "dec")
			var water_mult = _get_water_spawn_multiplier(definition, sample_gx, sample_gy)
			var density = grid_density * eco_mult * region_mult * water_mult
			if density <= 0.0 or spawn_hash >= density:
				continue

			var jx = _hash_float("dg_jx_%s" % spawn_group, cell_x, cell_y)
			var jy = _hash_float("dg_jy_%s" % spawn_group, cell_x, cell_y)
			var pos_x = (cell_x + jx) * cell_size
			var pos_y = (cell_y + jy) * cell_size

			var tile_x = floori(pos_x / _tile_size)
			var tile_y = floori(pos_y / _tile_size)
			if tile_x < base_x or tile_x >= base_x + CHUNK_SIZE:
				continue
			if tile_y < base_y or tile_y >= base_y + CHUNK_SIZE:
				continue
			if get_biome_id_at(tile_x, tile_y) not in biomes:
				continue
			if is_zero_approx(_get_water_spawn_multiplier(definition, tile_x, tile_y)):
				continue

			var tex: Texture2D = textures[_hash_index(textures.size(), "%s_texture" % definition["id"], cell_x, cell_y)]
			var sprite = Sprite2D.new()
			sprite.position = Vector2(pos_x, pos_y)
			sprite.centered = true
			sprite.texture = tex
			sprite.z_index = definition.get("z_index", 2)
			var ds = definition.get("scale", 1.0)
			sprite.scale = Vector2(ds, ds)
			_object_node.add_child(sprite)
			chunk_nodes.append(sprite)


func _spawn_deco_per_tile(cx: int, cy: int, definition: Dictionary, chunk_nodes: Array) -> void:
	var biomes: Array = definition.get("biomes", [])
	var textures = _get_resource_textures(definition)
	if textures.is_empty():
		return
	var base_x = cx * CHUNK_SIZE
	var base_y = cy * CHUNK_SIZE
	var z_idx = definition.get("z_index", 2)
	var placement_step = max(1, int(definition.get("placement_step", 2 if definition.get("clustered", false) else 1)))

	for y in range(0, CHUNK_SIZE, placement_step):
		for x in range(0, CHUNK_SIZE, placement_step):
			var gx = base_x + x
			var gy = base_y + y
			if get_biome_id_at(gx, gy) not in biomes:
				continue
			if not _should_spawn_definition_at(definition, gx, gy, "dec"):
				continue

			var offset_x = lerpf(-_tile_size / 3.0, _tile_size / 3.0, _hash_float("%s_offset_x" % definition["id"], gx, gy))
			var offset_y = lerpf(-_tile_size / 3.0, _tile_size / 3.0, _hash_float("%s_offset_y" % definition["id"], gx, gy))
			var pos = Vector2(gx * _tile_size + _tile_size / 2.0 + offset_x, gy * _tile_size + _tile_size / 2.0 + offset_y)
			var tex: Texture2D = textures[_hash_index(textures.size(), "%s_texture" % definition["id"], gx, gy)]

			var sprite = Sprite2D.new()
			sprite.position = pos
			sprite.centered = true
			sprite.texture = tex
			sprite.z_index = z_idx
			var ds = definition.get("scale", 1.0)
			sprite.scale = Vector2(ds, ds)
			_object_node.add_child(sprite)
			chunk_nodes.append(sprite)
