extends Node
class_name GatheringController

## 客户端采集控制器 — 检测最近资源节点，发送采集请求

var _target_node_id: String = ""
var _harvest_cooldown: float = 0.0
const HARVEST_INTERVAL: float = 0.5

signal harvest_attempted(node_id: String)

func _process(delta: float) -> void:
	if _harvest_cooldown > 0:
		_harvest_cooldown -= delta

func try_harvest(player_position: Vector2) -> bool:
	if _harvest_cooldown > 0:
		return false
	_harvest_cooldown = HARVEST_INTERVAL
	NetworkRPC.rpc("_receive_harvest_action", {
		"player_position": {"x": player_position.x, "y": player_position.y},
	})
	harvest_attempted.emit(_target_node_id)
	return true
