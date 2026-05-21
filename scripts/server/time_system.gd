extends Node
class_name TimeSystem

## 时间系统 — 服务端时间 + 昼夜循环 + tick 同步

# 基础时间
var server_start_time: float = 0.0
var current_time: float = 0.0
var tick: int = 0

# 昼夜循环
const DAY_LENGTH_SECONDS: float = 600.0  # 游戏一天 = 真实 10 分钟
var game_time_seconds: float = 8.0 * 3600.0  # 从早上 8 点开始
var day_number: int = 1
var current_phase: int = 0  # 0=Dawn 1=Day 2=Dusk 3=Night
var time_speed_multiplier: float = 60.0  # 1真实秒 = 60游戏秒

signal phase_changed(new_phase: int)
signal day_passed(day: int)

func _ready() -> void:
	server_start_time = Time.get_ticks_msec() / 1000.0
	print("[TimeSystem] 时间系统已初始化")

func _process(delta: float) -> void:
	game_time_seconds += delta * time_speed_multiplier
	if game_time_seconds >= 86400.0:  # 24小时
		game_time_seconds -= 86400.0
		day_number += 1
		day_passed.emit(day_number)
	var new_phase = _calc_phase()
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(current_phase)

func _calc_phase() -> int:
	var h = get_game_hour()
	if h >= 4 and h < 7: return 0   # Dawn
	if h >= 7 and h < 17: return 1  # Day
	if h >= 17 and h < 20: return 2 # Dusk
	return 3                          # Night

func get_game_hour() -> float:
	return game_time_seconds / 3600.0

func get_light_multiplier() -> float:
	var h = get_game_hour()
	if h >= 5 and h < 7: return lerpf(0.3, 0.9, (h - 5.0) / 2.0)
	if h >= 7 and h < 16: return 0.9 + sin((h - 7.0) / 9.0 * PI) * 0.1
	if h >= 16 and h < 17: return 1.0
	if h >= 17 and h < 19: return lerpf(1.0, 0.2, (h - 17.0) / 2.0)
	if h >= 19 and h < 20: return 0.2
	if h >= 20 or h < 4: return lerpf(0.05, 0.2, (h if h < 4 else h - 20.0) / 4.0)
	if h >= 4 and h < 5: return lerpf(0.2, 0.3, (h - 4.0))
	return 0.5

func get_server_time_seconds() -> float:
	current_time = Time.get_ticks_msec() / 1000.0 - server_start_time
	return current_time

func get_server_time_ms() -> int:
	return Time.get_ticks_msec() - int(server_start_time * 1000.0)

func get_tick() -> int:
	return tick

func advance_tick() -> void:
	tick += 1

func get_time_sync_data() -> Dictionary:
	return {"server_time": get_server_time_seconds(), "tick": tick}

func client_adjust_latency(server_time: float, _client_send_time: float) -> float:
	return server_time
