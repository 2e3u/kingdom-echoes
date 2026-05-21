class_name GutTest
extends RefCounted
## GUT 测试基类占位 — 安装 GUT 插件后替换为真实基类
## 此文件仅用于消除 Godot 编辑器报错，不影响游戏运行

func assert_eq(actual, expected, _text: String = "") -> void: pass
func assert_ne(actual, expected, _text: String = "") -> void: pass
func assert_true(condition: bool, _text: String = "") -> void: pass
func assert_false(condition: bool, _text: String = "") -> void: pass
func assert_gt(actual, expected, _text: String = "") -> void: pass
func assert_ge(actual, expected, _text: String = "") -> void: pass
func assert_lt(actual, expected, _text: String = "") -> void: pass
func assert_le(actual, expected, _text: String = "") -> void: pass
func assert_null(value, _text: String = "") -> void: pass
func assert_not_null(value, _text: String = "") -> void: pass
func assert_file_exists(_path: String, _text: String = "") -> void: pass
func before_each() -> void: pass
func after_each() -> void: pass
