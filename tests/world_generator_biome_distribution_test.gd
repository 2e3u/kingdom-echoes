extends SceneTree

var _failed = false


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260523

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var counts := {}
	for biome in WorldGenerator.BIOME_IDS.size():
		counts[biome] = 0

	var sample_size := 0
	for y in range(-1024, 1024, 8):
		for x in range(-1024, 1024, 8):
			var biome = generator.get_biome_at(x, y)
			counts[biome] += 1
			sample_size += 1

	var temperate_share = 0.0
	var extreme_share = 0.0
	for biome in WorldGenerator.BIOME_IDS.size():
		var share = float(counts[biome]) / float(sample_size)
		_check(share >= 0.015, "Biome %s should appear in ecological generation; share was %.3f" % [WorldGenerator.BIOME_IDS[biome], share])
		if biome in [WorldGenerator.BIOME_GRASS, WorldGenerator.BIOME_DIRT, WorldGenerator.BIOME_FOREST]:
			temperate_share += share
		else:
			extreme_share += share

	_check(temperate_share > 0.38, "temperate biomes should remain common")
	_check(temperate_share < 0.72, "temperate biomes should not erase harsher ecological niches")
	_check(extreme_share > 0.28, "dry, cold, wet, rocky, and water niches should have visible map presence")

	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
