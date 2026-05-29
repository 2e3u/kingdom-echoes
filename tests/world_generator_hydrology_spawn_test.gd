extends SceneTree

var _failed := false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260529

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	_check(generator.has_method("is_water_cell"), "WorldGenerator should expose a unified water mask")
	_check(generator.has_method("get_river_bank_distance"), "WorldGenerator should expose river bank distance")
	_check(generator.has_method("_get_water_spawn_multiplier"), "WorldGenerator should gate spawns against water")
	if _failed:
		quit(1)
		return

	var river_cell = _find_river_cell(generator)
	if not _check(river_cell != Vector2i(999999, 999999), "test seed should produce a nearby river cell"):
		quit(1)
		return

	var tree_definition = {
		"id": "tree",
		"water_clearance": 3,
		"water_falloff": 6,
	}
	_check(generator.is_water_cell(river_cell.x, river_cell.y), "river cells should be included in the unified water mask")
	_check(
		is_zero_approx(generator._get_water_spawn_multiplier(tree_definition, river_cell.x, river_cell.y)),
		"trees should never spawn inside river water"
	)

	var bank_cell = _find_river_bank_cell(generator, river_cell, 3)
	if _check(bank_cell != Vector2i(999999, 999999), "test seed should expose a dry river bank"):
		_check(generator.get_river_bank_distance(bank_cell.x, bank_cell.y, 6) <= 3, "bank cell should be within the tree clearance radius")
		_check(
			is_zero_approx(generator._get_water_spawn_multiplier(tree_definition, bank_cell.x, bank_cell.y)),
			"trees should leave a clear bank around river water"
		)

	var riparian_definition = {
		"id": "tall_grass",
		"allow_near_water": true,
		"water_clearance": 0,
		"water_falloff": 1,
	}
	_check(
		generator._get_water_spawn_multiplier(riparian_definition, bank_cell.x, bank_cell.y) > 0.95,
		"riparian vegetation should be allowed on dry river banks"
	)

	quit(1 if _failed else 0)


func _find_river_cell(generator: WorldGenerator) -> Vector2i:
	for y in range(-160, 161):
		for x in range(-160, 161):
			if generator._is_river_cell(x, y):
				return Vector2i(x, y)
	return Vector2i(999999, 999999)


func _find_river_bank_cell(generator: WorldGenerator, river_cell: Vector2i, max_distance: int) -> Vector2i:
	for radius in range(1, max_distance + 1):
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				if max(abs(ox), abs(oy)) != radius:
					continue
				var cell = river_cell + Vector2i(ox, oy)
				if generator.is_water_cell(cell.x, cell.y):
					continue
				if generator.get_river_bank_distance(cell.x, cell.y, max_distance) <= max_distance:
					return cell
	return Vector2i(999999, 999999)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
