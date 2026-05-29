extends SceneTree

var _failed := false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260529

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var broad_windows = 0
	var tributary_junctions = 0
	for y in range(-240, 241, 16):
		for x in range(-240, 241, 16):
			var local_cells = _count_river_cells(generator, x, y, 20)
			if local_cells > 520:
				broad_windows += 1
			if _has_branch_junction(generator, x, y):
				tributary_junctions += 1

	_check(broad_windows == 0, "river network should avoid lake-like local blobs; broad windows=%d" % broad_windows)
	_check(tributary_junctions >= 4, "river network should include visible tributary junctions; junctions=%d" % tributary_junctions)
	quit(1 if _failed else 0)


func _count_river_cells(generator: WorldGenerator, center_x: int, center_y: int, radius: int) -> int:
	var count = 0
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if generator._is_river_cell(x, y):
				count += 1
	return count


func _has_branch_junction(generator: WorldGenerator, center_x: int, center_y: int) -> bool:
	var horizontal = false
	var vertical = false
	for offset in range(-12, 13):
		if generator._is_river_cell(center_x + offset, center_y):
			horizontal = true
		if generator._is_river_cell(center_x, center_y + offset):
			vertical = true
	return horizontal and vertical and generator._is_river_cell(center_x, center_y)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
