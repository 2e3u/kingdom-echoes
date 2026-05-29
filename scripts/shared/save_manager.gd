extends Node
## 存档管理器（autoload 单例）
## 把游戏进度写入 user://savegame.json（跨平台的用户数据目录）。
## 存档内容由 OfflineGame 收集与应用；读档由主菜单"继续游戏"触发。

const SAVE_PATH := "user://savegame.json"

## 主菜单点"继续游戏"时置 true；OfflineGame 启动时据此决定是否读档（用后即清）。
var should_load_on_start := false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func write_save(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 无法写入存档 %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
