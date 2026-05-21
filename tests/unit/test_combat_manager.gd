extends GutTest

var _combat: CombatManager
var _pm: PlayerManager
var _im: ItemManager

const A = 1  # attacker
const T = 2  # target

func before_each() -> void:
	_pm = PlayerManager.new()
	_im = ItemManager.new()
	_combat = CombatManager.new()
	_combat.player_manager = _pm
	_combat.world_state_manager = WorldStateManager.new()
	_combat.item_manager = _im

	var atk = _pm.add_player(A, "A"); atk.position = Vector2(100, 100)
	var tgt = _pm.add_player(T, "T"); tgt.position = Vector2(120, 100)
	_im.initialize_player_inventory(A)
	_im.initialize_player_inventory(T)
	_im.add_item(A, "wooden_sword", 1, 50)

func after_each() -> void:
	_combat.free(); _pm.free(); _im.free()

func test_attack_deals_damage() -> void:
	var r = _combat.try_attack(A, T)
	assert_true(r.get("success", false))
	assert_gt(r.get("damage", 0), 0)
	assert_lt(_pm.get_player(T).health, 100)

func test_attack_no_weapon_fails() -> void:
	_im.remove_player_inventory(A)
	_im.initialize_player_inventory(A)
	assert_false(_combat.try_attack(A, T).get("success", false))

func test_attack_out_of_range() -> void:
	_pm.get_player(T).position = Vector2(1000, 1000)
	assert_false(_combat.try_attack(A, T).get("success", false))

func test_attack_dead_target() -> void:
	_pm.get_player(T).health = 0
	assert_false(_combat.try_attack(A, T).get("success", false))

func test_cooldown_prevents_spam() -> void:
	assert_true(_combat.try_attack(A, T).get("success", false))
	assert_false(_combat.try_attack(A, T).get("success", false))

func test_armor_reduces_damage() -> void:
	_im.add_item(T, "iron_armor", 1, 120)
	_im.add_item(T, "iron_helm", 1, 80)
	var r = _combat.try_attack(A, T)
	assert_true(r.get("success", false))
	# 护甲 0.30 减伤，15 伤害 -> ~10
	assert_lt(r.get("damage", 0), 15)

func test_kill_triggers_death_signal() -> void:
	_pm.get_player(T).health = 5
	var fired = false
	_combat.player_died.connect(func(_p, _k): fired = true)
	_combat.try_attack(A, T)
	assert_true(fired)
	assert_eq(_pm.get_player(T).state, SharedEnums.PlayerState.DEAD)

func test_respawn() -> void:
	_pm.get_player(T).health = 5
	_combat.try_attack(A, T)
	assert_true(_combat.is_player_dead(T))
	_combat._process(10.0)
	assert_false(_combat.is_player_dead(T))
	assert_eq(_pm.get_player(T).health, 100)
