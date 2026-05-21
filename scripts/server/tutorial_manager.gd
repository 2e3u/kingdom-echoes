extends Node
class_name TutorialManager

## 服务端教程奖励管理器 — 根据完成步骤发放物品奖励

var item_manager: ItemManager = null


func grant_tutorial_reward(player_id: int, step: int) -> void:
	if not item_manager:
		push_error("[TutorialManager] item_manager 未设置，无法发放奖励")
		return

	match step:
		0:
			# woodsman_kit: 木材 x10, 石头 x5, 纤维 x5
			item_manager.add_item(player_id, "wood", 10)
			item_manager.add_item(player_id, "stone", 5)
			item_manager.add_item(player_id, "fiber", 5)
			print("[TutorialManager] 玩家 %d 完成步骤 %d，获得新手工具包 (木材x10, 石头x5, 纤维x5)" % [player_id, step])
		1:
			# wooden_pickaxe
			item_manager.add_item(player_id, "wooden_pickaxe", 1)
			print("[TutorialManager] 玩家 %d 完成步骤 %d，获得木镐" % [player_id, step])
		2:
			# stone_axe
			item_manager.add_item(player_id, "stone_axe", 1)
			print("[TutorialManager] 玩家 %d 完成步骤 %d，获得石斧" % [player_id, step])
		3:
			# health_potion
			item_manager.add_item(player_id, "health_potion", 1)
			print("[TutorialManager] 玩家 %d 完成步骤 %d，获得生命药剂" % [player_id, step])
		4:
			# teleport_stone
			item_manager.add_item(player_id, "teleport_stone", 1)
			print("[TutorialManager] 玩家 %d 完成步骤 %d，获得传送石" % [player_id, step])
		5:
			# 教程完成，无物品奖励
			print("[TutorialManager] 玩家 %d 完成全部教程 (步骤 %d)，无额外奖励" % [player_id, step])
		_:
			push_error("[TutorialManager] 无效的教程步骤: %d (玩家 %d)" % [step, player_id])
