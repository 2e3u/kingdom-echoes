extends Node
class_name TutorialController

## 客户端新手引导控制器 — 6步教程链，显示步骤并追踪进度

var _current_step: int = 0
var _tutorial_active: bool = false
var _progress_count: int = 0

const TUTORIAL_STEPS: Array[Dictionary] = [
	{"title": "欢迎来到世界", "desc": "你已觉醒为守望者。先来收集一些基础资源吧。", "action": "wait", "reward": "woodsman_kit"},
	{"title": "采集资源", "desc": "走到树旁按 E 键砍树，收集 3 个木材。", "action": "gather_wood", "target": 3, "reward": "wooden_pickaxe"},
	{"title": "制造工具", "desc": "按 Tab 打开背包，手工制作一个工作台。", "action": "craft", "target": "workbench", "reward": "stone_axe"},
	{"title": "战斗入门", "desc": "装备石剑，清理附近的史莱姆。", "action": "kill", "target": 2, "reward": "health_potion"},
	{"title": "建造基地", "desc": "放置工作台和箱子，打造你的第一个据点。", "action": "place_block", "target": 2, "reward": "teleport_stone"},
	{"title": "自由探索", "desc": "你已经掌握了基础！去找导师聊聊主线，或者自由探索这个世界。", "action": "complete", "reward": ""},
]

signal step_completed(step: int)
signal tutorial_finished()


func start() -> void:
	_current_step = 0
	_progress_count = 0
	_tutorial_active = true
	print("[Tutorial] 新手引导开始")
	_show_current_step()
	# Step 0 是欢迎信息，自动推进到 Step 1
	advance_step()


func _show_current_step() -> void:
	if not _tutorial_active:
		return
	if _current_step >= TUTORIAL_STEPS.size():
		return
	var step = TUTORIAL_STEPS[_current_step]
	print("[Tutorial] 步骤 %d / %d: %s — %s" % [_current_step + 1, TUTORIAL_STEPS.size(), step["title"], step["desc"]])


func advance_step() -> void:
	if not _tutorial_active:
		return
	var prev_step = _current_step
	_current_step += 1
	_progress_count = 0
	if prev_step < TUTORIAL_STEPS.size():
		step_completed.emit(prev_step)
	if _current_step >= TUTORIAL_STEPS.size():
		_tutorial_active = false
		print("[Tutorial] 新手引导完成！")
		tutorial_finished.emit()
		return
	_show_current_step()


func check_gather_progress(item_id: String, quantity: int) -> void:
	if not _tutorial_active:
		return
	if _current_step >= TUTORIAL_STEPS.size():
		return
	var step = TUTORIAL_STEPS[_current_step]
	if step.get("action", "") != "gather_wood":
		return
	if item_id != "wood":
		return
	_progress_count += quantity
	var target = step.get("target", 0)
	print("[Tutorial] 采集进度: %d/%d 木材" % [_progress_count, target])
	if _progress_count >= target:
		advance_step()


func check_craft_progress(item_id: String) -> void:
	if not _tutorial_active:
		return
	if _current_step >= TUTORIAL_STEPS.size():
		return
	var step = TUTORIAL_STEPS[_current_step]
	if step.get("action", "") != "craft":
		return
	if item_id != step.get("target", ""):
		return
	print("[Tutorial] 已制造: %s" % item_id)
	advance_step()


func check_build_progress() -> void:
	if not _tutorial_active:
		return
	if _current_step >= TUTORIAL_STEPS.size():
		return
	var step = TUTORIAL_STEPS[_current_step]
	if step.get("action", "") != "place_block":
		return
	_progress_count += 1
	var target = step.get("target", 0)
	print("[Tutorial] 建造进度: %d/%d" % [_progress_count, target])
	if _progress_count >= target:
		advance_step()


## 检查当前教程是否处于激活状态
func is_active() -> bool:
	return _tutorial_active


## 获取当前步骤索引（0-based），如果未激活返回 -1
func get_current_step() -> int:
	if not _tutorial_active:
		return -1
	return _current_step
