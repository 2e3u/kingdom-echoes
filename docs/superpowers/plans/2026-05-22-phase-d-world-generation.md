# Phase D: 世界生成增强 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将简陋正弦波世界升级为 8 种群落 Simplex 噪声分布 + 群落绑定资源 + 装饰物 + 水域不可行走的丰富世界，瓦片由 ComfyUI SDXL 生成。

**Architecture:** 新增 WorldGenerator 模块（RefCounted 纯逻辑），负责噪声群落分布、TileSet 构建、资源放置、装饰散布。主控注入 rng/尺寸后调用 generate()，拿到 TileMap + 资源 + 装饰 add_child 到场景树。

**Tech Stack:** Godot 4.6 GDScript (FastNoiseLite), Python 3 + PIL (瓦片后处理), ComfyUI SDXL (瓦片/装饰生成)

---

## File Map

```
pixel-art-generator/
├── config.yaml                   # 改：output_size 48, 768×768, 新增 decorations
├── src/tile_processor.py         # 改：新增 atlas_combine()
└── src/decoration_prompt.py      # 新：装饰物 prompt 构建

scripts/game/
├── world_generator.gd            # 新：群落噪声 + TileSet + 资源 + 装饰
├── texture_gen.gd                # 微改：新增占位装饰纹理（可选）
└── kingdom_echoes.gd             # 改：委托 WorldGenerator，水域阻挡，常量更新

assets/sprites/
└── tile_{biome}_{nn}.png         # ComfyUI 产出 → 合并为 atlas_{biome}.png
```

---

### Task 1: 更新 pixel-art-generator 配置 + 生成瓦片

**Files:**
- Modify: `pixel-art-generator/config.yaml`
- Modify: `pixel-art-generator/src/tile_processor.py`

**Purpose:** 将瓦片输出尺寸改为 48px，生成尺寸改为 768×768，新增 atlas 合并函数。

- [ ] **Step 1: 更新 config.yaml**

Read current config, modify terrain and generation sections:

```yaml
generation:
  width: 768
  height: 768

terrain:
  output_size: 48
  output_variants: 9
  generations_per_biome: 3
  seamless: true
```

Run: `cd /Users/wxb/cc/_active/pixel-art-generator && python3 -c "
import yaml
with open('config.yaml') as f:
    c = yaml.safe_load(f)
c['generation']['width'] = 768
c['generation']['height'] = 768
c['terrain']['output_size'] = 48
with open('config.yaml', 'w') as f:
    yaml.dump(c, f, default_flow_style=False, allow_unicode=True)
print('Done')
"`

- [ ] **Step 2: 新增 atlas_combine() 到 tile_processor.py**

Append to `pixel-art-generator/src/tile_processor.py`:

```python
def atlas_combine(tiles: list[Image.Image], tile_size: int = 48) -> Image.Image:
    """将瓦片列表合并为水平条带 atlas，tile_size × (count * tile_size)"""
    if not tiles:
        return Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
    count = len(tiles)
    atlas = Image.new("RGBA", (tile_size * count, tile_size), (0, 0, 0, 0))
    for i, tile in enumerate(tiles):
        atlas.paste(tile, (i * tile_size, 0))
    return atlas
```

- [ ] **Step 3: 确认 ComfyUI 服务运行**

```bash
curl -s http://127.0.0.1:8188/system_stats | python3 -c "import sys,json; print('ComfyUI OK' if 'system' in json.load(sys.stdin) else 'NOT RUNNING')"
```

Expected: `ComfyUI OK`. If NOT RUNNING, report BLOCKED.

- [ ] **Step 4: 生成瓦片（先用一个群落测试）**

```bash
cd /Users/wxb/cc/_active/pixel-art-generator
python3 pipeline.py --tiles --biome grass --dry-run
```

Expected: 生成 `tile_grass_01.png` 到 `../kingdom-echoes/assets/sprites/`

- [ ] **Step 5: Commit**

```bash
cd /Users/wxb/cc/_active/pixel-art-generator
git add config.yaml src/tile_processor.py
git commit -m "feat: 瓦片管线 48px — config更新 + atlas合并函数"
```

---

### Task 2: 生成全量地形瓦片 + 构建 atlas

**Files:**
- Create: `kingdom-echoes/assets/sprites/atlas_{biome}.png` (8 files, via script)

**Purpose:** 生成 8 群落全量瓦片，按群落合并为 atlas 条带。

- [ ] **Step 1: 生成全部 8 群落瓦片**

```bash
cd /Users/wxb/cc/_active/pixel-art-generator
python3 pipeline.py --tiles
```

Wait time: ~2-5 min per biome on SDXL (total ~15-40 min). This step is fire-and-forget.

- [ ] **Step 2: 合并每个群落为 atlas**

Run Python script to combine:

```bash
cd /Users/wxb/cc/_active/pixel-art-generator
python3 << 'PYEOF'
from pathlib import Path
from PIL import Image
from src.tile_processor import atlas_combine

output_dir = Path("../kingdom-echoes/assets/sprites")
biomes = ["grass", "dirt", "sand", "snow", "swamp", "forest_floor", "stone_path", "water"]

for biome in biomes:
    tiles = []
    for i in range(1, 10):
        p = output_dir / f"tile_{biome}_{i:02d}.png"
        if p.exists():
            tiles.append(Image.open(p))
    if tiles:
        atlas = atlas_combine(tiles, 48)
        atlas.save(output_dir / f"atlas_{biome}.png")
        print(f"{biome}: {len(tiles)} tiles -> atlas_{biome}.png")
    else:
        print(f"{biome}: NO TILES FOUND — skipping")
PYEOF
```

- [ ] **Step 3: Commit atlas PNGs**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add assets/sprites/atlas_*.png assets/sprites/tile_*.png
git commit -m "feat: 8群落瓦片atlas — ComfyUI SDXL 生成 48px 无缝拼接"
```

---

### Task 3: Create WorldGenerator — 噪声群落分布 + TileSet 构建

**Files:**
- Create: `scripts/game/world_generator.gd`

**Purpose:** 核心模块。Simplex 噪声 + 纬度偏置 → 群落格子 → TileSet + TileMap 产出。

- [ ] **Step 1: Write world_generator.gd**

```gdscript
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
			lat_bias = lerpf(-0.3, -1.0, (lat + 0.3) / -0.7)  # 高纬：雪地+石路
		elif lat > 0.3:
			lat_bias = lerpf(0.3, 1.0, (lat - 0.3) / 0.7)      # 低纬：沙漠+水+沼泽
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

	# 边界过渡带：±2 格内 50% 用邻居群落
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
		var img = Image.load_from_file(atlas_path)
		var tex = ImageTexture.create_from_image(img)
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
				sprite.z_index = 1 if d["id"] != "tree" else 2
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
	_generate_biome_grid()
	var tilemap = _build_tilemap()
	parent_node.add_child(tilemap)
	_spawn_resources(parent_node)
	_spawn_decorations(parent_node)
```

- [ ] **Step 2: 编译验证**

```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"
```
Expected: Only export preset errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add scripts/game/world_generator.gd
git commit -m "feat: WorldGenerator — Simplex噪声+纬度偏置群落分布 + TileSet构建"
```

---

### Task 4: 集成 WorldGenerator 到 kingdom_echoes.gd

**Files:**
- Modify: `scripts/game/kingdom_echoes.gd`

**Purpose:** 替换 `_build_ground()` 和 `_spawn_resources()`，更新世界常量，接入 WorldGenerator。

- [ ] **Step 1: 更新世界常量**

```gdscript
const WORLD_TILES_X: int = 100
const WORLD_TILES_Y: int = 75
const TILE_SIZE: int = 48
```

Edit `scripts/game/kingdom_echoes.gd` lines 7-9.

- [ ] **Step 2: 替换 _build_ground + _spawn_resources**

Remove `_build_ground()` (lines 71-79) and `_spawn_resources()` (lines 84-119). Replace with WorldGenerator wiring in `_ready()`:

```gdscript
# 配置群落（对应 atlas PNG 路径）
var biome_configs: Array[Dictionary] = []
for biome_id in WorldGenerator.BIOME_IDS:
    biome_configs.append({
        "id": biome_id,
        "atlas_path": "res://assets/sprites/atlas_%s.png" % biome_id,
        "variant_count": 9,
    })

# 配置资源（按群落分布 + 密度）
var resource_defs: Array[Dictionary] = [
    {"id": "tree", "item": "wood", "qty": 3, "name": "树",
     "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE,
     "biomes": ["forest_floor", "grass"], "density": 0.016,
     "texture": TextureGen.get_tree_texture()},
    {"id": "copper_ore", "item": "copper_ore", "qty": 2, "name": "铜矿",
     "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.WOOD,
     "biomes": ["stone_path", "sand"], "density": 0.004,
     "texture": TextureGen.get_ore_texture(Color(0.72, 0.42, 0.18), Color(0.95, 0.65, 0.2))},
    {"id": "iron_ore", "item": "iron_ore", "qty": 2, "name": "铁矿",
     "harvest_type": SharedEnums.HarvestType.ORE, "tool_tier": SharedEnums.ToolTier.STONE,
     "biomes": ["stone_path", "dirt"], "density": 0.005,
     "texture": TextureGen.get_ore_texture(Color(0.45, 0.42, 0.48), Color(0.65, 0.62, 0.7))},
    {"id": "stone_node", "item": "stone", "qty": 3, "name": "石头",
     "harvest_type": -1, "tool_tier": SharedEnums.ToolTier.NONE,
     "biomes": ["dirt", "stone_path"], "density": 0.008,
     "texture": TextureGen.get_stone_texture()},
    {"id": "herb_red", "item": "herb_red", "qty": 2, "name": "药草",
     "harvest_type": SharedEnums.HarvestType.HERB, "tool_tier": SharedEnums.ToolTier.NONE,
     "biomes": ["grass", "swamp", "forest_floor"], "density": 0.010,
     "texture": TextureGen.get_herb_texture()},
    {"id": "fiber_plant", "item": "fiber", "qty": 2, "name": "纤维植物",
     "harvest_type": SharedEnums.HarvestType.FIBER, "tool_tier": SharedEnums.ToolTier.NONE,
     "biomes": ["grass", "swamp"], "density": 0.008,
     "texture": TextureGen.get_fiber_texture()},
]

# 装饰物（先用 TextureGen 占位，后续切换 ComfyUI）
var decoration_defs: Array[Dictionary] = []

# 创建 WorldGenerator
var wg = WorldGenerator.new()
wg.setup(rng, TILE_SIZE, WORLD_TILES_X, WORLD_TILES_Y)
wg.set_biome_configs(biome_configs)
wg.set_resource_defs(resource_defs)
wg.set_decoration_defs(decoration_defs)

# 生成世界
var res_layer = Node2D.new()
res_layer.name = "Resources"
add_child(res_layer)
wg.generate(self)  # 内部 add_child TileMap + 资源 + 装饰

# 从 WorldGenerator 获取资源引用
resource_sprites = wg.resource_sprites
resource_data = wg.resource_data
```

- [ ] **Step 3: 添加水域阻挡逻辑**

In `_process`, after movement calculation, add water check:

```gdscript
# 移动（加水域阻挡）
var dir = Vector2.ZERO
if Input.is_action_pressed("move_up"): dir.y -= 1
if Input.is_action_pressed("move_down"): dir.y += 1
if Input.is_action_pressed("move_left"): dir.x -= 1
if Input.is_action_pressed("move_right"): dir.x += 1
if dir.length() > 0:
    dir = dir.normalized()
var next_pos = player.position + dir * move_speed * delta
next_pos.x = clamp(next_pos.x, 64, (WORLD_TILES_X - 2) * TILE_SIZE)
next_pos.y = clamp(next_pos.y, 64, (WORLD_TILES_Y - 2) * TILE_SIZE)

# 水域阻挡：检测目标位置群落
var target_gx = int(next_pos.x / TILE_SIZE)
var target_gy = int(next_pos.y / TILE_SIZE)
# WorldGenerator 需要作为成员变量保存引用
if world_generator.get_biome_at(target_gx, target_gy) != "water":
    player.position = next_pos
```

Save `world_generator` as member variable: `var world_generator: WorldGenerator = null`.

- [ ] **Step 4: 编译验证**

```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"
```
Expected: Only export preset errors. Fix any parse errors if present.

- [ ] **Step 5: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add scripts/game/kingdom_echoes.gd
git commit -m "feat: 接入 WorldGenerator — 8群落+资源分布+水域阻挡"
```

---

### Task 5: 装饰物系统

**Files:**
- Modify: `pixel-art-generator/src/decoration_prompt.py` (new)
- Modify: `pixel-art-generator/pipeline.py`
- Modify: `scripts/game/kingdom_echoes.gd`

**Purpose:** ComfyUI 生成装饰物小精灵，Godot 端散布到对应群落。

- [ ] **Step 1: 创建 decoration_prompt.py**

```python
# pixel-art-generator/src/decoration_prompt.py

DECORATION_PROMPT_TEMPLATE = (
    "pixel art {style}, isolated sprite, "
    "flat shading, hard edges, limited palette, no anti-aliasing, "
    "transparent background, top-down view, small object"
)

DECORATION_DEFS = [
    {"id": "flower", "style": "small flower, white petals yellow center", "size": 12},
    {"id": "grass_tuft", "style": "tuft of grass, green blades", "size": 16},
    {"id": "mushroom", "style": "small red mushroom with white spots", "size": 12},
    {"id": "pebble", "style": "small gray pebble stone", "size": 8},
    {"id": "rock_small", "style": "small rough rock, gray", "size": 16},
    {"id": "bush_small", "style": "small green bush shrub", "size": 20},
    {"id": "berry_bush", "style": "small bush with red berries", "size": 20},
    {"id": "leaf_pile", "style": "pile of autumn fallen leaves, orange brown", "size": 16},
    {"id": "twig", "style": "small dry twig branch, brown", "size": 12},
]

DECORATION_BIOME_MAP = {
    "grass": ["flower", "grass_tuft", "bush_small", "twig"],
    "dirt": ["grass_tuft", "pebble", "rock_small"],
    "sand": ["pebble"],
    "snow": [],
    "swamp": ["grass_tuft", "mushroom", "berry_bush", "twig"],
    "forest_floor": ["flower", "mushroom", "bush_small", "berry_bush", "leaf_pile", "twig"],
    "stone_path": ["pebble", "rock_small"],
    "water": [],
}

def build_decoration_prompt(dec_def: dict) -> str:
    style = dec_def.get("style", "small object")
    return DECORATION_PROMPT_TEMPLATE.format(style=style)
```

- [ ] **Step 2: 生成装饰物精灵（测试一个）**

```bash
cd /Users/wxb/cc/_active/pixel-art-generator
# 手动构建一个 ComfyUI 工作流生成 flower
python3 << 'PYEOF'
from src.comfyui_client import ComfyUIClient
from src.tile_workflow import build_tile_workflow
from src.decoration_prompt import build_decoration_prompt, DECORATION_DEFS
from PIL import Image
from io import BytesIO
from pathlib import Path
import yaml

with open("config.yaml") as f:
    config = yaml.safe_load(f)

gen_cfg = config["generation"]
client = ComfyUIClient(base_url=config["comfyui"]["base_url"], timeout=300)

for d in DECORATION_DEFS[:1]:  # 只生成 flower 测试
    prompt = build_decoration_prompt(d)
    wf = build_tile_workflow(prompt, gen_cfg["negative_prompt"],
        gen_cfg["checkpoint"], 256, 256, gen_cfg["steps"], gen_cfg["cfg"],
        gen_cfg["sampler"], seed=42)
    images_bytes = client.generate(wf)
    for i, img_bytes in enumerate(images_bytes):
        img = Image.open(BytesIO(img_bytes))
        # Nearest Neighbor 到目标尺寸
        img = img.resize((d["size"], d["size"]), Image.NEAREST)
        img = img.convert("RGBA")
        out = Path(config["godot"]["output_dir"]) / f"deco_{d['id']}.png"
        img.save(out)
        print(f"Saved: {out}")
PYEOF
```

- [ ] **Step 3: 更新 kingdom_echoes.gd 装饰物配置**

Uncomment decoration_defs and populate:

```gdscript
var decoration_defs: Array[Dictionary] = [
    {"id": "flower", "biomes": ["grass", "forest_floor"], "density": 0.02, "z_index": 2,
     "texture": _load_deco_texture("deco_flower.png")},
    {"id": "grass_tuft", "biomes": ["grass", "dirt", "swamp"], "density": 0.03, "z_index": 2,
     "texture": _load_deco_texture("deco_grass_tuft.png")},
    {"id": "mushroom", "biomes": ["forest_floor", "swamp"], "density": 0.01, "z_index": 2,
     "texture": _load_deco_texture("deco_mushroom.png")},
    {"id": "pebble", "biomes": ["dirt", "stone_path", "sand"], "density": 0.04, "z_index": 1,
     "texture": _load_deco_texture("deco_pebble.png")},
    {"id": "rock_small", "biomes": ["stone_path", "dirt"], "density": 0.015, "z_index": 1,
     "texture": _load_deco_texture("deco_rock_small.png")},
    {"id": "bush_small", "biomes": ["grass", "forest_floor"], "density": 0.015, "z_index": 3,
     "texture": _load_deco_texture("deco_bush_small.png")},
    {"id": "berry_bush", "biomes": ["forest_floor", "swamp"], "density": 0.012, "z_index": 3,
     "texture": _load_deco_texture("deco_berry_bush.png")},
    {"id": "leaf_pile", "biomes": ["forest_floor"], "density": 0.025, "z_index": 1,
     "texture": _load_deco_texture("deco_leaf_pile.png")},
    {"id": "twig", "biomes": ["forest_floor", "grass", "swamp"], "density": 0.025, "z_index": 1,
     "texture": _load_deco_texture("deco_twig.png")},
]
```

Helper function:
```gdscript
func _load_deco_texture(path: String) -> ImageTexture:
    var full = "res://assets/sprites/%s" % path
    if ResourceLoader.exists(full):
        return load(full)
    return null  # 缺失纹理时跳过该装饰
```

- [ ] **Step 4: 编译验证**

```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"
```
Expected: Only export preset errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add -A
git commit -m "feat: 装饰物系统 — ComfyUI精灵 + 群落散布"
```

---

### Task 6: 最终验证 + 启动测试

**Files:**
- Verify: all `.gd` files compile
- Test: launch game, verify behavior

- [ ] **Step 1: 最终编译验证**

```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 /Users/wxb/cc/_active/kingdom-echoes/project.godot | grep -iE "error|parse"
```
Expected: Zero parse errors.

- [ ] **Step 2: 启动游戏编辑器手动验证**

```bash
/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --editor /Users/wxb/cc/_active/kingdom-echoes/project.godot &
```

Manual test checklist:
- [ ] 世界地图正确显示 8 种群落（非 3 种草皮）
- [ ] 瓦片无缝拼接（无明显接缝）
- [ ] 资源出现在对应群落（树在森林/草地，铜矿在石路等）
- [ ] WASD 移动正常
- [ ] 水域不可行走（踩水边缘停止）
- [ ] J 采集正常
- [ ] B 背包正常
- [ ] C 制造正常
- [ ] V 建造正常
- [ ] 装饰物可见（花草、石子等）

- [ ] **Step 3: Commit**

```bash
cd /Users/wxb/cc/_active/kingdom-echoes
git add -A
git commit -m "chore: Phase D 最终验证通过"
```
