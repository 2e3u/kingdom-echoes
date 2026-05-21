extends Node
class_name TimeSystem

## 游戏时间系统 — 昼夜循环、时间相位、时间流速
## 1 游戏日 = 24 游戏小时，默认 1 游戏小时 = 60 真实秒（即 1 游戏日 = 24 分钟）

const GAME_HOURS_PER_DAY: int = 24
const DEFAULT_SECONDS_PER_GAME_HOUR: float = 60.0  # 可配置

enum TimePhase {
	DAWN,       # 黎明 4-7
	DAY,        # 白天 7-17
	DUSK,       # 黄昏 17-20
	NIGHT,      # 夜晚 20-4
}

var server_start_time: float = 0.0
var game_time_seconds: float = 0.0       # 游戏内累计时间（游戏秒）
var seconds_per_game_hour: float = DEFAULT_SECONDS_PER_GAME_HOUR
var tick: int = 0
var current_phase: int = TimePhase.DAY
var day_number: int = 1                  # 第几天

signal phase_changed(old_phase: int, new_phase: int)
signal day_passed(day: int)
signal game_hour_changed(hour: int)


func _ready() -> void:
	server_start_time = Time.get_ticks_msec() / 1000.0
	# 初始化为游戏内早上 6 点（黎明）
	game_time_seconds = 6.0 * seconds_per_game_hour
	current_phase = _calc_phase()
	print("[TimeSystem] 游戏时间系统已初始化, 第 %d 天, 相位: %d" % [day_number, current_phase])


func _process(delta: float) -> void:
	game_time_seconds += delta
	var new_phase = _calc_phase()
	if new_phase != current_phase:
		var old = current_phase
		current_phase = new_phase
		phase_changed.emit(old, new_phase)
		# 新的一天
		if old == TimePhase.NIGHT and new_phase == TimePhase.DAWN:
			day_number += 1
			day_passed.emit(day_number)


# ---------- 时间查询 ----------

func get_game_hour() -> float:
	return fmod(game_time_seconds / seconds_per_game_hour, GAME_HOURS_PER_DAY)


func get_game_minute() -> int:
	return int(fmod(game_time_seconds / seconds_per_game_hour * 60.0, 60.0))


func get_day_number() -> int:
	return day_number


func get_phase() -> int:
	return current_phase


func get_phase_name() -> String:
	match current_phase:
		TimePhase.DAWN: return "黎明"
		TimePhase.DAY: return "白天"
		TimePhase.DUSK: return "黄昏"
		TimePhase.NIGHT: return "夜晚"
	return "未知"


func get_day_progress() -> float:
	## 返回 0.0-1.0，表示一天中的进度（用于光照计算）
	return fmod(game_time_seconds / seconds_per_game_hour, GAME_HOURS_PER_DAY) / GAME_HOURS_PER_DAY


func get_sun_angle() -> float:
	## 返回太阳角度（弧度），0=日出(东)，PI/2=正午，PI=日落(西)
	return get_day_progress() * PI


func get_light_multiplier() -> float:
	## 返回环境光系数 0.0-1.0，用于渲染和游戏机制
	var hour = get_game_hour()
	if hour >= 6 and hour < 18:
		return 1.0  # 白天全亮
	elif hour >= 5 and hour < 6:
		return lerpf(0.3, 1.0, (hour - 5.0))
	elif hour >= 18 and hour < 19:
		return lerpf(0.3, 1.0, (19.0 - hour))
	elif hour >= 19 and hour < 20:
		return lerpf(0.1, 0.3, (20.0 - hour))
	elif hour >= 4 and hour < 5:
		return lerpf(0.1, 0.3, (hour - 4.0))
	else:
		return 0.1  # 深夜


func is_daytime() -> bool:
	return current_phase == TimePhase.DAY or current_phase == TimePhase.DAWN


func is_nighttime() -> bool:
	return current_phase == TimePhase.NIGHT or current_phase == TimePhase.DUSK


# ---------- 时间速度控制 ----------

func set_time_speed(multiplier: float) -> void:
	seconds_per_game_hour = DEFAULT_SECONDS_PER_GAME_HOUR / multiplier


func advance_game_time(seconds: float) -> void:
	## 跳过游戏时间（用于调试或特殊效果）
	game_time_seconds += seconds


# ---------- 游戏机制挂钩 ----------

func get_crop_growth_multiplier() -> float:
	## 农作物生长速度倍率（白天快，夜晚慢）
	match current_phase:
		TimePhase.DAY: return 1.0
		TimePhase.DAWN, TimePhase.DUSK: return 0.5
		TimePhase.NIGHT: return 0.1
	return 1.0


func get_monster_spawn_multiplier() -> float:
	## 怪物生成倍率（夜晚更多）
	match current_phase:
		TimePhase.NIGHT: return 1.5
		TimePhase.DUSK: return 1.2
		TimePhase.DAY: return 1.0
		TimePhase.DAWN: return 0.8
	return 1.0


# ---------- 内部 ----------

func _calc_phase() -> int:
	var hour = get_game_hour()
	if hour >= 4 and hour < 7:
		return TimePhase.DAWN
	elif hour >= 7 and hour < 17:
		return TimePhase.DAY
	elif hour >= 17 and hour < 20:
		return TimePhase.DUSK
	return TimePhase.NIGHT


# ---------- 兼容旧接口 ----------

func get_server_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0 - server_start_time


func get_server_time_ms() -> int:
	return Time.get_ticks_msec() - int(server_start_time * 1000.0)


func get_tick() -> int:
	return tick


func advance_tick() -> void:
	tick += 1


func get_time_sync_data() -> Dictionary:
	return {
		"server_time": get_server_time_seconds(),
		"tick": tick,
		"game_time": game_time_seconds,
		"day": day_number,
		"phase": current_phase,
		"game_hour": get_game_hour(),
	}
