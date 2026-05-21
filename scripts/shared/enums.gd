extends Node
class_name SharedEnums

## 共享枚举定义 — 客户端和服务端使用同一套值

# ---------- 游戏状态 ----------
enum GameState {
	LOBBY,           # 等待玩家
	COUNTDOWN,       # 倒计时开始
	PLAYING,         # 游戏中
	PAUSED,          # 暂停
	GAME_OVER,       # 结束
}

# ---------- 玩家状态 ----------
enum PlayerState {
	IDLE,            # 空闲
	MOVING,          # 移动中
	INTERACTING,     # 交互中
	DEAD,            # 死亡
	SPECTATING,      # 观战
}

# ---------- 队伍 ----------
enum Team {
	NONE,
	RED,
	BLUE,
	SPECTATOR,
}

# ---------- 网络消息类型 ----------
enum MessageType {
	# 系统
	PING,            # 心跳
	PONG,            # 心跳回复
	# 认证
	AUTH_REQUEST,    # 登录请求
	AUTH_RESPONSE,   # 登录响应
	# 状态同步
	WORLD_STATE,     # 全量世界状态
	DELTA_STATE,     # 增量状态
	INPUT_STATE,     # 玩家输入
	# 事件
	PLAYER_JOINED,   # 玩家加入
	PLAYER_LEFT,     # 玩家离开
	CHAT_MESSAGE,    # 聊天消息
	GAME_EVENT,      # 游戏事件
}

# ---------- 物品分类 ----------
enum ItemCategory {
	MATERIAL,       # 材料
	TOOL,           # 工具
	WEAPON,         # 武器
	ARMOR,          # 防具
	CONSUMABLE,     # 消耗品
	ACCESSORY,      # 饰品
	BLUEPRINT,      # 蓝图
	SPECIAL,        # 特殊
}

# ---------- 物品稀有度 ----------
enum Rarity {
	COMMON,         # 普通（灰）
	UNCOMMON,       # 稀有（绿）
	RARE,           # 精良（蓝）
	EPIC,           # 史诗（紫）
	LEGENDARY,      # 传说（橙）
}

# ---------- 方块类型 ----------
enum BlockType {
	FLOOR,          # 地板
	WALL,           # 墙壁
	DOOR,           # 门
	FURNITURE,      # 家具
	WORKSTATION,    # 工作站
	DECORATION,     # 装饰
	LOGIC,          # 逻辑装置
	CROP,           # 农作物
}

# ---------- 工具等级 ----------
enum ToolTier {
	NONE,           # 手
	WOOD,           # 木
	STONE,          # 石
	COPPER,         # 铜
	IRON,           # 铁
	MITHRIL,        # 秘银
}

# ---------- 制造工作站 ----------
enum CraftStation {
	HAND,           # 手工
	WORKBENCH,      # 工作台
	FURNACE,        # 熔炉
	ANVIL,          # 铁砧
	ALCHEMY,        # 炼金台
	KITCHEN,        # 厨房
	LOOM,           # 织布机
	ENCHANT,        # 附魔台
}

# ---------- 采集类型 ----------
enum HarvestType {
	NONE,
	WOOD,           # 伐木
	ORE,            # 采矿
	HERB,           # 采药
	FISH,           # 钓鱼
	FIBER,          # 采集纤维
}


func _ready():
	pass
