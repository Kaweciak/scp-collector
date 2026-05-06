extends Node

signal players_updated

var peer = ENetMultiplayerPeer.new()
var player_scene: PackedScene = preload("res://player/player_body_3d.tscn")

var connected_peer_ids: Array[int] = []

var player_names: Dictionary = {}

var spawner: MultiplayerSpawner = MultiplayerSpawner.new()

func _ready() -> void:
	add_child(spawner)
	spawner.add_spawnable_scene("res://player/player_body_3d.tscn")


func host(nickname: String) -> void:
	peer.create_server(2137)
	multiplayer.multiplayer_peer = peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	var my_id = multiplayer.get_unique_id()

	if not connected_peer_ids.has(my_id):
		connected_peer_ids.append(my_id)

	player_names[my_id] = nickname


func join(ip_address: String = "127.0.0.1", nickname: String = "Player") -> void:
	var result = peer.create_client(ip_address, 2137)
	if result == OK:
		multiplayer.multiplayer_peer = peer

		multiplayer.connected_to_server.connect(func():
			rpc_id(1, "register_player", nickname)
		)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


@rpc("any_peer")
func register_player(nickname: String) -> void:
	if not multiplayer.is_server():
		return

	var id = multiplayer.get_remote_sender_id()

	player_names[id] = nickname

	if not connected_peer_ids.has(id):
		connected_peer_ids.append(id)

	add_player(id)

	rpc("sync_player_names", connected_peer_ids, player_names)
	emit_signal("players_updated")


@rpc("authority")
func sync_player_names(ids: Array, names: Dictionary) -> void:
	connected_peer_ids = ids
	player_names = names
	emit_signal("players_updated")


func _on_peer_connected(id: int) -> void:
	if not connected_peer_ids.has(id):
		connected_peer_ids.append(id)


func _on_peer_disconnected(id: int) -> void:
	if connected_peer_ids.has(id):
		connected_peer_ids.erase(id)

	player_names.erase(id)
	del_player(id)

	if multiplayer.is_server():
		rpc("sync_player_names", connected_peer_ids, player_names)

	emit_signal("players_updated")


func spawn_players_in_new_scene() -> void:
	if not multiplayer.is_server():
		return

	for id in connected_peer_ids:
		add_player(id)


func add_player(id: int) -> void:
	if not multiplayer.is_server():
		return

	var container = get_node(spawner.spawn_path)
	if container.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)

	container.add_child(player, true)


func del_player(id: int) -> void:
	if not multiplayer.is_server():
		return

	var container = get_node(spawner.spawn_path)
	var player_node = container.get_node_or_null(str(id))

	if player_node:
		player_node.queue_free()

func _on_server_disconnected() -> void:
	print("Lost connection to the host")
	go_to_main_menu()

func go_to_main_menu() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	connected_peer_ids.clear()
	player_names.clear()

	get_tree().change_scene_to_file("res://ui/menus/main_menu/main_menu.tscn")
