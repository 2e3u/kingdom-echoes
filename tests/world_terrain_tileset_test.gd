extends SceneTree

var _failed := false


func _init() -> void:
	var tile_set = load("res://assets/tilesets/world_terrain_tileset.tres") as TileSet
	_check(tile_set != null, "world terrain TileSet should load")
	_check(tile_set.get_terrain_sets_count() >= 1, "TileSet should have a terrain set")
	_check(tile_set.get_terrains_count(0) >= 5, "TileSet should define grass, mud, sand, snow, and river terrains")

	var expected := {
		0: "grass0",
		1: "mud1",
		2: "sand2",
		3: "snow3",
		4: "river4",
	}
	for terrain_id in expected:
		if terrain_id >= tile_set.get_terrains_count(0):
			_check(false, "terrain %d should exist" % terrain_id)
			continue
		_check(tile_set.get_terrain_name(0, terrain_id) == expected[terrain_id], "terrain %d should be named %s" % [terrain_id, expected[terrain_id]])
		_check(_terrain_has_full_tile(tile_set, terrain_id), "terrain %d should have a full center tile" % terrain_id)

	if _failed:
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _terrain_has_full_tile(tile_set: TileSet, terrain_id: int) -> bool:
	for i in range(tile_set.get_source_count()):
		var source_id = tile_set.get_source_id(i)
		var source = tile_set.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue
		var atlas_source = source as TileSetAtlasSource
		for j in range(atlas_source.get_tiles_count()):
			var atlas_coords = atlas_source.get_tile_id(j)
			for n in range(atlas_source.get_alternative_tiles_count(atlas_coords)):
				var alternative = atlas_source.get_alternative_tile_id(atlas_coords, n)
				var tile_data = atlas_source.get_tile_data(atlas_coords, alternative)
				if tile_data.terrain_set != 0 or tile_data.terrain != terrain_id:
					continue
				if _is_full_terrain_tile(tile_data, terrain_id):
					return true
	return false


func _is_full_terrain_tile(tile_data: TileData, terrain_id: int) -> bool:
	var neighbors = [
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	]
	for neighbor in neighbors:
		if tile_data.get_terrain_peering_bit(neighbor) != terrain_id:
			return false
	return true
