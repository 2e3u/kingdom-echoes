extends SceneTree

func _init():
    print("=== Testing TileSet build ===")
    
    var ts = TileSet.new()
    var tex = load("res://assets/sprites/atlas_grass.png")
    print("1. Texture: ", tex, " type=", tex.get_class())
    
    var src = TileSetAtlasSource.new()
    src.texture = tex
    src.texture_region_size = Vector2i(48, 48)
    ts.add_source(src, 0)
    
    print("2. Source added, source_count=", ts.get_source_count())
    print("3. Tile size from source: ", src.texture_region_size)
    print("4. Atlas texture size: ", src.texture.get_size())
    
    # Try creating TileMap
    var tm = TileMap.new()
    tm.tile_set = ts
    tm.set_cell(0, Vector2i(0, 0), 0, Vector2i(0, 0))
    tm.set_cell(0, Vector2i(1, 0), 0, Vector2i(1, 0))
    
    print("5. Cell (0,0): ", tm.get_cell_source_id(0, Vector2i(0, 0)))
    print("6. Cell (1,0): ", tm.get_cell_source_id(0, Vector2i(1, 0)))
    print("7. TileMap tile_set valid: ", tm.tile_set != null)
    
    quit()
