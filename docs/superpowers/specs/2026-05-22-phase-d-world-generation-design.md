# Phase D: 世界生成增强

## 目标

将 3 种草皮正弦波 + 6 种资源随机散布的简陋世界，升级为 8 种群落噪声分布 + 群落绑定资源 + 装饰物的丰富世界。瓦片由 ComfyUI SDXL 生成无缝像素贴图。

## 架构

```
scripts/game/
├── world_generator.gd     # 新：群落噪声 + 资源分布 + 装饰散布
├── texture_gen.gd         # 不改（瓦片/装饰由 ComfyUI 生成）
└── kingdom_echoes.gd      # 改：_build_ground + _spawn_resources 委托 WorldGenerator
```

### 依赖关系

```
kingdom_echoes.gd
    └── WorldGenerator
            ├── TextureGen (仅 make_tileset，瓦片来自外部 PNG)
            ├── rng (主控传入，保持种子确定性)
            └── 产出: TileMap + resource_sprites + resource_data + decoration Sprites
```

WorldGenerator 是纯逻辑模块，extends RefCounted，由主控注入依赖后调用 `generate()`。

## 瓦片生成管线

### pixel-art-generator 配置

修改 `config.yaml`：

```
terrain:
  output_size: 48          # 32 → 48
  output_variants: 9
  generations_per_biome: 3
  seamless: true

generation:
  width: 768               # 512 → 768 (48*4*4 覆盖更多随机)
  height: 768
```

### 8 群落配置（沿用现有 config.yaml）

| id | 名称 | style prompt |
|---|---|---|
| grass | 草地 | grass ground, green, small flowers |
| dirt | 泥土 | dirt ground, brown earth, small pebbles |
| sand | 沙漠 | sand ground, golden warm, sparse dry grass |
| snow | 雪地 | snow ground, white blue-tinted, clean |
| swamp | 沼泽 | swamp ground, dark green murky, vines moss |
| forest_floor | 森林地面 | forest floor, fallen leaves, brown earth |
| stone_path | 石路 | stone path, gray cobblestone arranged |
| water | 水域 | water surface, blue ripples, reflective |

### 执行

```
cd pixel-art-generator
python pipeline.py --tiles
```

产出：`kingdom-echoes/assets/sprites/tile_{biome_id}_{variant}.png`（最多 72 张）

## 世界生成系统

### 世界尺寸

- WORLD_TILES_X: 80 → 100
- WORLD_TILES_Y: 60 → 75
- TILE_SIZE: 32 → 48
- 物理尺寸：4800 × 3600 像素

### WorldGenerator 接口

```
extends RefCounted
class_name WorldGenerator

func setup(rng: RandomNumberGenerator, tile_size: int, world_w: int, world_h: int) -> void
func set_biome_configs(configs: Array[Dictionary]) -> void
func set_resource_defs(defs: Array[Dictionary]) -> void
func set_decoration_defs(defs: Array[Dictionary]) -> void

func generate() -> Dictionary:
    # 返回 {biome_grid, tilemap, resource_sprites, resource_data, decorations}
    # 调用方拿到数据后 add_child 到场景树

func get_biome_at(grid_x: int, grid_y: int) -> String
```

### 群落分布算法

每个瓦片 (x, y) 的群落由两层决定：

1. **Simplex 噪声层**（频率可配，默认 `scale=0.015`）
   - 决定局部地形变化：低值→沼泽/水域，中值→草地/泥土，高值→森林/石路

2. **纬度偏置层**
   - y 归一化到 [-1, 1]：`lat = (y / WORLD_TILES_Y) * 2 - 1`
   - 高纬度 (lat < -0.3)：+雪地、+石路 倾向
   - 中纬度 (-0.3 ≤ lat ≤ 0.3)：均匀分布
   - 低纬度 (lat > 0.3)：+沙漠、+沼泽、+水域 倾向

3. **混合公式**：
   ```
   biome_score = noise_2d(x, y) * 0.6 + latitude_bias(y) * 0.4
   ```
   将 biome_score 映射到 0-1，按阈值分段对应 8 种群落。

4. **过渡带**：群落边界 ±2 格内，从相邻群落中随机选择（50% 概率用邻居群落），避免硬边。

### 水域处理

- 水域瓦片不可行走：在 `_process` 移动逻辑中，检测玩家目标位置的群落类型，若为 water 则阻止移动
- 预留 `harvest_type: FISH` 扩展点

## 资源按群落分布

### 配置结构

```gdscript
var resource_defs = [
    {"id": "tree", "item": "wood", "qty": 3, "count": 150, "size": 22,
     "harvest_type": SharedEnums.HarvestType.WOOD, "tool_tier": SharedEnums.ToolTier.NONE,
     "biomes": ["forest_floor", "grass"], "density": 0.08},  # 每格 8% 概率
    ...
]
```

每个资源定义新增 `biomes` 和 `density` 字段。生成时按群落过滤，在对应群落区域内以 density 概率放置。

**注意**：铜矿和铁矿需要工具等级门控（Phase A 已实现），放置时保持 tool_tier 不变。

### 资源分布表

| 资源 | 群落 | 密度/千格 | 数量 (~7500格) |
|---|---|---|---|
| tree (木头) | forest_floor, grass | 40 | ~120 |
| copper_ore (铜矿) | stone_path, sand | 10 | ~15 |
| iron_ore (铁矿) | stone_path, dirt | 15 | ~20 |
| stone_node (石头) | dirt, stone_path | 20 | ~30 |
| herb_red (药草) | grass, swamp, forest_floor | 25 | ~40 |
| fiber_plant (纤维) | grass, swamp | 20 | ~25 |

水域和雪地无资源。

## 装饰物系统

### ComfyUI 生成

新增 `config.yaml` 的 `decorations` 段，和 terrain 类似但生成独立小精灵（16-24px）。

生成命令（扩展 pipeline.py 支持 `--decorations` 参数）。

### 装饰类型

| 类别 | 装饰物 | 尺寸 | 群落 |
|---|---|---|---|
| 花草 | 小花 (flower) | 12px | grass, forest_floor |
| 花草 | 草簇 (grass_tuft) | 16px | grass, dirt, swamp |
| 花草 | 蘑菇 (mushroom) | 12px | forest_floor, swamp |
| 石子 | 小石子 (pebble) | 8px | dirt, stone_path, sand |
| 石子 | 小岩块 (rock_small) | 16px | stone_path, dirt |
| 灌木 | 矮灌木 (bush_small) | 20px | grass, forest_floor |
| 灌木 | 浆果丛 (berry_bush) | 20px | forest_floor, swamp |
| 枯枝 | 落叶堆 (leaf_pile) | 16px | forest_floor |
| 枯枝 | 枯枝 (twig) | 12px | forest_floor, grass, swamp |

### 散布规则

- 每个群落独立生成：对群落内每格，以 `decoration_density`（默认 3%）概率放置
- 同一格最多 1 个装饰物
- 装饰物放在地面之上，z_index = 2-3（低于玩家 5、高于资源 1-2）
- 装饰物的确切位置在瓦片中心 ± 随机偏移（±TILE_SIZE/3）
- 纯视觉，不可交互，不阻挡移动

### 如果 ComfyUI 管线就绪前想先看到效果

可在 `texture_gen.gd` 添加 `get_flower_texture()` 等简单静态函数作为占位。管线就绪后切换为 PNG 导入。

## 非功能要求

- 编译零错误
- 游戏现有行为不变（移动、采集、制造、建造）
- 世界种子确定性（同 seed 同世界）
- 水域不可行走（移动限制 + 视觉反馈：踩水边缘停止）
- 管线生成的瓦片需验证无缝拼接（在 Godot TileMap 中无可见接缝）

## 不在此 Phase

- 钓鱼系统（水域预留接口）
- 海拔/高度系统
- 矿脉/资源富集区
- 动态天气
- 洞穴/地下层
