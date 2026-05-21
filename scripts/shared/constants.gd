extends Node
class_name SharedConstants

## 共享常量定义 — 客户端和服务端使用同一套值

# ---------- 网络 ----------
const SERVER_DEFAULT_PORT: int = 12345        # ENet UDP 端口
const SERVER_HTTP_PORT: int = 12346           # HTTP 健康检查端口
const MAX_PLAYERS: int = 64                    # 最大玩家数
const CLIENT_TIMEOUT_SEC: float = 15.0         # 客户端超时（秒）
const RECONNECT_ATTEMPTS: int = 3              # 重连次数
const RECONNECT_DELAY_SEC: float = 2.0         # 重连间隔

# ---------- 时间 ----------
const TICK_RATE: int = 30                      # 逻辑帧率（tick/s）
const TICK_DELTA: float = 1.0 / TICK_RATE      # 每 tick 秒数
const PHYSICS_TICK_RATE: int = 60              # 物理帧率
const SYNC_INTERVAL_MS: int = 50               # 状态同步间隔（ms）

# ---------- 世界 ----------
const WORLD_WIDTH: float = 1920.0              # 世界宽度
const WORLD_HEIGHT: float = 1080.0             # 世界高度
const PLAYER_SPEED: float = 400.0              # 玩家移动速度（像素/秒）
const PLAYER_RADIUS: float = 16.0              # 玩家碰撞半径

# ---------- 持久化 ----------
const SAVE_DIR: String = "user://saves/"
const PLAYER_DATA_FILE: String = "user://player_data.json"
const MAX_SAVE_SLOTS: int = 5
const WORLD_VERSION: int = 1

# ---------- HTTP 健康检查 ----------
const HEALTH_CHECK_PATH: String = "/health"
const HEALTH_CHECK_INTERVAL_SEC: float = 5.0

# ---------- 背包 ----------
const INVENTORY_INITIAL_SLOTS: int = 20
const INVENTORY_MAX_SLOTS: int = 60
const HOTBAR_SLOTS: int = 8

# ---------- 建造 ----------
const BUILD_RANGE: int = 8            # 建造距离（格）
const TERRITORY_INITIAL_SIZE: int = 32  # 初始领地（格）
const TERRITORY_EXPAND_COST_PER_TILE: int = 10  # 每格扩展金币
const TILE_SIZE: int = 32             # 等距 TileMap 单元（像素）

# ---------- 工具耐久 ----------
const TOOL_DURABILITY_WOOD: int = 50
const TOOL_DURABILITY_STONE: int = 100
const TOOL_DURABILITY_COPPER: int = 150
const TOOL_DURABILITY_IRON: int = 250
const TOOL_DURABILITY_MITHRIL: int = 400

# ---------- 世界生成 ----------
const WORLD_SEED: int = 0             # 0=随机种子
const WORLD_CHUNK_SIZE: int = 32      # 区块大小（格）
const BIOME_COUNT: int = 9
const RESOURCE_DENSITY: float = 0.05  # 资源节点密度

# ---------- 等级 ----------
const MAX_LEVEL: int = 100
const XP_CURVE_BASE: int = 100       # 1级→2级所需经验
const XP_CURVE_GROWTH: float = 1.15  # 每级经验增长系数

# ---------- 属性 ----------
const ATTR_POINTS_PER_LEVEL: int = 5     # 每级自由属性点
const ATTR_BASE_VALUE: int = 5            # 初始属性值
const ATTR_MAX_PER_ATTR: int = 100        # 单项属性上限

# ---------- 技能槽 ----------
const SKILL_SLOT_COUNT: int = 5           # 总技能槽（含终极）
const SKILL_GENERAL_SLOTS: int = 2        # 通用技能槽数量

# ---------- 职业 ----------
const CLASS_COUNT: int = 4


func _ready():
	pass
