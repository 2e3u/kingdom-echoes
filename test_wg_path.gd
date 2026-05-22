extends SceneTree

func _init():
    print("=== Testing WorldGenerator code path ===")
    
    # Exact code from world_generator.gd
    var atlas_path = "res://assets/sprites/atlas_grass.png"
    var img = Image.load_from_file(atlas_path)
    print("1. Image: ", "OK" if (img and not img.is_empty()) else "FAILED", " size=", img.get_size() if img else "N/A")
    
    var tex = ImageTexture.create_from_image(img)
    print("2. ImageTexture: ", tex, " type=", tex.get_class())
    
    var ts = TileSet.new()
    var src = TileSetAtlasSource.new()
    src.texture = tex
    src.texture_region_size = Vector2i(48, 48)
    ts.add_source(src, 0)
    print("3. Source count: ", ts.get_source_count())
    
    # Compare: load() approach
    var tex2 = load("res://assets/sprites/atlas_grass.png")
    print("4. load() texture type: ", tex2.get_class())
    
    # Key difference: does ImageTexture from create_from_image actually work for rendering?
    var tm = TileMap.new()
    tm.tile_set = ts
    tm.set_cell(0, Vector2i(5, 5), 0, Vector2i(0, 0))
    print("5. Cell set: source=", tm.get_cell_source_id(0, Vector2i(5, 5)))
    
    # Check if the ImageTexture is valid
    print("6. ImageTexture valid: ", tex.is_valid() if tex.has_method("is_valid") else "no is_valid method")
    print("7. ImageTexture size: ", tex.get_size())
    
    quit()
