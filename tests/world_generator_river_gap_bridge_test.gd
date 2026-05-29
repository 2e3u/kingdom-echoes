extends SceneTree

var _failed := false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260529

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var short_gaps = 0
	for y in range(-192, 193):
		for x in range(-192, 193):
			if generator._is_river_cell(x, y):
				continue
			if _has_opposing_direct_river_cells(generator, x, y, Vector2i.RIGHT, 2):
				short_gaps += 1
			elif _has_opposing_direct_river_cells(generator, x, y, Vector2i.DOWN, 2):
				short_gaps += 1

	_check(short_gaps <= 2, "river channels should bridge short one-to-two tile gaps; gaps=%d" % short_gaps)
	quit(1 if _failed else 0)


func _has_opposing_direct_river_cells(generator: WorldGenerator, x: int, y: int, direction: Vector2i, max_distance: int) -> bool:
	var has_before = false
	var has_after = false
	for distance in range(1, max_distance + 1):
		if generator._is_direct_river_cell(x - direction.x * distance, y - direction.y * distance):
			has_before = true
		if generator._is_direct_river_cell(x + direction.x * distance, y + direction.y * distance):
			has_after = true
	return has_before and has_after


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
