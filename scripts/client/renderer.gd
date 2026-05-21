extends Node
class_name ClientRenderer

## 客户端渲染器 — 负责绘制所有游戏对象
## 从 GameClientManager 获取插值后的状态，渲染到 Canvas

var player_sprites: Dictionary = {}  # {player_id: Sprite2D}
var _game_client: GameClientManager = null

@export var world_path: NodePath = ^"World"

var world_node: Node2D = null

var ground_tilemap: TileMap = null
var block_sprites: Dictionary = {}  # {"x,y": Sprite2D}
var resource_sprites: Dictionary = {}  # {node_id: Sprite2D}


func _ready() -> void:
	# 查找 World 节点（通过 @export NodePath 配置）
	world_node = get_node_or_null(world_path) as Node2D
	if world_node:
		print("[Renderer] 渲染器已初始化, World 节点已找到")
	else:
		push_warning("[Renderer] 未找到 World 节点")
	_setup_tilemap()


func set_game_client(client: GameClientManager) -> void:
	_game_client = client
	# 连接到世界状态信号
	if client and not client.world_state_received.is_connected(_on_world_state_received):
		client.world_state_received.connect(_on_world_state_received)
	# 连接到玩家加入/离开信号
	if client:
		if not client.remote_player_joined.is_connected(_on_remote_player_joined):
			client.remote_player_joined.connect(_on_remote_player_joined)
		if not client.remote_player_left.is_connected(_on_remote_player_left):
			client.remote_player_left.connect(_on_remote_player_left)


func _on_world_state_received(state: Dictionary) -> void:
	# 收到服务端世界状态，触发渲染
	render_world_state(state)


func render_world_state(world_state: Dictionary) -> void:
	# 根据世界状态渲染所有游戏对象
	if not world_node:
		return

	var players: Array = world_state.get("players", [])
	var rendered_ids: Array[int] = []

	for player_data in players:
		var pid = player_data.get("player_id", -1)
		if pid < 0:
			continue
		rendered_ids.append(pid)
		_update_player_sprite(pid, player_data)

	# 清理已离开的玩家精灵（先收集再删除，避免迭代时修改字典）
	var ids_to_remove: Array = []
	for pid in player_sprites.keys():
		if pid not in rendered_ids:
			ids_to_remove.append(pid)
	for pid in ids_to_remove:
		remove_player_sprite(pid)

	_render_resource_nodes(world_state.get("resource_nodes", {}))
	_render_blocks(world_state.get("placed_blocks", {}))


func _update_player_sprite(player_id: int, player_data: Dictionary) -> void:
	# 确保精灵存在
	if not player_sprites.has(player_id):
		_create_player_sprite(player_id)

	var sprite: Sprite2D = player_sprites[player_id]
	if not sprite:
		return

	# 获取位置：本地玩家使用预测位置，远程玩家使用服务端位置
	var local_id = _game_client.player_id if _game_client else 0
	var pos_data: Dictionary
	if player_id == local_id and _game_client:
		# 本地玩家使用预测位置（更低的延迟手感）
		var pred = _game_client.get_predicted_or_server_position()
		pos_data = {"x": pred.x, "y": pred.y}
	else:
		pos_data = player_data.get("position", {"x": 0.0, "y": 0.0})

	sprite.position = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))


func _create_player_sprite(player_id: int) -> void:
	if not world_node:
		return

	var players_node = world_node.get_node_or_null("Players")
	if not players_node:
		players_node = Node2D.new()
		players_node.name = "Players"
		world_node.add_child(players_node)

	var sprite = Sprite2D.new()
	sprite.name = "Player_%d" % player_id
	sprite.centered = true

	# 生成简单的占位纹理（彩色方块）
	var placeholder = _create_placeholder_texture(player_id)
	sprite.texture = placeholder

	# 根据 player_id 分配颜色
	var color = _get_player_color(player_id)
	sprite.modulate = color
	sprite.scale = Vector2(0.25, 0.25)

	players_node.add_child(sprite)
	player_sprites[player_id] = sprite

	print("[Renderer] 创建玩家精灵: %d (颜色: %s)" % [player_id, color])


func _get_player_color(player_id: int) -> Color:
	# 根据 player_id 生成稳定的颜色
	var colors = [
		Color.RED,
		Color.BLUE,
		Color.GREEN,
		Color.YELLOW,
		Color.ORANGE,
		Color.PURPLE,
		Color.CYAN,
		Color.MAGENTA,
	]
	return colors[player_id % colors.size()]


func _create_placeholder_texture(player_id: int) -> ImageTexture:
	# 创建简单的方形占位纹理（64x64 白色方块）
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var color = _get_player_color(player_id)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func remove_player_sprite(player_id: int) -> void:
	if player_sprites.has(player_id):
		var sprite: Sprite2D = player_sprites[player_id]
		if sprite:
			sprite.queue_free()
		player_sprites.erase(player_id)
		print("[Renderer] 移除玩家精灵: %d" % player_id)


# ---------- 加入/离开事件处理 ----------

func _on_remote_player_joined(peer_id: int, _player_data: Dictionary) -> void:
	# 收到新玩家加入通知，立即创建精灵（位置由后续世界状态更新）
	if not player_sprites.has(peer_id):
		_create_player_sprite(peer_id)
		print("[Renderer] 收到远程玩家加入: %d" % peer_id)


func _on_remote_player_left(peer_id: int) -> void:
	# 收到玩家离开通知，立即移除精灵
	remove_player_sprite(peer_id)
	print("[Renderer] 收到远程玩家离开: %d" % peer_id)


func clear_all_sprites() -> void:
	for sprite in player_sprites.values():
		if sprite:
			sprite.queue_free()
	player_sprites.clear()
	for sprite in block_sprites.values():
		if sprite:
			sprite.queue_free()
	block_sprites.clear()
	for sprite in resource_sprites.values():
		if sprite:
			sprite.queue_free()
	resource_sprites.clear()
	print("[Renderer] 已清除所有玩家精灵")


func _setup_tilemap() -> void:
	if not world_node:
		return
	ground_tilemap = TileMap.new()
	ground_tilemap.name = "GroundLayer"
	ground_tilemap.tile_set = _create_ground_tileset()
	world_node.add_child(ground_tilemap)
	var blocks_node = Node2D.new()
	blocks_node.name = "BlocksLayer"
	blocks_node.y_sort_enabled = true
	world_node.add_child(blocks_node)
	var resources_node = Node2D.new()
	resources_node.name = "ResourcesLayer"
	resources_node.y_sort_enabled = true
	world_node.add_child(resources_node)


func _create_ground_tileset() -> TileSet:
	var ts = TileSet.new()
	var grass_image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	grass_image.fill(Color(0.3, 0.6, 0.2))
	var grass_tex = ImageTexture.create_from_image(grass_image)
	var grass_source = TileSetAtlasSource.new()
	grass_source.texture = grass_tex
	grass_source.texture_region_size = Vector2i(64, 32)
	ts.add_source(grass_source, 0)
	ts.add_physics_layer(0)
	return ts


func _render_resource_nodes(nodes: Dictionary) -> void:
	if not world_node:
		return
	var resources_node = world_node.get_node_or_null("ResourcesLayer")
	if not resources_node:
		return
	for node_id in nodes:
		var node_data = nodes[node_id]
		if node_data.get("is_depleted", false):
			if resource_sprites.has(node_id):
				resource_sprites[node_id].queue_free()
				resource_sprites.erase(node_id)
			continue
		if not resource_sprites.has(node_id):
			var sprite = _create_resource_sprite(node_data)
			resources_node.add_child(sprite)
			resource_sprites[node_id] = sprite


func _create_resource_sprite(node_data: Dictionary) -> Sprite2D:
	var sprite = Sprite2D.new()
	var pos = node_data.get("position", {"x": 0.0, "y": 0.0})
	sprite.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	var res_type = node_data.get("resource_type", 0)
	var color = Color.GREEN
	match res_type:
		SharedEnums.HarvestType.WOOD: color = Color.SADDLE_BROWN
		SharedEnums.HarvestType.ORE: color = Color.GRAY
		SharedEnums.HarvestType.HERB: color = Color.RED
		SharedEnums.HarvestType.FIBER: color = Color.WEB_GREEN
	sprite.modulate = color
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(1, 1)
	return sprite


func _render_blocks(blocks: Dictionary) -> void:
	if not world_node:
		return
	var blocks_node = world_node.get_node_or_null("BlocksLayer")
	if not blocks_node:
		return
	for key in blocks:
		var block_data = blocks[key]
		if not block_sprites.has(key):
			var sprite = Sprite2D.new()
			var gp = block_data.get("grid_pos", {"x": 0, "y": 0})
			var px = gp.get("x", 0) * SharedConstants.TILE_SIZE
			var py = gp.get("y", 0) * SharedConstants.TILE_SIZE
			sprite.position = Vector2(px, py)
			var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
			img.fill(Color.SANDY_BROWN)
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.scale = Vector2(1, 1)
			blocks_node.add_child(sprite)
			block_sprites[key] = sprite


func _world_to_iso(world_pos: Vector2) -> Vector2:
	var tile_size = SharedConstants.TILE_SIZE
	var iso_x = (world_pos.x - world_pos.y) / tile_size * (tile_size / 2.0)
	var iso_y = (world_pos.x + world_pos.y) / tile_size * (tile_size / 4.0)
	return Vector2(iso_x, iso_y)


func _process(_delta: float) -> void:
	# 每帧可在此做平滑插值（暂时由信号驱动渲染）
	pass
