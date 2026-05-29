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
	continue_button.disabled = true
	hint_label.text = ""
	start_button.grab_focus()


func _apply_texture_button_states() -> void:
	for button in [start_button, continue_button, settings_button, quit_button]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_continue_pressed() -> void:
	hint_label.text = "No saved game yet."


func _on_settings_pressed() -> void:
	hint_label.text = "Settings are coming soon."


func _on_quit_pressed() -> void:
	get_tree().quit()
