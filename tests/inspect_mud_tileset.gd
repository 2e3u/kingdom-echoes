extends SceneTree

const NEIGHBORS = [
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
]


func _init() -> void:
	var tile_set = load("res://assets/tilesets/world_terrain_tileset.tres") as TileSet
	print("terrain mode=", tile_set.get_terrain_set_mode(0))
	for i in range(tile_set.get_source_count()):
		var source_id = tile_set.get_source_id(i)
		var source = tile_set.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue
		var atlas = source as TileSetAtlasSource
		for j in range(atlas.get_tiles_count()):
			var coords = atlas.get_tile_id(j)
			var tile_data = atlas.get_tile_data(coords, 0)
			if tile_data.terrain != 1:
				continue
			var bits = ""
			for neighbor in NEIGHBORS:
				bits += "1" if tile_data.get_terrain_peering_bit(neighbor) == 1 else "0"
			print("mud tile source=", source_id, " coords=", coords, " bits=", bits)
	quit()
