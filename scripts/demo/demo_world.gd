extends Node2D
class_name DemoWorld

## 独立演示场景 — 无需服务端，打开即玩
## WASD 移动，E 采集，左键攻击（仅视觉效果）

const WORLD_TILES_X: int = 60
const WORLD_TILES_Y: int = 40
const TILE_SIZE: int = 32

var player: CharacterBody2D = null
var player_sprite: Sprite2D = null
var camera: Camera2D = null
var hud_labels: Array[Label] = []

# 资源节点
var resource_sprites: Dictionary = {}
var resource_data: Dictionary = {}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 42
	_build_ground()
	_spawn_resources()
	_create_player()
	_setup_camera()
	_create_hud()
	print("[Demo] 演示世界已生成 — WASD 移动, E 采集, 鼠标左键攻击")


func _build_ground() -> void:
	var tm = TileMap.new()
	tm.name = "Ground"
	tm.tile_set = _make_tileset()
	# 铺地板
	for x in range(-5, WORLD_TILES_X + 5):
		for y in range(-5, WORLD_TILES_Y + 5):
			var biome = int((sin(x * 0.15) * cos(y * 0.12) + 1.0) * 1.5)
			tm.set_cell(0, Vector2i(x, y), biome, Vector2i(0, 0))
	add_child(tm)


func _make_tileset() -> TileSet:
	var ts = TileSet.new()
	var colors = [
		Color(0.25, 0.55, 0.15),  # 浅草
		Color(0.20, 0.50, 0.18),  # 中草
		Color(0.30, 0.45, 0.12),  # 深草
	]
	for i in range(3):
		var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(colors[i])
		# 加点纹理噪声
		for _j in range(20):
			var rx = rng.randi_range(0, TILE_SIZE - 1)
			var ry = rng.randi_range(0, TILE_SIZE - 1)
			img.set_pixel(rx, ry, colors[i].lightened(rng.randf_range(-0.05, 0.08)))
		var tex = ImageTexture.create_from_image(img)
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		ts.add_source(src, i)
	return ts


func _spawn_resources() -> void:
	var types = [
		{"id": "tree", "name": "树", "color": Color.SADDLE_BROWN, "count": 80, "size": 24},
		{"id": "rock", "name": "岩石", "color": Color.DIM_GRAY, "count": 40, "size": 16},
		{"id": "herb", "name": "药草", "color": Color(0.8, 0.2, 0.3), "count": 60, "size": 10},
		{"id": "bush", "name": "灌木", "color": Color(0.15, 0.7, 0.2), "count": 50, "size": 14},
	]
	var res_layer = Node2D.new()
	res_layer.name = "Resources"
	add_child(res_layer)

	for t in types:
		for _i in range(t.count):
			var pos = Vector2(
				rng.randf_range(2, WORLD_TILES_X - 2) * TILE_SIZE,
				rng.randf_range(2, WORLD_TILES_Y - 2) * TILE_SIZE,
			)
			var id = "%s_%d" % [t.id, resource_sprites.size()]
			var sprite = Sprite2D.new()
			sprite.position = pos
			sprite.centered = true
			var img = Image.create(t.size, t.size, false, Image.FORMAT_RGBA8)
			img.fill(t.color)
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.scale = Vector2(1.0, 1.0)
			res_layer.add_child(sprite)
			resource_sprites[id] = sprite
			resource_data[id] = {"name": t.name, "depleted": false}


func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(WORLD_TILES_X / 2.0 * TILE_SIZE, WORLD_TILES_Y / 2.0 * TILE_SIZE)
	player.collision_layer = 1

	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = 14.0
	player.add_child(col)

	player_sprite = Sprite2D.new()
	player_sprite.name = "Sprite"
	player_sprite.centered = true
	var img = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.5, 0.9))
	# 画个简单的角色形状：身体 + 眼睛
	for x in range(8, 20):
		for y in range(6, 22):
			img.set_pixel(x, y, Color(0.2, 0.45, 0.85))
	img.set_pixel(10, 10, Color.WHITE)
	img.set_pixel(17, 10, Color.WHITE)
	img.set_pixel(10, 11, Color.WHITE)
	img.set_pixel(17, 11, Color.WHITE)
	player_sprite.texture = ImageTexture.create_from_image(img)
	player.add_child(player_sprite)

	var name_label = Label.new()
	name_label.text = "玩家"
	name_label.position = Vector2(-20, -22)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	player.add_child(name_label)

	add_child(player)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.zoom = Vector2(0.8, 0.8)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _create_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel = Panel.new()
	panel.position = Vector2(10, 10)
	panel.size = Vector2(260, 120)
	panel.modulate = Color(0, 0, 0, 0.6)
	canvas.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.add_theme_constant_override("separation", 4)
	canvas.add_child(vbox)

	var labels_data = ["位置: --", "附近: --", "采集: --", "时间: --", ""]
	var texts = ["[b]王国残响 Demo[/b]", "", "", "", "WASD=移动  E=采集  左键=攻击"]
	for i in range(5):
		var lbl = Label.new()
		lbl.text = texts[i] if i != 0 else texts[0]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(lbl)
		hud_labels.append(lbl)


# ---------- 每帧更新 ----------

var _move_speed: float = 300.0
var _harvest_cooldown: float = 0.0
var _attack_cooldown: float = 0.0


func _process(delta: float) -> void:
	if not player:
		return

	# 移动
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"): dir.y -= 1
	if Input.is_action_pressed("move_down"): dir.y += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	if dir.length() > 0:
		dir = dir.normalized()
	player.position += dir * _move_speed * delta
	player.position.x = clamp(player.position.x, 64, (WORLD_TILES_X - 2) * TILE_SIZE)
	player.position.y = clamp(player.position.y, 64, (WORLD_TILES_Y - 2) * TILE_SIZE)

	# 摄像机跟随
	if camera:
		camera.position = player.position

	# 冷却
	if _harvest_cooldown > 0: _harvest_cooldown -= delta
	if _attack_cooldown > 0: _attack_cooldown -= delta

	# 交互：采集最近资源
	if Input.is_action_just_pressed("interact") and _harvest_cooldown <= 0:
		_try_harvest()

	# HUD 更新
	_update_hud()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and _attack_cooldown <= 0:
		_attack_cooldown = 0.3
		_do_attack_effect()


func _try_harvest() -> void:
	var nearest_id = ""
	var nearest_dist = 60.0
	for rid in resource_sprites:
		if resource_data.get(rid, {}).get("depleted", false):
			continue
		var sprite = resource_sprites[rid]
		var dist = player.position.distance_to(sprite.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = rid

	if nearest_id.is_empty():
		return
	_harvest_cooldown = 0.5
	resource_data[nearest_id]["depleted"] = true
	var sprite: Sprite2D = resource_sprites[nearest_id]
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
	# 弹出采集文字
	_spawn_floating_text(sprite.position, resource_data[nearest_id]["name"] + " +1")
	# 几秒后重生
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
			resource_data[nearest_id]["depleted"] = false
	)


func _do_attack_effect() -> void:
	# 攻击视觉效果：前方发射一道光
	var slash = Sprite2D.new()
	slash.position = player.position + Vector2(30, 0)
	slash.centered = true
	var img = Image.create(40, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.8, 0.2, 0.8))
	slash.texture = ImageTexture.create_from_image(img)
	slash.modulate = Color(1, 0.8, 0.2, 0.9)
	add_child(slash)
	var tween = create_tween()
	tween.tween_property(slash, "position:x", slash.position.x + 60, 0.2)
	tween.tween_callback(slash.queue_free)


func _spawn_floating_text(pos: Vector2, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-20, -10)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 30, 0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)


func _update_hud() -> void:
	if hud_labels.size() < 5:
		return
	var pos_text = "位置: (%d, %d)" % [int(player.position.x), int(player.position.y)]
	hud_labels[0].text = pos_text

	# 统计附近资源
	var nearby = 0
	var nearby_name = "无"
	for rid in resource_sprites:
		if resource_data.get(rid, {}).get("depleted", false):
			continue
		var dist = player.position.distance_to(resource_sprites[rid].position)
		if dist < 80:
			nearby += 1
			if nearby_name == "无":
				nearby_name = resource_data[rid]["name"]
	if nearby > 0:
		nearby_name += " x%d" % nearby
	hud_labels[1].text = "附近: %s" % nearby_name
	hud_labels[2].text = "采集: %s" % ("就绪" if _harvest_cooldown <= 0 else "冷却中...")
	hud_labels[3].text = "攻击: %s" % ("就绪" if _attack_cooldown <= 0 else "冷却中...")
