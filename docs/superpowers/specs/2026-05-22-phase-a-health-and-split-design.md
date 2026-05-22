# Phase A: 健康度修复 + 代码拆分

## 目标

修复 3 个已知 bug，将 1553 行 `kingdom_echoes.gd` 按职责拆分为 5 个模块，建立可维护的架构基础。

## 架构

```
scripts/game/
├── kingdom_echoes.gd      # 主控制器 ~300行
├── texture_gen.gd         # 纹理生成 ~450行
├── hud_controller.gd      # HUD系统 ~400行
├── harvest_controller.gd  # 采集系统 ~200行
└── build_controller.gd    # 建造系统 ~250行
```

### 依赖关系

```
kingdom_echoes.gd (主控)
    ├── TextureGen          (纯静态，无依赖)
    ├── HUDController       (读 player/item_manager/time_system 状态)
    ├── HarvestController   (读 player/resource_sprites，写 item_manager)
    └── BuildController     (读 player/item_manager，操作场景树)
```

所有 controller 由主控实例化并注入依赖，彼此之间无直接引用。

## 各模块接口

### TextureGen（纯静态纹理工厂）

```
static _tex_cache: Dictionary
static get_grass_tile(variant: int) -> ImageTexture
static get_tree_texture() -> ImageTexture
static get_stump_texture() -> ImageTexture
static get_stone_texture() -> ImageTexture
static get_ore_texture(base: Color, spec: Color) -> ImageTexture
static get_herb_texture() -> ImageTexture
static get_fiber_texture() -> ImageTexture
static get_player_texture() -> ImageTexture
static get_block_texture(item_id: String) -> ImageTexture
static get_item_icon(item_id: String) -> ImageTexture
# 像素辅助: _px, _px_rect, _px_circle, _px_noise
```

无 `_process`，无信号，不持有游戏状态。

### HUDController

```
依赖: player (CharacterBody2D), item_manager (ItemManager), time_system (TimeSystem)
持有: 所有 HUD Control 节点引用（hotbar/inventory/craft/build panels/labels/icons）

接口:
  create(parent: CanvasLayer) -> void
  update() -> void                    # 每帧：位置/时间/光效/资源统计
  refresh_slots() -> void             # 脏标记触发：图标+数量更新
  toggle_inventory() -> void
  toggle_craft() -> void
  close_all() -> void
  set_hint(text: String) -> void
  show_harvest_bar(visible: bool) -> void
  update_harvest_bar(progress: float) -> void
  mark_dirty() -> void                # 外部设置脏标记
```

优化：`update()` 只刷新动态文本（时间、位置、资源统计），图标纹理在 `refresh_slots()` 中按脏标记更新。

### HarvestController

```
依赖: player, resource_sprites (Dictionary), resource_data (Dictionary), item_manager

信号:
  harvest_completed(item_id: String, qty: int)

接口:
  try_harvest() -> bool               # 开始采集，返回是否成功
  update(delta: float) -> void        # 进度条推进
  cancel() -> void
  is_harvesting() -> bool
  get_progress() -> float
```

### BuildController

```
依赖: player, item_manager, scene_root (Node)

接口:
  toggle() -> void
  is_active() -> bool
  update_preview() -> void            # 幽灵方块位置+纹理更新
  try_place() -> void
  try_remove() -> void
  select_block(item_id: String) -> void
  cycle_selection(dir: int) -> void
  get_available_blocks() -> Array
```

## Bug 修复

### B1: 幽灵预览每帧重建纹理
- 文件：`build_controller.gd`
- 问题：`_update_ghost_preview` 每帧调用 `ImageTexture.create_from_image()`，即使纹理已缓存
- 修复：直接用 `TextureGen.get_block_texture(selected_block_item)` 赋值，不再重复创建

### B2: HUD 每帧刷新图标
- 文件：`hud_controller.gd`
- 问题：`_update_hud` 每帧对 29 个格子调用 `get_item_icon()`，大部分帧无需更新
- 修复：新增 `inventory_dirty` 标志，只在背包变化、切换选中、打开/关闭面板时调用 `refresh_slots()`

### B3: consume_durability 工具损坏覆盖数据
- 文件：`item_manager.gd` 第 138-141 行
- 问题：`slot["broken"] = true` 会覆盖掉整个 slot 字典
- 修复：改为 `slot["broken"] = true`（仅设置字段，不覆盖已有 item_id/quantity）

## 主控职责精简

`kingdom_echoes.gd` 只保留：
- `_ready()` — 场景搭建、子系统初始化、controller 创建
- `_process(delta)` — 输入读取、控制器分发
- `_input(event)` — 按键事件分发
- 世界生成 + 资源生成
- 浮字辅助函数
- 子系统桥接（如采集完成后通知制造面板刷新）

## 非功能要求

- 拆分后编译零错误
- 拆分后游戏行为与拆分前完全一致
- 所有 controller 用 `class_name` 注册，类型安全引用
