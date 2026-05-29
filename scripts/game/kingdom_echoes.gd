extends Node2D
class_name OfflineGame

## 离线单机模式 — 无限 chunk 世界 + 资源采集 + 背包 + 制造 + 昼夜循环

const TILE_SIZE: int = 64
const LAND_BIOME_IDS: Array[String] = ["grass", "dirt", "sand", "snow", "swamp", "forest_floor", "stone_path"]
# 树木只在草地、林地等适宜地形生长，排除泥土层(dirt)与沙漠层(sand)
const TREE_BIOME_IDS: Array[String] = ["grass", "snow", "swamp", "forest_floor", "stone_path"]
const MIN_CHUNK_VIEW_RADIUS: int = 3
const MAX_CHUNK_VIEW_RADIUS: int = 4
const CHUNK_VIEW_MARGIN: int = 1
const CHUNK_LOADS_PER_FRAME: int = 4
const CHUNK_UNLOADS_PER_FRAME: int = 2
const CHUNK_QUEUE_FRAME_INTERVAL: int = 1
const CONTENT_JOBS_PER_FRAME: int = 4
const MAX_TERRAIN_WORKER_JOBS: int = 8
# 点击"开始游戏"时只同步加载玩家周围这么多个核心区块（保证脚下不空），
# 其余视野区块与全部内容（树木/花草）进入游戏后逐帧异步补齐，避免长时间卡顿。
const INITIAL_SYNC_CHUNKS: int = 25
const TERRAIN_APPLIES_PER_FRAME: int = 2
const TERRAIN_TILESET_PATH: String = "res://assets/tilesets/world_terrain_tileset.tres"
const TREE_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/trees/tree_01.png",
	"res://assets/vegetation/trees/tree_02.png",
	"res://assets/vegetation/trees/tree_03.png",
	"res://assets/vegetation/trees/tree_04.png",
	"res://assets/vegetation/trees/tree_05.png",
	"res://assets/vegetation/trees/tree_06.png",
]
const ROUND_TREE_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/trees/tree_01.png",
	"res://assets/vegetation/trees/tree_02.png",
	"res://assets/vegetation/trees/tree_03.png",
	"res://assets/vegetation/trees/tree_04.png",
]
const CONIFER_TREE_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/trees/tree_05.png",
	"res://assets/vegetation/trees/tree_06.png",
]
const GRASS_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/grass/grass_01.png",
	"res://assets/vegetation/grass/grass_02.png",
	"res://assets/vegetation/grass/grass_03.png",
	"res://assets/vegetation/grass/grass_04.png",
	"res://assets/vegetation/grass/grass_05.png",
	"res://assets/vegetation/grass/grass_06.png",
	"res://assets/vegetation/grass/grass_07.png",
	"res://assets/vegetation/grass/grass_08.png",
	"res://assets/vegetation/grass/grass_09.png",
]
const MUSHROOM_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/mushrooms/mushroom_01.png",
	"res://assets/vegetation/mushrooms/mushroom_02.png",
	"res://assets/vegetation/mushrooms/mushroom_03.png",
]
const ROCK_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/rocks/rock_01.png",
	"res://assets/vegetation/rocks/rock_02.png",
	"res://assets/vegetation/rocks/rock_03.png",
]
const TWIG_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/twigs/twig_01.png",
	"res://assets/vegetation/twigs/twig_02.png",
	"res://assets/vegetation/twigs/twig_03.png",
]
const LEAF_PILE_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/leaves/leaf_pile_01.png",
	"res://assets/vegetation/leaves/leaf_pile_02.png",
]
const TALL_GRASS_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/tall_grass/tall_grass_01.png",
	"res://assets/vegetation/tall_grass/tall_grass_02.png",
]
const FLOWER_TEXTURE_PATHS: Array[String] = [
	"res://assets/vegetation/flowers/flower_01.png",
	"res://assets/vegetation/flowers/flower_02.png",
	"res://assets/vegetation/flowers/flower_03.png",
	"res://assets/vegetation/flowers/flower_04.png",
]
const TerrainChunkWorkerScript = preload("res://scripts/game/terrain_chunk_worker.gd")
const PLAYER_SCENE = preload("res://scenes/player.tscn")

# ============ 可在 Inspector 实时调整的世界生成参数 ============
# 打开 scenes/kingdom_echoes.tscn、选中根节点 OfflineGame，即可在右侧 Inspector 调这些值。
@export_group("植被疏密")
## 地被(花草/树枝/石头)间距系数，越大越稀疏
@export var vegetation_spacing_scale: float = 10.0
## 树木间距系数，越大越稀疏（树木单独控制，不受上面影响）
@export var tree_spacing_scale: float = 1.2

@export_group("森林生态")
## 阔叶树偏好温度（0=最冷，1=最暖）
@export_range(0.0, 1.0) var broadleaf_temperature: float = 0.62
## 针叶树偏好温度（越低越往寒冷/雪地分布）
@export_range(0.0, 1.0) var conifer_temperature: float = 0.30
## 针叶林海拔上限（越大，树线越高、雪山上的树越多）
@export_range(0.0, 1.0) var conifer_tree_line: float = 0.55
## 温度容差（越大，阔叶↔针叶之间的混交过渡带越宽）
@export_range(0.1, 0.6) var mixed_zone_width: float = 0.38

var player: CharacterBody2D = null
var player_sprite: Sprite2D = null
var camera: Camera2D = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var terrain_root: Node2D = null
var object_root: Node2D = null
var ecology_debug_overlay: EcologyDebugOverlay = null

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
var _last_chunk_view_radius: int = -1
var _desired_chunks: Array[Vector2i] = []
var _loaded_chunks: Array[Vector2i] = []
var _pending_load_chunks: Array[Vector2i] = []
var _pending_content_chunks: Array[Vector2i] = []
var _pending_decoration_chunks: Array[Vector2i] = []
var _pending_resource_jobs: Array[Dictionary] = []
var _pending_decoration_jobs: Array[Dictionary] = []
var _pending_unload_chunks: Array[Vector2i] = []
var _content_loaded_chunks: Array[Vector2i] = []
var _active_terrain_jobs: Dictionary = {}
var _terrain_worker_context: Dictionary = {}
var _chunk_queue_frame_skip: int = 0


func _ready() -> void:
	rng.randomize()  # 每次进入游戏随机生成不同的世界
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
		{"id": "tree_round", "item": "wood", "qty": 3, "name": "阔叶树",
		 "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": TREE_BIOME_IDS, "density": 0.001, "z_index": 2, "scale": 0.36, "spacing_scale": tree_spacing_scale, "textures": _load_round_tree_textures(), "anchor": "bottom", "collision_radius": 12.0, "collision_offset": Vector2(0, -9),
		 "placement_mode": "poisson_grid", "grid_cell_size": 150, "grid_density": 0.54, "candidate_multiplier": 14, "min_distance_factor": 0.74, "water_clearance": 3, "water_falloff": 6, "block_on_water": true, "cluster_group": "round_forest", "region_noise": {"group": "round_forest", "frequency": 0.014, "threshold": 0.50, "softness": 0.16, "min_multiplier": 0.05, "power": 1.45, "octaves": 4, "gain": 0.56}, "ecology": {"temperature": {"target": broadleaf_temperature, "tolerance": mixed_zone_width, "gate": true}, "moisture": {"target": 0.62, "tolerance": 0.34}, "soil_depth": {"target": 0.72, "tolerance": 0.34}, "elevation": {"target": 0.38, "tolerance": 0.34, "gate": true}, "min_multiplier": 0.04}},
		{"id": "tree_conifer", "item": "wood", "qty": 3, "name": "针叶树",
		 "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": TREE_BIOME_IDS, "density": 0.001, "z_index": 2, "scale": 0.40, "spacing_scale": tree_spacing_scale, "textures": _load_conifer_tree_textures(), "anchor": "bottom", "collision_radius": 11.0, "collision_offset": Vector2(0, -9),
		 "placement_mode": "poisson_grid", "grid_cell_size": 142, "grid_density": 0.50, "candidate_multiplier": 14, "min_distance_factor": 0.78, "water_clearance": 3, "water_falloff": 6, "block_on_water": true, "cluster_group": "conifer_forest", "region_noise": {"group": "conifer_forest", "frequency": 0.014, "threshold": 0.50, "softness": 0.16, "min_multiplier": 0.05, "power": 1.45, "octaves": 4, "gain": 0.56}, "ecology": {"temperature": {"target": conifer_temperature, "tolerance": mixed_zone_width, "gate": true}, "moisture": {"target": 0.55, "tolerance": 0.36}, "soil_depth": {"target": 0.50, "tolerance": 0.38}, "elevation": {"target": conifer_tree_line, "tolerance": 0.40, "gate": true}, "min_multiplier": 0.04}},
		{"id": "copper_ore", "item": "copper_ore", "qty": 2, "name": "铜矿",
		 "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.WOOD,
		 "biomes": ["stone_path", "sand"], "density": 0.004, "z_index": 1, "scale": 1.5, "placement_mode": "poisson_grid", "grid_cell_size": 130, "grid_density": 0.4, "candidate_multiplier": 8, "min_distance_factor": 0.5,
		 "texture": TextureGen.get_ore_texture(Color(0.72, 0.42, 0.18), Color(0.95, 0.65, 0.2))},
		{"id": "iron_ore", "item": "iron_ore", "qty": 2, "name": "铁矿",
		 "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.STONE,
		 "biomes": ["stone_path", "dirt"], "density": 0.005, "z_index": 1, "scale": 1.5, "placement_mode": "poisson_grid", "grid_cell_size": 130, "grid_density": 0.4, "candidate_multiplier": 8, "min_distance_factor": 0.5,
		 "texture": TextureGen.get_ore_texture(Color(0.45, 0.42, 0.48), Color(0.65, 0.62, 0.7))},
		{"id": "stone_node", "item": "stone", "qty": 3, "name": "石头",
		 "harvest_type": -1, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": ["dirt", "stone_path"], "density": 0.008, "z_index": 1, "scale": 1.5, "placement_mode": "poisson_grid", "grid_cell_size": 120, "grid_density": 0.45, "candidate_multiplier": 8, "min_distance_factor": 0.5,
		 "texture": TextureGen.get_stone_texture()},
		{"id": "herb_red", "item": "herb_red", "qty": 2, "name": "药草",
		 "harvest_type": SharedEnums.HarvestType.HERB, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": LAND_BIOME_IDS, "density": 0.010, "z_index": 1, "scale": 0.5, "textures": _load_flower_textures(), "position_jitter": 0.46, "block_on_water": true, "placement_mode": "poisson_grid", "grid_cell_size": 84, "grid_density": 0.40, "candidate_multiplier": 12, "min_distance_factor": 0.42,
		 "clustered": true, "cluster_group": "meadow", "cluster_cell_size": 80, "cluster_chance": 0.40, "cluster_radius_min": 12.0, "cluster_radius_max": 34.0, "cluster_density": 0.10, "scatter_density": 0.002, "region_noise": {"group": "meadow", "frequency": 0.018, "threshold": 0.42, "softness": 0.20, "min_multiplier": 0.12}, "ecology": {"temperature": {"target": 0.56, "tolerance": 0.40}, "moisture": {"target": 0.54, "tolerance": 0.36}, "soil_depth": {"target": 0.62, "tolerance": 0.34}, "elevation": {"target": 0.42, "tolerance": 0.38, "weight": 0.70}, "min_multiplier": 0.15}},
		{"id": "fiber_plant", "item": "fiber", "qty": 2, "name": "纤维植物",
		 "harvest_type": SharedEnums.HarvestType.FIBER, "tool_tier": SharedEnums.ToolTier.NONE,
		 "biomes": LAND_BIOME_IDS, "density": 0.008, "z_index": 1, "scale": 0.42, "textures": _load_grass_textures(), "position_jitter": 0.46, "block_on_water": true, "placement_mode": "poisson_grid", "grid_cell_size": 90, "grid_density": 0.36, "candidate_multiplier": 12, "min_distance_factor": 0.44,
		 "clustered": true, "cluster_group": "wet_grass", "cluster_cell_size": 82, "cluster_chance": 0.42, "cluster_radius_min": 14.0, "cluster_radius_max": 38.0, "cluster_density": 0.11, "scatter_density": 0.001, "region_noise": {"group": "wet_grass", "frequency": 0.016, "threshold": 0.44, "softness": 0.22, "min_multiplier": 0.10}, "ecology": {"temperature": {"target": 0.52, "tolerance": 0.42}, "moisture": {"target": 0.72, "tolerance": 0.24}, "soil_depth": {"target": 0.66, "tolerance": 0.30}, "elevation": {"target": 0.30, "tolerance": 0.34, "weight": 0.80}, "min_multiplier": 0.12}},
	]

	var decoration_defs: Array[Dictionary] = _build_decoration_defs()

	# 创建 WorldGenerator
	world_generator = WorldGenerator.new()
	world_generator.setup(rng, TILE_SIZE)
	world_generator.vegetation_spacing_scale = vegetation_spacing_scale  # 应用 Inspector 里的地被疏密设置
	world_generator.set_biome_configs(biome_configs)
	world_generator.set_resource_defs(resource_defs)
	world_generator.set_decoration_defs(decoration_defs)
	_configure_terrain_tileset()
	world_generator.init_chunks(terrain_root, object_root)
	_terrain_worker_context = world_generator.make_chunk_terrain_context()
	ecology_debug_overlay.setup(world_generator, TILE_SIZE)

	# 引用 WorldGenerator 内部字典（共享引用）
	resource_sprites = world_generator.resource_sprites
	resource_data = world_generator.resource_data

	_create_player()
	_setup_camera()
	_init_systems()

	# 初始只同步加载玩家周围的核心区块，避免点击"开始游戏"后长时间卡顿；
	# 其余视野范围内的区块与所有内容（树木/花草）改为进入游戏后逐帧异步补齐。
	var start_chunk = WorldGenerator.world_position_to_chunk(player.position, TILE_SIZE)
	_update_chunks(start_chunk.x, start_chunk.y)
	_drain_initial_terrain_jobs(INITIAL_SYNC_CHUNKS)

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


func _exit_tree() -> void:
	for key in _active_terrain_jobs.keys():
		var job: Dictionary = _active_terrain_jobs[key]
		var thread: Thread = job.get("thread", null)
		if thread != null and thread.is_started():
			thread.wait_to_finish()
	_active_terrain_jobs.clear()


# ========== Chunk 管理 ==========

func _configure_terrain_tileset() -> void:
	if not FileAccess.file_exists(TERRAIN_TILESET_PATH):
		return
	var tile_set = load(TERRAIN_TILESET_PATH) as TileSet
	if tile_set == null:
		push_error("OfflineGame: Failed to load terrain tileset: %s" % TERRAIN_TILESET_PATH)
		return
	world_generator.set_layered_terrain_tileset(tile_set, 0, 0, {
		WorldGenerator.BIOME_DIRT: 1,
		WorldGenerator.BIOME_SAND: 2,
		WorldGenerator.BIOME_SNOW: 3,
		WorldGenerator.BIOME_SWAMP: 1,
		WorldGenerator.BIOME_STONE: 1,
		WorldGenerator.BIOME_WATER: 4,
	}, true)
	world_generator.set_terrain_paint_mode(WorldGenerator.TERRAIN_PAINT_GLOBAL_NEIGHBORS)


func _create_world_layers() -> void:
	terrain_root = Node2D.new()
	terrain_root.name = "TerrainChunks"
	add_child(terrain_root)

	ecology_debug_overlay = EcologyDebugOverlay.new()
	ecology_debug_overlay.name = "EcologyDebugOverlay"
	add_child(ecology_debug_overlay)

	object_root = Node2D.new()
	object_root.name = "WorldObjects"
	object_root.y_sort_enabled = true
	add_child(object_root)


func _update_chunks(cx: int, cy: int) -> void:
	var r = _get_chunk_view_radius()
	if cx == _last_chunk.x and cy == _last_chunk.y and r == _last_chunk_view_radius:
		return
	_last_chunk = Vector2i(cx, cy)
	_last_chunk_view_radius = r

	var desired: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			desired.append(Vector2i(cx + dx, cy + dy))
	desired.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da = abs(a.x - cx) + abs(a.y - cy)
		var db = abs(b.x - cx) + abs(b.y - cy)
		return da < db
	)

	_desired_chunks = desired

	for key in _loaded_chunks:
		if key not in desired:
			_queue_chunk_unload(key)

	_pending_load_chunks.clear()
	_pending_content_chunks = _pending_content_chunks.filter(func(key: Vector2i) -> bool:
		return key in desired
	)
	_pending_decoration_chunks = _pending_decoration_chunks.filter(func(key: Vector2i) -> bool:
		return key in desired
	)
	_pending_resource_jobs = _pending_resource_jobs.filter(func(job: Dictionary) -> bool:
		return job.get("chunk", Vector2i.ZERO) in desired
	)
	_pending_decoration_jobs = _pending_decoration_jobs.filter(func(job: Dictionary) -> bool:
		return job.get("chunk", Vector2i.ZERO) in desired
	)
	_content_loaded_chunks = _content_loaded_chunks.filter(func(key: Vector2i) -> bool:
		return key in desired
	)
	for key in desired:
		_pending_unload_chunks.erase(key)
		if key not in _loaded_chunks:
			_queue_chunk_load(key)

	if ecology_debug_overlay:
		ecology_debug_overlay.set_chunks(_desired_chunks)


func _get_chunk_view_radius() -> int:
	if camera == null:
		return MIN_CHUNK_VIEW_RADIUS + CHUNK_VIEW_MARGIN
	var viewport_size = get_viewport_rect().size
	var zoom_x = maxf(camera.zoom.x, 0.001)
	var zoom_y = maxf(camera.zoom.y, 0.001)
	var visible_tiles_x = viewport_size.x / (float(TILE_SIZE) * zoom_x)
	var visible_tiles_y = viewport_size.y / (float(TILE_SIZE) * zoom_y)
	var visible_chunk_radius = ceili(maxf(visible_tiles_x, visible_tiles_y) / float(WorldGenerator.CHUNK_SIZE) * 0.5)
	return max(MIN_CHUNK_VIEW_RADIUS, min(MAX_CHUNK_VIEW_RADIUS, visible_chunk_radius + CHUNK_VIEW_MARGIN))


func _get_initial_chunk_load_budget() -> int:
	var radius = _get_chunk_view_radius()
	return int(pow(radius * 2 + 1, 2))


func _queue_chunk_load(key: Vector2i) -> void:
	if key in _pending_load_chunks:
		return
	_pending_unload_chunks.erase(key)
	_pending_load_chunks.append(key)


func _queue_chunk_content(key: Vector2i) -> void:
	if key in _content_loaded_chunks:
		return
	if key in _pending_content_chunks:
		return
	_pending_content_chunks.append(key)


func _queue_chunk_decoration(key: Vector2i) -> void:
	if key in _pending_decoration_chunks:
		return
	_pending_decoration_chunks.append(key)


func _queue_chunk_resource_jobs(key: Vector2i) -> void:
	for i in range(world_generator.get_resource_definition_count()):
		_pending_resource_jobs.append({"chunk": key, "index": i})


func _queue_chunk_decoration_jobs(key: Vector2i) -> void:
	for i in range(world_generator.get_decoration_definition_count()):
		_pending_decoration_jobs.append({"chunk": key, "index": i})


func _queue_chunk_unload(key: Vector2i) -> void:
	if key in _pending_unload_chunks:
		return
	_pending_load_chunks.erase(key)
	_pending_content_chunks.erase(key)
	_pending_decoration_chunks.erase(key)
	_pending_resource_jobs = _pending_resource_jobs.filter(func(job: Dictionary) -> bool:
		return job.get("chunk", Vector2i.ZERO) != key
	)
	_pending_decoration_jobs = _pending_decoration_jobs.filter(func(job: Dictionary) -> bool:
		return job.get("chunk", Vector2i.ZERO) != key
	)
	_content_loaded_chunks.erase(key)
	_pending_unload_chunks.append(key)


func _process_chunk_queues(load_budget: int = CHUNK_LOADS_PER_FRAME, unload_budget: int = CHUNK_UNLOADS_PER_FRAME) -> void:
	_collect_finished_terrain_jobs()

	var can_load_terrain = true
	if load_budget == CHUNK_LOADS_PER_FRAME and unload_budget == CHUNK_UNLOADS_PER_FRAME:
		_chunk_queue_frame_skip = (_chunk_queue_frame_skip + 1) % CHUNK_QUEUE_FRAME_INTERVAL
		if _chunk_queue_frame_skip != 0:
			can_load_terrain = false

	var unload_count = min(unload_budget, _pending_unload_chunks.size())
	for i in range(unload_count):
		var key = _pending_unload_chunks.pop_front()
		_loaded_chunks.erase(key)
		world_generator.unload_chunk(key.x, key.y)

	if can_load_terrain:
		var load_count = min(load_budget, _pending_load_chunks.size(), max(0, MAX_TERRAIN_WORKER_JOBS - _active_terrain_jobs.size()))
		for i in range(load_count):
			var key = _pending_load_chunks.pop_front()
			if key not in _desired_chunks or key in _loaded_chunks:
				continue
			_start_terrain_job(key)

	if load_budget > CHUNK_LOADS_PER_FRAME:
		_drain_initial_terrain_jobs()

	for i in range(CONTENT_JOBS_PER_FRAME):
		if not _run_next_content_job():
			return


func _start_terrain_job(key: Vector2i) -> void:
	if key in _active_terrain_jobs or key in _loaded_chunks:
		return

	var thread = Thread.new()
	var worker = TerrainChunkWorkerScript.new()
	var error = thread.start(Callable(worker, "build_chunk_terrain_data").bind(_terrain_worker_context, key.x, key.y))
	if error != OK:
		push_warning("OfflineGame: Terrain worker failed for chunk %s, falling back to synchronous generation." % key)
		world_generator.generate_chunk(key.x, key.y, false)
		_loaded_chunks.append(key)
		_queue_chunk_content(key)
		return
	_active_terrain_jobs[key] = {"thread": thread, "worker": worker}


func _collect_finished_terrain_jobs(apply_budget: int = TERRAIN_APPLIES_PER_FRAME) -> void:
	var applied = 0
	for key in _active_terrain_jobs.keys():
		if applied >= apply_budget:
			return
		var job: Dictionary = _active_terrain_jobs[key]
		var thread: Thread = job.get("thread", null)
		if thread == null:
			_active_terrain_jobs.erase(key)
			continue
		if thread.is_alive():
			continue
		var terrain_data = thread.wait_to_finish()
		_active_terrain_jobs.erase(key)
		if key not in _desired_chunks or key in _loaded_chunks:
			continue
		world_generator.apply_chunk_terrain_data(terrain_data)
		_loaded_chunks.append(key)
		_queue_chunk_content(key)
		applied += 1


func _drain_initial_terrain_jobs(max_chunks: int = -1) -> void:
	# max_chunks < 0 表示排空全部待加载区块（旧行为）；
	# max_chunks >= 0 时只同步加载最近的 max_chunks 个区块，其余留给逐帧异步加载。
	var loaded_at_start = _loaded_chunks.size()
	var safety_frames = 10000
	while (not _pending_load_chunks.is_empty() or not _active_terrain_jobs.is_empty()) and safety_frames > 0:
		_collect_finished_terrain_jobs(_get_initial_chunk_load_budget())
		if max_chunks >= 0 and (_loaded_chunks.size() - loaded_at_start) >= max_chunks and _active_terrain_jobs.is_empty():
			break
		var can_start = max(0, MAX_TERRAIN_WORKER_JOBS - _active_terrain_jobs.size())
		if max_chunks >= 0:
			var remaining = max_chunks - (_loaded_chunks.size() - loaded_at_start) - _active_terrain_jobs.size()
			can_start = min(can_start, max(0, remaining))
		var start_count = min(_pending_load_chunks.size(), can_start)
		for i in range(start_count):
			var key = _pending_load_chunks.pop_front()
			if key in _desired_chunks and key not in _loaded_chunks:
				_start_terrain_job(key)
		OS.delay_msec(1)
		safety_frames -= 1
	_collect_finished_terrain_jobs(_get_initial_chunk_load_budget())


func _run_next_content_job() -> bool:
	if not _pending_resource_jobs.is_empty():
		var job = _pending_resource_jobs.pop_front()
		var key: Vector2i = job.get("chunk", Vector2i.ZERO)
		if key in _desired_chunks and key in _loaded_chunks and key not in _content_loaded_chunks:
			world_generator.populate_chunk_resource_definition(key.x, key.y, int(job.get("index", 0)))
		return true

	if not _pending_decoration_chunks.is_empty():
		var key = _pending_decoration_chunks.pop_front()
		if key in _desired_chunks and key in _loaded_chunks and key not in _content_loaded_chunks:
			_queue_chunk_decoration_jobs(key)
		return true

	if not _pending_decoration_jobs.is_empty():
		var job = _pending_decoration_jobs.pop_front()
		var key: Vector2i = job.get("chunk", Vector2i.ZERO)
		if key in _desired_chunks and key in _loaded_chunks and key not in _content_loaded_chunks:
			world_generator.populate_chunk_decoration_definition(key.x, key.y, int(job.get("index", 0)))
			if not _has_pending_content_work(key):
				_mark_chunk_content_loaded(key)
		return true

	if not _pending_content_chunks.is_empty():
		var key = _pending_content_chunks.pop_front()
		if key in _desired_chunks and key in _loaded_chunks and key not in _content_loaded_chunks:
			_queue_chunk_resource_jobs(key)
			_queue_chunk_decoration(key)
		return true

	return false


func _has_pending_content_work(key: Vector2i) -> bool:
	if key in _pending_content_chunks or key in _pending_decoration_chunks:
		return true
	for job in _pending_resource_jobs:
		if job.get("chunk", Vector2i.ZERO) == key:
			return true
	for job in _pending_decoration_jobs:
		if job.get("chunk", Vector2i.ZERO) == key:
			return true
	return false


func _mark_chunk_content_loaded(key: Vector2i) -> void:
	if key not in _content_loaded_chunks:
		_content_loaded_chunks.append(key)
	_pending_content_chunks.erase(key)
	_pending_decoration_chunks.erase(key)
	_pending_resource_jobs = _pending_resource_jobs.filter(func(job: Dictionary) -> bool:
		return job.get("chunk", Vector2i.ZERO) != key
	)
	_pending_decoration_jobs = _pending_decoration_jobs.filter(func(job: Dictionary) -> bool:
		return job.get("chunk", Vector2i.ZERO) != key
	)


# ========== 玩家 ==========

func _create_player() -> void:
	# 玩家的节点结构（碰撞体/精灵/名字标签）都在 res://scenes/player.tscn 里可视化编辑，
	# 这里只实例化并设置运行时才能确定的东西（出生位置、程序生成的贴图）。
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(50 * TILE_SIZE, 37 * TILE_SIZE)
	player_sprite = player.get_node("Sprite")
	player_sprite.texture = TextureGen.get_player_texture()
	object_root.add_child(player)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.zoom = Vector2(0.35, 0.35)
	if player:
		camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()
	camera.reset_smoothing()


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
	_process_chunk_queues()

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
	if event is InputEventKey and event.pressed and not event.is_echo() and (event as InputEventKey).keycode == KEY_TAB:
		_cycle_ecology_debug_layer()

	# 初始地形预加载期间各控制器尚未创建，跳过依赖它们的输入，避免对 Nil 的空引用
	if build_controller == null or hud_controller == null:
		return

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


func _cycle_ecology_debug_layer() -> void:
	if ecology_debug_overlay == null:
		return
	var layer_label = ecology_debug_overlay.cycle_layer()
	print("[Debug] Ecology overlay: %s" % layer_label)


# ========== 装饰物 ==========

func _build_decoration_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	var grass_textures = _load_grass_textures()
	var flower_textures = _load_flower_textures()
	var mushroom_textures = _load_mushroom_textures()
	var rock_textures = _load_rock_textures()
	var twig_textures = _load_twig_textures()
	var leaf_pile_textures = _load_leaf_pile_textures()
	var tall_grass_textures = _load_tall_grass_textures()
	var deco_specs = [
		{"id": "flower", "biomes": LAND_BIOME_IDS, "density": 0.020, "z_index": 2, "scale": 0.46, "textures": flower_textures, "placement_mode": "poisson_grid", "grid_cell_size": 86, "grid_density": 0.42, "candidate_multiplier": 12, "min_distance_factor": 0.42, "position_jitter": 0.46, "block_on_water": true, "clustered": true, "cluster_group": "meadow", "cluster_cell_size": 74, "cluster_chance": 0.48, "cluster_radius_min": 10.0, "cluster_radius_max": 30.0, "cluster_density": 0.19, "scatter_density": 0.002, "region_noise": {"group": "meadow", "frequency": 0.018, "threshold": 0.43, "softness": 0.21, "min_multiplier": 0.08}, "ecology": {"temperature": {"target": 0.58, "tolerance": 0.38}, "moisture": {"target": 0.52, "tolerance": 0.34}, "soil_depth": {"target": 0.64, "tolerance": 0.32}, "elevation": {"target": 0.42, "tolerance": 0.38, "weight": 0.70}, "min_multiplier": 0.10}},
		{"id": "grass_tuft", "biomes": LAND_BIOME_IDS, "density": 0.030, "z_index": 2, "scale": 0.34, "textures": grass_textures, "placement_mode": "poisson_grid", "grid_cell_size": 78, "grid_density": 0.54, "candidate_multiplier": 12, "min_distance_factor": 0.38, "position_jitter": 0.46, "block_on_water": true, "clustered": true, "cluster_group": "meadow", "cluster_cell_size": 72, "cluster_chance": 0.56, "cluster_radius_min": 12.0, "cluster_radius_max": 34.0, "cluster_density": 0.25, "scatter_density": 0.003, "region_noise": {"group": "meadow", "frequency": 0.017, "threshold": 0.40, "softness": 0.23, "min_multiplier": 0.12}, "ecology": {"temperature": {"target": 0.54, "tolerance": 0.42}, "moisture": {"target": 0.58, "tolerance": 0.36}, "soil_depth": {"target": 0.60, "tolerance": 0.36}, "elevation": {"target": 0.38, "tolerance": 0.40, "weight": 0.65}, "min_multiplier": 0.12}},
		{"id": "mushroom", "biomes": LAND_BIOME_IDS, "density": 0.010, "z_index": 2, "scale": 0.44, "textures": mushroom_textures, "placement_mode": "poisson_grid", "grid_cell_size": 96, "grid_density": 0.30, "candidate_multiplier": 10, "min_distance_factor": 0.40, "position_jitter": 0.46, "block_on_water": true, "clustered": true, "cluster_group": "fungi", "cluster_cell_size": 84, "cluster_chance": 0.34, "cluster_radius_min": 8.0, "cluster_radius_max": 24.0, "cluster_density": 0.17, "scatter_density": 0.001, "region_noise": {"group": "fungi", "frequency": 0.020, "threshold": 0.48, "softness": 0.20, "min_multiplier": 0.04}, "ecology": {"temperature": {"target": 0.48, "tolerance": 0.34}, "moisture": {"target": 0.78, "tolerance": 0.22}, "soil_depth": {"target": 0.70, "tolerance": 0.26}, "elevation": {"target": 0.36, "tolerance": 0.32, "weight": 0.75}, "min_multiplier": 0.05}},
		# 泥土层/沙漠层的零星点缀（真实树枝、石头素材；间距用默认点缀级稀疏度）
		{"id": "ground_branch", "biomes": ["dirt", "sand"], "z_index": 1, "scale": 0.4, "textures": twig_textures, "placement_mode": "poisson_grid", "grid_cell_size": 96, "grid_density": 0.5, "candidate_multiplier": 10, "min_distance_factor": 0.5, "position_jitter": 0.42},
		{"id": "ground_rock", "biomes": ["dirt", "sand"], "z_index": 1, "scale": 0.42, "textures": rock_textures, "placement_mode": "poisson_grid", "grid_cell_size": 108, "grid_density": 0.45, "candidate_multiplier": 10, "min_distance_factor": 0.5, "position_jitter": 0.42},
		{"id": "bush_small", "biomes": ["grass", "forest_floor"], "density": 0.010, "z_index": 3, "scale": 0.6, "textures": grass_textures, "placement_mode": "poisson_grid", "grid_cell_size": 132, "grid_density": 0.34, "candidate_multiplier": 10, "min_distance_factor": 0.46, "position_jitter": 0.42},
		{"id": "berry_bush", "biomes": ["forest_floor", "swamp"], "density": 0.008, "z_index": 3, "scale": 0.6, "textures": flower_textures, "placement_mode": "poisson_grid", "grid_cell_size": 144, "grid_density": 0.30, "candidate_multiplier": 10, "min_distance_factor": 0.48, "position_jitter": 0.42},
		{"id": "leaf_pile", "biomes": LAND_BIOME_IDS, "density": 0.025, "z_index": 1, "scale": 0.43, "textures": leaf_pile_textures, "placement_mode": "poisson_grid", "grid_cell_size": 88, "grid_density": 0.36, "candidate_multiplier": 10, "min_distance_factor": 0.40, "position_jitter": 0.46, "block_on_water": true, "clustered": true, "cluster_group": "forest", "cluster_cell_size": 88, "cluster_chance": 0.46, "cluster_radius_min": 10.0, "cluster_radius_max": 30.0, "cluster_density": 0.18, "scatter_density": 0.002, "region_noise": {"group": "forest_litter", "frequency": 0.010, "threshold": 0.44, "softness": 0.24, "min_multiplier": 0.08}, "ecology": {"temperature": {"target": 0.52, "tolerance": 0.38}, "moisture": {"target": 0.68, "tolerance": 0.28}, "soil_depth": {"target": 0.72, "tolerance": 0.26}, "elevation": {"target": 0.44, "tolerance": 0.34, "weight": 0.75}, "min_multiplier": 0.10}},
		{"id": "twig", "biomes": LAND_BIOME_IDS, "density": 0.025, "z_index": 1, "scale": 0.44, "textures": twig_textures, "placement_mode": "poisson_grid", "grid_cell_size": 92, "grid_density": 0.38, "candidate_multiplier": 10, "min_distance_factor": 0.38, "position_jitter": 0.46, "block_on_water": true, "clustered": true, "cluster_group": "forest", "cluster_cell_size": 86, "cluster_chance": 0.44, "cluster_radius_min": 10.0, "cluster_radius_max": 28.0, "cluster_density": 0.18, "scatter_density": 0.003, "region_noise": {"group": "forest_litter", "frequency": 0.010, "threshold": 0.43, "softness": 0.24, "min_multiplier": 0.08}, "ecology": {"temperature": {"target": 0.52, "tolerance": 0.40}, "moisture": {"target": 0.64, "tolerance": 0.32}, "soil_depth": {"target": 0.68, "tolerance": 0.30}, "elevation": {"target": 0.42, "tolerance": 0.36, "weight": 0.75}, "min_multiplier": 0.10}},
		{"id": "tall_grass", "biomes": LAND_BIOME_IDS, "density": 0.020, "z_index": 2, "scale": 0.38, "textures": tall_grass_textures, "placement_mode": "poisson_grid", "grid_cell_size": 82, "grid_density": 0.38, "candidate_multiplier": 12, "min_distance_factor": 0.44, "position_jitter": 0.46, "block_on_water": true, "clustered": true, "cluster_group": "wet_grass", "cluster_cell_size": 78, "cluster_chance": 0.46, "cluster_radius_min": 12.0, "cluster_radius_max": 36.0, "cluster_density": 0.18, "scatter_density": 0.001, "region_noise": {"group": "wet_grass", "frequency": 0.016, "threshold": 0.44, "softness": 0.22, "min_multiplier": 0.08}, "ecology": {"temperature": {"target": 0.52, "tolerance": 0.42}, "moisture": {"target": 0.74, "tolerance": 0.24}, "soil_depth": {"target": 0.66, "tolerance": 0.30}, "elevation": {"target": 0.28, "tolerance": 0.34, "weight": 0.85}, "min_multiplier": 0.10}},
	]
	for spec in deco_specs:
		if spec.has("textures") and (spec["textures"] as Array).is_empty():
			continue
		defs.append(spec)
	return defs


func _load_tree_textures() -> Array[Texture2D]:
	return _load_texture_list(TREE_TEXTURE_PATHS, TextureGen.get_tree_texture())


func _load_round_tree_textures() -> Array[Texture2D]:
	return _load_texture_list(ROUND_TREE_TEXTURE_PATHS, TextureGen.get_tree_texture())


func _load_conifer_tree_textures() -> Array[Texture2D]:
	return _load_texture_list(CONIFER_TREE_TEXTURE_PATHS, TextureGen.get_tree_texture())


func _load_grass_textures() -> Array[Texture2D]:
	return _load_texture_list(GRASS_TEXTURE_PATHS, TextureGen.get_fiber_texture())


func _load_mushroom_textures() -> Array[Texture2D]:
	return _load_texture_list(MUSHROOM_TEXTURE_PATHS, null)


func _load_rock_textures() -> Array[Texture2D]:
	return _load_texture_list(ROCK_TEXTURE_PATHS, TextureGen.get_stone_texture())


func _load_twig_textures() -> Array[Texture2D]:
	return _load_texture_list(TWIG_TEXTURE_PATHS, null)


func _load_leaf_pile_textures() -> Array[Texture2D]:
	return _load_texture_list(LEAF_PILE_TEXTURE_PATHS, null)


func _load_tall_grass_textures() -> Array[Texture2D]:
	return _load_texture_list(TALL_GRASS_TEXTURE_PATHS, TextureGen.get_fiber_texture())


func _load_flower_textures() -> Array[Texture2D]:
	return _load_texture_list(FLOWER_TEXTURE_PATHS, TextureGen.get_herb_texture())


func _load_texture_list(paths: Array[String], fallback: Texture2D) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var tex = load(path) as Texture2D
		if tex != null:
			textures.append(tex)
	if textures.is_empty() and fallback != null:
		textures.append(fallback)
	return textures


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
