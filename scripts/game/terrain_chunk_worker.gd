extends RefCounted
class_name TerrainChunkWorker


func build_chunk_terrain_data(context: Dictionary, cx: int, cy: int) -> Dictionary:
	var state = _create_state(context)
	if bool(context.get("has_layered_terrain", false)):
		return _build_layered_chunk_terrain_data(state, context, cx, cy)
	return _build_chunk_tilemap_data(state, context, cx, cy)


func _create_state(context: Dictionary) -> Dictionary:
	var world_seed = int(context.get("world_seed", 0))
	var biome_noises: Array[FastNoiseLite] = []
	for i in range(WorldGenerator.BIOME_IDS.size()):
		biome_noises.append(_create_noise(world_seed + 1009 + i * 7919, FastNoiseLite.TYPE_PERLIN, 0.0075, 4, 0.50))
	return {
		"world_seed": world_seed,
		"base_noise": _create_noise(world_seed, FastNoiseLite.TYPE_PERLIN, 0.0048, 5, 0.52),
		"overlay_noise": _create_noise(world_seed + 137, FastNoiseLite.TYPE_PERLIN, 0.018, 4, 0.42),
		"river_noise": _create_noise(world_seed + 29017, FastNoiseLite.TYPE_PERLIN, 0.0042, 5, 0.50),
		"river_width_noise": _create_noise(world_seed + 38011, FastNoiseLite.TYPE_PERLIN, 0.013, 3, 0.45),
		"river_branch_noise": _create_noise(world_seed + 47017, FastNoiseLite.TYPE_PERLIN, 0.0085, 4, 0.48),
		"river_warp_noise": _create_noise(world_seed + 59023, FastNoiseLite.TYPE_SIMPLEX, 0.0035, 3, 0.52),
		"temperature_noise": _create_noise(world_seed + 3109, FastNoiseLite.TYPE_PERLIN, 0.0026, 4, 0.48),
		"moisture_noise": _create_noise(world_seed + 7127, FastNoiseLite.TYPE_PERLIN, 0.0032, 4, 0.52),
		"soil_depth_noise": _create_noise(world_seed + 11003, FastNoiseLite.TYPE_PERLIN, 0.0041, 3, 0.46),
		"biome_noises": biome_noises,
		"direct_river_cell_cache": {},
		"river_cell_cache": {},
		"main_river_distance_cache": {},
		"tributary_distance_cache": {},
	}


func _create_noise(seed: int, noise_type: int, frequency: float, octaves: int, gain: float) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = noise_type
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = gain
	return noise


func _build_chunk_tilemap_data(state: Dictionary, context: Dictionary, cx: int, cy: int) -> Dictionary:
	var base_x = cx * WorldGenerator.CHUNK_SIZE
	var base_y = cy * WorldGenerator.CHUNK_SIZE
	var cells: Array[Dictionary] = []
	var biome_variant_counts: Array = context.get("biome_variant_counts", [])

	for y in range(WorldGenerator.CHUNK_SIZE):
		for x in range(WorldGenerator.CHUNK_SIZE):
			var gx = base_x + x
			var gy = base_y + y
			var biome = _get_biome_at(state, gx, gy)
			if biome < 0 or biome >= biome_variant_counts.size():
				continue
			var variant_count = int(biome_variant_counts[biome])
			var v = _tile_variant(state, gx, gy, variant_count)
			cells.append({
				"cell": Vector2i(x, y),
				"source_id": biome,
				"atlas_coords": Vector2i(v % 4, int(v / 4)),
			})

	return {
		"mode": "single",
		"key": Vector2i(cx, cy),
		"name": "Chunk_%d_%d" % [cx, cy],
		"position": Vector2(base_x * int(context.get("tile_size", 64)), base_y * int(context.get("tile_size", 64))),
		"cells": cells,
	}


func _build_layered_chunk_terrain_data(state: Dictionary, context: Dictionary, cx: int, cy: int) -> Dictionary:
	var base_x = cx * WorldGenerator.CHUNK_SIZE
	var base_y = cy * WorldGenerator.CHUNK_SIZE
	var base_cells: Array[Vector2i] = []
	var overlay_cells_by_terrain: Dictionary = {}
	var overlay_tiles: Array[Dictionary] = []
	var base_terrain_id = int(context.get("base_terrain_id", -1))
	var use_global_neighbors = int(context.get("terrain_paint_mode", WorldGenerator.TERRAIN_PAINT_GODOT_CONNECT)) == WorldGenerator.TERRAIN_PAINT_GLOBAL_NEIGHBORS

	for y in range(WorldGenerator.CHUNK_SIZE):
		for x in range(WorldGenerator.CHUNK_SIZE):
			var local_cell = Vector2i(x, y)
			var gx = base_x + x
			var gy = base_y + y
			if base_terrain_id >= 0:
				base_cells.append(local_cell)
			var terrain_id = _get_overlay_terrain_at(state, context, gx, gy)
			if terrain_id < 0:
				continue
			if use_global_neighbors:
				var tile = _get_global_neighbor_terrain_tile(state, context, terrain_id, gx, gy)
				if tile.is_empty():
					_add_overlay_cell(overlay_cells_by_terrain, terrain_id, local_cell)
				else:
					overlay_tiles.append({
						"cell": local_cell,
						"source_id": tile["source_id"],
						"atlas_coords": tile["atlas_coords"],
						"alternative": tile["alternative"],
					})
				continue
			_add_overlay_cell(overlay_cells_by_terrain, terrain_id, local_cell)

	return {
		"mode": "layered",
		"key": Vector2i(cx, cy),
		"name": "Chunk_%d_%d" % [cx, cy],
		"position": Vector2(base_x * int(context.get("tile_size", 64)), base_y * int(context.get("tile_size", 64))),
		"base_cells": base_cells,
		"base_terrain_id": base_terrain_id,
		"overlay_cells_by_terrain": overlay_cells_by_terrain,
		"overlay_tiles": overlay_tiles,
		"overlay_uses_terrain_connect": bool(context.get("overlay_uses_terrain_connect", false)),
		"use_global_neighbors": use_global_neighbors,
	}


func _add_overlay_cell(cells_by_terrain: Dictionary, terrain_id: int, cell: Vector2i) -> void:
	if not cells_by_terrain.has(terrain_id):
		cells_by_terrain[terrain_id] = []
	cells_by_terrain[terrain_id].append(cell)


func _get_overlay_terrain_at(state: Dictionary, context: Dictionary, gx: int, gy: int) -> int:
	var river_terrain_id = int(context.get("river_terrain_id", -1))
	if river_terrain_id >= 0 and _is_river_cell(state, gx, gy):
		return river_terrain_id
	var biome = _get_biome_at(state, gx, gy)
	var overlay_ids: Dictionary = context.get("overlay_terrain_ids_by_biome", {})
	if biome == WorldGenerator.BIOME_WATER and int(overlay_ids.get(WorldGenerator.BIOME_WATER, -1)) == river_terrain_id:
		return -1
	return int(overlay_ids.get(biome, -1))


func _get_global_neighbor_terrain_tile(state: Dictionary, context: Dictionary, terrain_id: int, gx: int, gy: int) -> Dictionary:
	var mask = _get_global_terrain_neighbor_mask(state, context, terrain_id, gx, gy)
	var tiles_by_terrain: Dictionary = context.get("terrain_tiles_by_neighbor_mask", {})
	var tiles_by_mask: Dictionary = tiles_by_terrain.get(terrain_id, {})
	if tiles_by_mask.has(mask):
		return tiles_by_mask[mask]
	var full_tiles: Dictionary = context.get("full_terrain_tiles", {})
	return full_tiles.get(terrain_id, {})


func _get_global_terrain_neighbor_mask(state: Dictionary, context: Dictionary, terrain_id: int, gx: int, gy: int) -> int:
	var mask = 0
	if _get_overlay_terrain_at(state, context, gx - 1, gy) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_LEFT
	if _get_overlay_terrain_at(state, context, gx - 1, gy + 1) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_BOTTOM_LEFT
	if _get_overlay_terrain_at(state, context, gx, gy + 1) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_BOTTOM
	if _get_overlay_terrain_at(state, context, gx + 1, gy + 1) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_BOTTOM_RIGHT
	if _get_overlay_terrain_at(state, context, gx + 1, gy) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_RIGHT
	if _get_overlay_terrain_at(state, context, gx + 1, gy - 1) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_TOP_RIGHT
	if _get_overlay_terrain_at(state, context, gx, gy - 1) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_TOP
	if _get_overlay_terrain_at(state, context, gx - 1, gy - 1) == terrain_id:
		mask |= WorldGenerator.TERRAIN_MASK_TOP_LEFT
	return _normalize_terrain_neighbor_mask(mask)


func _normalize_terrain_neighbor_mask(mask: int) -> int:
	var has_left = (mask & WorldGenerator.TERRAIN_MASK_LEFT) != 0
	var has_bottom_left = (mask & WorldGenerator.TERRAIN_MASK_BOTTOM_LEFT) != 0
	var has_bottom = (mask & WorldGenerator.TERRAIN_MASK_BOTTOM) != 0
	var has_bottom_right = (mask & WorldGenerator.TERRAIN_MASK_BOTTOM_RIGHT) != 0
	var has_right = (mask & WorldGenerator.TERRAIN_MASK_RIGHT) != 0
	var has_top_right = (mask & WorldGenerator.TERRAIN_MASK_TOP_RIGHT) != 0
	var has_top = (mask & WorldGenerator.TERRAIN_MASK_TOP) != 0
	var has_top_left = (mask & WorldGenerator.TERRAIN_MASK_TOP_LEFT) != 0
	if has_bottom_left and not (has_bottom and has_left):
		mask &= ~WorldGenerator.TERRAIN_MASK_BOTTOM_LEFT
	if has_bottom_right and not (has_bottom and has_right):
		mask &= ~WorldGenerator.TERRAIN_MASK_BOTTOM_RIGHT
	if has_top_right and not (has_top and has_right):
		mask &= ~WorldGenerator.TERRAIN_MASK_TOP_RIGHT
	if has_top_left and not (has_top and has_left):
		mask &= ~WorldGenerator.TERRAIN_MASK_TOP_LEFT
	return mask


func _get_biome_at(state: Dictionary, gx: int, gy: int) -> int:
	var ecology = _sample_ecology_layers(state, gx, gy)
	ecology["temperature"] = clampf(float(ecology["temperature"]) + clampf(float(gy) / 10000.0, -0.55, 0.55), 0.0, 1.0)
	return _select_biome_for_ecology(state, ecology, gx, gy)


func _sample_ecology_layers(state: Dictionary, gx: int, gy: int) -> Dictionary:
	var elevation = _sample_base_elevation(state, gx, gy)
	var local_relief = _sample_local_relief(state, gx, gy)
	var temperature = _normalized_noise(state["temperature_noise"], gx, gy)
	var moisture = _normalized_noise(state["moisture_noise"], gx, gy)
	var soil_depth = _normalized_noise(state["soil_depth_noise"], gx, gy)
	moisture = clampf(moisture + maxf(0.35 - elevation, 0.0) * 0.22 - maxf(elevation - 0.72, 0.0) * 0.18, 0.0, 1.0)
	soil_depth = clampf(soil_depth + moisture * 0.10 - elevation * 0.22 - absf(local_relief - 0.5) * 0.08, 0.0, 1.0)
	return {"temperature": temperature, "moisture": moisture, "soil_depth": soil_depth, "elevation": elevation}


func _sample_base_elevation(state: Dictionary, gx: int, gy: int) -> float:
	var macro = (state["base_noise"].get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	var relief = _sample_local_relief(state, gx, gy)
	return clampf((macro - 0.5) * 1.85 + 0.5 + (relief - 0.5) * 0.10, 0.0, 1.0)


func _sample_local_relief(state: Dictionary, gx: int, gy: int) -> float:
	return clampf((state["overlay_noise"].get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5, 0.0, 1.0)


func _normalized_noise(noise: FastNoiseLite, gx: int, gy: int) -> float:
	var normalized = (noise.get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	return clampf((normalized - 0.5) * 2.35 + 0.5, 0.0, 1.0)


func _select_biome_for_ecology(state: Dictionary, ecology: Dictionary, gx: int, gy: int) -> int:
	var best_biome = WorldGenerator.BIOME_GRASS
	var best_score = -INF
	for biome in range(WorldGenerator.BIOME_IDS.size()):
		var score = _score_biome_for_ecology(biome, ecology)
		var biome_noises: Array = state["biome_noises"]
		score += biome_noises[biome].get_noise_2d(float(gx), float(gy)) * 0.085
		score += (_hash_float(state, "macro_biome_jitter", gx, gy, biome) - 0.5) * 0.045
		if score > best_score:
			best_score = score
			best_biome = biome
	return best_biome


func _score_biome_for_ecology(biome: int, ecology: Dictionary) -> float:
	var targets = _get_biome_ecology_targets(biome)
	var score = 1.0
	score -= absf(float(ecology.get("temperature", 0.5)) - targets["temperature"]) * float(targets.get("temperature_weight", 1.0))
	score -= absf(float(ecology.get("moisture", 0.5)) - targets["moisture"]) * float(targets.get("moisture_weight", 1.0))
	score -= absf(float(ecology.get("soil_depth", 0.5)) - targets["soil_depth"]) * float(targets.get("soil_weight", 1.0))
	score -= absf(float(ecology.get("elevation", 0.5)) - targets["elevation"]) * float(targets.get("elevation_weight", 1.0))
	return score + float(targets.get("bias", 0.0))


func _get_biome_ecology_targets(biome: int) -> Dictionary:
	match biome:
		WorldGenerator.BIOME_DIRT:
			return {"temperature": 0.68, "moisture": 0.22, "soil_depth": 0.30, "elevation": 0.50, "bias": -0.02}
		WorldGenerator.BIOME_SAND:
			return {"temperature": 0.84, "moisture": 0.10, "soil_depth": 0.18, "elevation": 0.42, "moisture_weight": 1.25, "elevation_weight": 0.65, "bias": 0.07}
		WorldGenerator.BIOME_SNOW:
			return {"temperature": 0.08, "moisture": 0.50, "soil_depth": 0.35, "elevation": 0.72, "temperature_weight": 1.55, "elevation_weight": 1.10, "bias": 0.02}
		WorldGenerator.BIOME_SWAMP:
			return {"temperature": 0.72, "moisture": 0.88, "soil_depth": 0.88, "elevation": 0.24, "moisture_weight": 1.3, "soil_weight": 1.15, "elevation_weight": 1.20, "bias": 0.02}
		WorldGenerator.BIOME_FOREST:
			return {"temperature": 0.48, "moisture": 0.72, "soil_depth": 0.82, "elevation": 0.46, "soil_weight": 1.15, "elevation_weight": 0.85, "bias": 0.01}
		WorldGenerator.BIOME_STONE:
			return {"temperature": 0.22, "moisture": 0.18, "soil_depth": 0.06, "elevation": 0.88, "soil_weight": 1.65, "elevation_weight": 2.00, "bias": 0.04}
		WorldGenerator.BIOME_WATER:
			return {"temperature": 0.50, "moisture": 0.96, "soil_depth": 0.50, "elevation": 0.08, "temperature_weight": 0.45, "moisture_weight": 1.85, "soil_weight": 0.25, "elevation_weight": 2.50, "bias": 0.02}
		_:
			return {"temperature": 0.55, "moisture": 0.50, "soil_depth": 0.55, "elevation": 0.44, "bias": -0.04}


func _is_river_cell(state: Dictionary, gx: int, gy: int) -> bool:
	var key = Vector2i(gx, gy)
	var river_cache: Dictionary = state["river_cell_cache"]
	if river_cache.has(key):
		return bool(river_cache[key])
	var is_river = _is_direct_river_cell(state, gx, gy) or _is_river_bridge_cell(state, gx, gy)
	river_cache[key] = is_river
	return is_river


func _is_direct_river_cell(state: Dictionary, gx: int, gy: int) -> bool:
	var key = Vector2i(gx, gy)
	var direct_cache: Dictionary = state["direct_river_cell_cache"]
	if direct_cache.has(key):
		return bool(direct_cache[key])
	for oy in range(-WorldGenerator.RIVER_CHANNEL_RADIUS, WorldGenerator.RIVER_CHANNEL_RADIUS + 1):
		for ox in range(-WorldGenerator.RIVER_CHANNEL_RADIUS, WorldGenerator.RIVER_CHANNEL_RADIUS + 1):
			if _is_river_core_cell(state, gx + ox, gy + oy):
				direct_cache[key] = true
				return true
	direct_cache[key] = false
	return false


func _is_river_bridge_cell(state: Dictionary, gx: int, gy: int) -> bool:
	for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
		if _has_direct_river_on_both_sides(state, gx, gy, direction):
			return true
	return false


func _is_river_cardinal_support_cell(state: Dictionary, gx: int, gy: int) -> bool:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _is_direct_river_cell(state, gx + direction.x, gy + direction.y):
			return true
	return false


func _has_direct_river_on_both_sides(state: Dictionary, gx: int, gy: int, direction: Vector2i) -> bool:
	var before_distance = 0
	var after_distance = 0
	for distance in range(1, WorldGenerator.RIVER_BRIDGE_MAX_GAP + 2):
		if _is_direct_river_cell(state, gx - direction.x * distance, gy - direction.y * distance):
			before_distance = distance
		if _is_direct_river_cell(state, gx + direction.x * distance, gy + direction.y * distance):
			after_distance = distance
		if before_distance > 0 and after_distance > 0:
			return before_distance + after_distance <= WorldGenerator.RIVER_BRIDGE_MAX_GAP + 1
	return false


func _is_river_core_cell(state: Dictionary, gx: int, gy: int) -> bool:
	if _get_main_river_distance(state, gx, gy) <= _get_main_river_half_width(state, gx, gy):
		return true
	return _get_tributary_distance(state, gx, gy) <= _get_branch_river_half_width(state, gx, gy)


func _get_main_river_distance(state: Dictionary, gx: int, gy: int) -> float:
	var key = Vector2i(gx, gy)
	var cache: Dictionary = state["main_river_distance_cache"]
	if cache.has(key):
		return float(cache[key])
	var basin = floori(float(gx) / float(WorldGenerator.RIVER_BASIN_WIDTH))
	var best_distance = INF
	for offset in range(-1, 2):
		var candidate_basin = basin + offset
		var river_x = _get_main_river_x(state, candidate_basin, float(gy))
		best_distance = minf(best_distance, absf(float(gx) - river_x))
	cache[key] = best_distance
	return best_distance


func _get_main_river_x(state: Dictionary, basin: int, y: float) -> float:
	var basin_center = float(basin * WorldGenerator.RIVER_BASIN_WIDTH)
	var broad_meander = state["river_noise"].get_noise_2d(float(basin) * 317.0 + 91.0, y) * 70.0
	var fine_meander = state["river_warp_noise"].get_noise_2d(float(basin) * 503.0 - 37.0, y) * 26.0
	return basin_center + broad_meander + fine_meander


func _get_main_river_half_width(state: Dictionary, gx: int, gy: int) -> float:
	var width_sample = (state["river_width_noise"].get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	return WorldGenerator.RIVER_MAIN_HALF_WIDTH + width_sample * WorldGenerator.RIVER_MAIN_WIDTH_VARIATION


func _get_tributary_distance(state: Dictionary, gx: int, gy: int) -> float:
	var key = Vector2i(gx, gy)
	var cache: Dictionary = state["tributary_distance_cache"]
	if cache.has(key):
		return float(cache[key])
	var basin = floori(float(gx) / float(WorldGenerator.RIVER_BASIN_WIDTH))
	var branch_row = floori(float(gy) / float(WorldGenerator.RIVER_BRANCH_INTERVAL))
	var best_distance = INF
	for basin_offset in range(-1, 2):
		for row_offset in range(-1, 2):
			var candidate_basin = basin + basin_offset
			var candidate_row = branch_row + row_offset
			if _hash_float(state, "river_branch_join", candidate_basin, candidate_row) > WorldGenerator.RIVER_BRANCH_JOIN_CHANCE:
				continue
			var junction_y = _get_tributary_junction_y(state, candidate_basin, candidate_row)
			var junction_x = _get_main_river_x(state, candidate_basin, junction_y)
			var side = -1.0 if _hash_float(state, "river_branch_side", candidate_basin, candidate_row) < 0.5 else 1.0
			var reach = lerpf(WorldGenerator.RIVER_BRANCH_REACH_MIN, WorldGenerator.RIVER_BRANCH_REACH_MAX, _hash_float(state, "river_branch_reach", candidate_basin, candidate_row))
			var source = Vector2(
				junction_x + side * reach,
				junction_y + lerpf(-42.0, 42.0, _hash_float(state, "river_branch_source_y", candidate_basin, candidate_row))
			)
			var bend = Vector2(
				(source.x + junction_x) * 0.5 + side * lerpf(-18.0, 26.0, _hash_float(state, "river_branch_bend_x", candidate_basin, candidate_row)),
				(source.y + junction_y) * 0.5 + lerpf(-34.0, 34.0, _hash_float(state, "river_branch_bend_y", candidate_basin, candidate_row))
			)
			var point = Vector2(float(gx), float(gy))
			best_distance = minf(best_distance, _distance_to_segment_if_near(point, source, bend, 12.0))
			best_distance = minf(best_distance, _distance_to_segment_if_near(point, bend, Vector2(junction_x, junction_y), 12.0))
	cache[key] = best_distance
	return best_distance


func _get_tributary_junction_y(state: Dictionary, basin: int, row: int) -> float:
	return float(row * WorldGenerator.RIVER_BRANCH_INTERVAL) + lerpf(-24.0, 24.0, _hash_float(state, "river_branch_junction_y", basin, row))


func _get_branch_river_half_width(state: Dictionary, gx: int, gy: int) -> float:
	var width_sample = (state["river_width_noise"].get_noise_2d(float(gx) + 2117.0, float(gy) - 1693.0) + 1.0) * 0.5
	return WorldGenerator.RIVER_BRANCH_HALF_WIDTH + width_sample * WorldGenerator.RIVER_BRANCH_WIDTH_VARIATION


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return point.distance_to(a)
	var t = clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _distance_to_segment_if_near(point: Vector2, a: Vector2, b: Vector2, margin: float) -> float:
	var min_x = minf(a.x, b.x) - margin
	var max_x = maxf(a.x, b.x) + margin
	var min_y = minf(a.y, b.y) - margin
	var max_y = maxf(a.y, b.y) + margin
	if point.x < min_x or point.x > max_x or point.y < min_y or point.y > max_y:
		return INF
	return _distance_to_segment(point, a, b)


func _get_river_warped_point(state: Dictionary, gx: int, gy: int) -> Vector2:
	var x = float(gx)
	var y = float(gy)
	var warp_x = state["river_warp_noise"].get_noise_2d(x, y) * WorldGenerator.RIVER_DOMAIN_WARP
	var warp_y = state["river_warp_noise"].get_noise_2d(x + 4096.0, y - 2048.0) * WorldGenerator.RIVER_DOMAIN_WARP
	return Vector2(x + warp_x, y + warp_y)


func _get_main_river_threshold(state: Dictionary, gx: int, gy: int) -> float:
	var width_sample = (state["river_width_noise"].get_noise_2d(float(gx), float(gy)) + 1.0) * 0.5
	return WorldGenerator.RIVER_MAIN_BASE_THRESHOLD + width_sample * WorldGenerator.RIVER_MAIN_THRESHOLD_VARIATION


func _get_branch_river_threshold(state: Dictionary, gx: int, gy: int) -> float:
	var width_sample = (state["river_width_noise"].get_noise_2d(float(gx) + 2117.0, float(gy) - 1693.0) + 1.0) * 0.5
	return WorldGenerator.RIVER_BRANCH_BASE_THRESHOLD + width_sample * WorldGenerator.RIVER_BRANCH_THRESHOLD_VARIATION


func _tile_variant(state: Dictionary, gx: int, gy: int, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	return _hash_index(state, variant_count, "tile", gx, gy)


func _hash_index(state: Dictionary, modulo: int, salt: String, a: int = 0, b: int = 0, c: int = 0) -> int:
	if modulo <= 0:
		return 0
	return posmod(hash("%d_%s_%d_%d_%d" % [int(state["world_seed"]), salt, a, b, c]), modulo)


func _hash_float(state: Dictionary, salt: String, a: int = 0, b: int = 0, c: int = 0) -> float:
	return float(_hash_index(state, 1000000, salt, a, b, c)) / 999999.0
