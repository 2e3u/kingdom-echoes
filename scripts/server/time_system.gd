extends Node
class_name TimeSystem

## 时间系统 — 管理服务端时间、tick 计数、时间同步
## 客户端通过 RPC 获取服务端时间来同步本地时间

var server_start_time: float = 0.0
var current_time: float = 0.0
var tick: int = 0

func _ready() -> void:
	server_start_time = Time.get_ticks_msec() / 1000.0
	print("[TimeSystem] 服务端时间系统已初始化, 启动时间: %f" % server_start_time)

func get_server_time_seconds() -> float:
	# TODO: 返回精确的服务端运行时间（秒）
	current_time = Time.get_ticks_msec() / 1000.0 - server_start_time
	return current_time

func get_server_time_ms() -> int:
	# TODO: 返回精确的服务端运行时间（毫秒）
	return Time.get_ticks_msec() - int(server_start_time * 1000.0)

func get_tick() -> int:
	# TODO: 返回当前 tick 数
	return tick

func advance_tick() -> void:
	# TODO: 推进 tick
	tick += 1

func get_time_sync_data() -> Dictionary:
	# TODO: 返回用于客户端时间同步的数据
	return {
		"server_time": get_server_time_seconds(),
		"tick": tick,
	}

func client_adjust_latency(server_time: float, client_send_time: float) -> float:
	# TODO: 客户端调用，根据往返延迟估算偏移
	# RTT = (当前时间 - client_send_time)
	# offset = server_time - (client_send_time + RTT/2)
	return server_time
