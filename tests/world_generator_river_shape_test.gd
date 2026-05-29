extends SceneTree

var _failed := false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260526

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	if not _check(generator.has_method("_is_river_cell"), "WorldGenerator should expose river-shaped terrain sampling"):
		return

	var river_cells = 0
	var samples = 0
	var useful_columns = 0
	var useful_rows = 0
	var widest_column = 0
	var widest_row = 0
	var longest_horizontal_run = 0
	var longest_vertical_run = 0
	var junction_cells = 0
	var isolated_cells = 0
	var weakly_connected_cells = 0
	var narrow_samples = 0
	var wide_samples = 0
	for x in range(-256, 257):
		var column_cells = 0
		for y in range(-256, 257):
			var is_river = generator._is_river_cell(x, y)
			if is_river:
				river_cells += 1
				column_cells += 1
			samples += 1
		if column_cells >= 2 and column_cells <= 60:
			useful_columns += 1
		widest_column = max(widest_column, column_cells)

	for y in range(-256, 257):
		var row_cells = 0
		var run = 0
		for x in range(-256, 257):
			if generator._is_river_cell(x, y):
				row_cells += 1
				run += 1
				longest_horizontal_run = max(longest_horizontal_run, run)
			else:
				run = 0
		if row_cells >= 2 and row_cells <= 60:
			useful_rows += 1
		widest_row = max(widest_row, row_cells)

	for x in range(-256, 257):
		var run = 0
		for y in range(-256, 257):
			if generator._is_river_cell(x, y):
				run += 1
				longest_vertical_run = max(longest_vertical_run, run)
			else:
				run = 0

	for y in range(-252, 253):
		for x in range(-252, 253):
			if not generator._is_river_cell(x, y):
				continue
			var cardinal_neighbors = 0
			if generator._is_river_cell(x - 1, y):
				cardinal_neighbors += 1
			if generator._is_river_cell(x + 1, y):
				cardinal_neighbors += 1
			if generator._is_river_cell(x, y - 1):
				cardinal_neighbors += 1
			if generator._is_river_cell(x, y + 1):
				cardinal_neighbors += 1
			if cardinal_neighbors == 0:
				isolated_cells += 1
			if cardinal_neighbors <= 1:
				weakly_connected_cells += 1
			if cardinal_neighbors >= 3:
				junction_cells += 1
			if posmod(x, 8) != 0 or posmod(y, 8) != 0:
				continue
			var local_cells = 0
			for oy in range(-3, 4):
				for ox in range(-3, 4):
					if generator._is_river_cell(x + ox, y + oy):
						local_cells += 1
			if local_cells <= 24:
				narrow_samples += 1
			if local_cells >= 18:
				wide_samples += 1

	var coverage = float(river_cells) / float(samples)
	_check(coverage >= 0.010 and coverage <= 0.08, "river terrain should be sparse, not lake-like; coverage was %.3f" % coverage)
	_check(widest_column <= 260, "river columns may contain a continuous main channel but should not become a lake wall; widest column was %d cells" % widest_column)
	_check(widest_row <= 130, "river rows should stay narrow across multiple branches; widest row was %d cells" % widest_row)
	_check(useful_columns >= 120, "river should cross many columns; useful columns were %d" % useful_columns)
	_check(useful_rows >= 120, "river should cross many rows instead of only horizontal bands; useful rows were %d" % useful_rows)
	_check(longest_horizontal_run >= 10, "tributaries should form readable horizontal or diagonal segments; longest run was %d" % longest_horizontal_run)
	_check(longest_vertical_run >= 12, "river should have vertical/diagonal movement; longest vertical run was %d" % longest_vertical_run)
	_check(junction_cells >= 20, "river network should include tributary junctions; junction cells were %d" % junction_cells)
	_check(isolated_cells <= 4, "river should not break into isolated water dots; isolated cells were %d" % isolated_cells)
	_check(weakly_connected_cells <= river_cells / 5, "most river cells should be connected to a channel; weakly connected cells were %d of %d" % [weakly_connected_cells, river_cells])
	_check(narrow_samples >= 5, "river network should include narrow segments; narrow samples were %d" % narrow_samples)
	_check(wide_samples >= 10, "river network should include wider confluences or broad segments; wide samples were %d" % wide_samples)

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	_failed = true
	return false
