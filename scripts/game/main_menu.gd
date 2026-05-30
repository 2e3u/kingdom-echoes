extends Control
class_name MainMenu

const GAME_SCENE_PATH: String = "res://scenes/kingdom_echoes.tscn"

@onready var start_button: BaseButton = %StartButton
@onready var continue_button: BaseButton = %ContinueButton
@onready var settings_button: BaseButton = %SettingsButton
@onready var quit_button: BaseButton = %QuitButton
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	_apply_texture_button_states()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	var sm = _save_manager()
	continue_button.disabled = sm == null or not sm.has_save()  # 有存档才能"继续"
	hint_label.text = ""
	start_button.grab_focus()


## 动态获取 SaveManager 单例（用路径访问而非全局符号，便于在无 autoload 的测试环境中加载本脚本）
func _save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")


func _apply_texture_button_states() -> void:
	for button in [start_button, continue_button, settings_button, quit_button]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# 去掉获得键盘焦点时的默认白色边框（保留焦点/回车选中功能，只是不画框）
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_start_pressed() -> void:
	var sm = _save_manager()
	if sm:
		sm.should_load_on_start = false  # 全新世界
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_continue_pressed() -> void:
	var sm = _save_manager()
	if sm == null or not sm.has_save():
		hint_label.text = "No saved game yet."
		return
	sm.should_load_on_start = true  # 通知游戏场景读档
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_settings_pressed() -> void:
	hint_label.text = "Settings are coming soon."


func _on_quit_pressed() -> void:
	get_tree().quit()
