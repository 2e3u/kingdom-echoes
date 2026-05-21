extends Node
class_name InputHandler

## 输入处理器 — 收集本地玩家输入并发送到服务端
## 处理键盘、鼠标、触摸（移动端）输入

var move_direction: Vector2 = Vector2.ZERO
var interact_pressed: bool = false
var tick_counter: int = 0
var last_sent_input: Dictionary = {}

var _throttle_timer: float = 0.0
var _last_sent_direction: Vector2 = Vector2.ZERO
var _last_sent_interact: bool = false
var _player_id: int = 0
var gathering_controller: GatheringController = null

## 输入变化时发射，由 GameClientManager 接收并发送 RPC
signal input_changed(input_data: Dictionary)
## 攻击触发信号（鼠标左键）
signal attack_triggered()

func _ready() -> void:
	print("[InputHandler] 输入处理器已初始化")


func set_player_id(id: int) -> void:
	_player_id = id


func _process(delta: float) -> void:
	if _player_id <= 0:
		return
	_collect_input()
	_throttle_timer += delta
	# 以 tick_rate 频率检查输入变化
	var max_sends = 5
	while _throttle_timer >= SharedConstants.TICK_DELTA:
		_throttle_timer -= SharedConstants.TICK_DELTA
		_send_if_changed()
		max_sends -= 1
		if max_sends <= 0:
			push_warning("[InputHandler] 达到每帧最大发送限制，可能存在卡顿")
			_throttle_timer = 0.0
			break


func _send_if_changed() -> void:
	var direction_changed = move_direction != _last_sent_direction
	var interact_changed = interact_pressed != _last_sent_interact
	if not direction_changed and not interact_changed:
		return
	_last_sent_direction = move_direction
	_last_sent_interact = interact_pressed
	var input_data = get_input_dict()
	input_changed.emit(input_data)


func _collect_input() -> void:
	# 移动方向 (WASD / 方向键)
	move_direction = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		move_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		move_direction.y += 1
	if Input.is_action_pressed("move_left"):
		move_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		move_direction.x += 1
	move_direction = move_direction.normalized()

	# 交互
	interact_pressed = Input.is_action_just_pressed("interact")

	tick_counter += 1


func get_input_dict() -> Dictionary:
	# 返回当前输入数据，封装为可发送的 Dictionary
	var input = SharedDataModels.PlayerInput.new()
	input.player_id = _player_id
	input.move_direction = move_direction
	input.interact = interact_pressed
	input.tick = tick_counter
	input.timestamp = Time.get_ticks_msec() / 1000.0
	return input.to_dict()



func get_predicted_position(current_pos: Vector2, speed: float) -> Vector2:
	# 客户端预测：根据输入预估下个位置
	return current_pos + move_direction * speed * SharedConstants.TICK_DELTA


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		attack_triggered.emit()
	if event.is_action_pressed("interact"):
		if gathering_controller:
			gathering_controller.try_harvest(_get_local_player_position())


func _get_local_player_position() -> Vector2:
	var parent = get_parent()
	if parent and parent is GameClient:
		var client = parent as GameClient
		if client.game_client:
			return client.game_client.get_predicted_or_server_position()
	return Vector2.ZERO
