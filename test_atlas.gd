extends SceneTree

func _init():
    print("=== Testing atlas loading ===")
    
    # Method 1: Image.load_from_file (current code)
    var img1 = Image.load_from_file("res://assets/sprites/atlas_grass.png")
    print("1. Image.load_from_file: ", "OK" if (img1 and not img1.is_empty()) else "FAILED", " size=", img1.get_size() if img1 else "N/A")
    
    # Method 2: load() (standard Godot)
    var tex = load("res://assets/sprites/atlas_grass.png")
    print("2. load(): ", "OK" if tex else "FAILED", " type=", tex.get_class() if tex else "N/A")
    
    # Method 3: ResourceLoader
    var rl = ResourceLoader.load("res://assets/sprites/atlas_grass.png")
    print("3. ResourceLoader.load: ", "OK" if rl else "FAILED")
    
    # Check if import files exist
    var import_file = FileAccess.open("res://assets/sprites/atlas_grass.png.import", FileAccess.READ)
    print("4. .import file exists: ", "YES" if import_file else "NO")
    
    quit()
