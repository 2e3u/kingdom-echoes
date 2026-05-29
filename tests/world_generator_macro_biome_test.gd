extends SceneTree


func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260524

	var generator = WorldGenerator.new()
	generator.setup(rng, 64)

	var transitions = 0
	var checks = 0
	for y in range(-512, 513, 8):
		var last_biome = generator.get_biome_at(-512, y)
		for x in range(-511, 513):
			var biome = generator.get_biome_at(x, y)
			if biome != last_biome:
				transitions += 1
				last_biome = biome
			checks += 1

	var transition_rate = float(transitions) / float(checks)
	_check(transition_rate < 0.025, "macro biomes should have long uninterrupted spans; transition rate was %.3f" % transition_rate)

	var dominant_blocks = 0
	var total_blocks = 0
	var dominant_share_sum = 0.0
	for by in range(-512, 512, 64):
		for bx in range(-512, 512, 64):
			var counts = {}
			var samples = 0
			for y in range(by, by + 64):
				for x in range(bx, bx + 64):
					var biome = generator.get_biome_at(x, y)
					counts[biome] = counts.get(biome, 0) + 1
					samples += 1
			var largest = 0
			for count in counts.values():
				largest = max(largest, count)
			var share = float(largest) / float(samples)
			dominant_share_sum += share
			if share >= 0.75:
				dominant_blocks += 1
			total_blocks += 1

	var average_dominance = dominant_share_sum / float(total_blocks)
	_check(average_dominance > 0.66, "64x64 areas should usually read as one terrain; average dominance was %.3f" % average_dominance)
	_check(float(dominant_blocks) / float(total_blocks) > 0.45, "many 64x64 areas should be mostly one terrain")

	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
