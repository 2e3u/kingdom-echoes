extends Node2D
class_name EcologyDebugOverlay

const LAYERS: Array[String] = ["off", "temperature", "moisture", "soil_depth", "elevation", "forest_raw", "forest_suitability", "tree_density"]
const SAMPLE_STEP: int = 2

var world_generator: WorldGenerator = null
var tile_size: int = 64
var active_layer_index: int = 0
var chunks: Array[Vector2i] = []


func setup(generator: WorldGenerator, world_tile_size: int) -> void:
	world_generator = generator
	tile_size = world_tile_size
	visible = false


func set_chunks(new_chunks: Array[Vector2i]) -> void:
	chunks = new_chunks.duplicate()
	queue_redraw()


func cycle_layer() -> String:
	active_layer_index = (active_layer_index + 1) % LAYERS.size()
	visible = get_active_layer() != "off"
	queue_redraw()
	return get_layer_label()


func get_active_layer() -> String:
	return LAYERS[active_layer_index]


func get_layer_label() -> String:
	match get_active_layer():
		"temperature":
			return "temperature"
		"moisture":
			return "moisture"
		"soil_depth":
			return "soil_depth"
		"elevation":
			return "elevation"
		"forest_suitability":
			return "forest suitability"
		"forest_raw":
			return "forest raw"
		"tree_density":
			return "tree density"
		_:
			return "off"


func _draw() -> void:
	if world_generator == null or get_active_layer() == "off":
		return
	var rect_size = Vector2(tile_size * SAMPLE_STEP, tile_size * SAMPLE_STEP)
	for chunk in chunks:
		var base_x = chunk.x * WorldGenerator.CHUNK_SIZE
		var base_y = chunk.y * WorldGenerator.CHUNK_SIZE
		for y in range(0, WorldGenerator.CHUNK_SIZE, SAMPLE_STEP):
			for x in range(0, WorldGenerator.CHUNK_SIZE, SAMPLE_STEP):
				var gx = base_x + x
				var gy = base_y + y
				var value = world_generator.get_debug_ecology_value(get_active_layer(), gx, gy)
				var pos = Vector2(gx * tile_size, gy * tile_size)
				draw_rect(Rect2(pos, rect_size), _color_for_value(get_active_layer(), value))


func _color_for_value(layer: String, value: float) -> Color:
	value = clampf(value, 0.0, 1.0)
	match layer:
		"temperature":
			return Color(value, 0.12, 1.0 - value, 0.48)
		"moisture":
			return Color(0.08, 0.25 + value * 0.55, 0.95, 0.46)
		"soil_depth":
			return Color(0.18 + value * 0.42, 0.10 + value * 0.48, 0.04, 0.46)
		"elevation":
			return Color(0.10 + value * 0.55, 0.12 + value * 0.50, 0.16 + value * 0.44, 0.46)
		"forest_raw":
			return Color(value * 0.18, 0.10 + value * 0.65, value * 0.18, 0.46)
		"forest_suitability":
			return Color(0.04, 0.12 + value * 0.78, 0.06, 0.50)
		"tree_density":
			return Color(0.12 + value * 0.45, 0.08 + value * 0.82, 0.02, 0.52)
		_:
			return Color(value, value, value, 0.45)
