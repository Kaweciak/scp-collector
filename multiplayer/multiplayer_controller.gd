extends Node

var peer = ENetMultiplayerPeer.new()
var player_scene: PackedScene = preload("res://player/player_body_3d.tscn")

#Stores connected players
var connected_peer_ids: Array[int] = []

var spawner: MultiplayerSpawner = MultiplayerSpawner.new()

func _ready() -> void:
	add_child(spawner)
	spawner.add_spawnable_scene("res://player/player_body_3d.tscn")

	var args = OS.get_cmdline_args()
	#if "--host" in args:
		#_host()
	#elif "--join" in args:
		#_join()

func _host() -> void:
	peer.create_server(2137)
	multiplayer.multiplayer_peer = peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not connected_peer_ids.has(1):
		connected_peer_ids.append(1)

func _on_peer_connected(id: int) -> void:
	if not connected_peer_ids.has(id):
		connected_peer_ids.append(id)
	add_player(id)

func _on_peer_disconnected(id: int) -> void:
	if connected_peer_ids.has(id):
		connected_peer_ids.erase(id)

	del_player(id)

func spawn_players_in_new_scene() -> void:
	if not multiplayer.is_server():
		return

	for id in connected_peer_ids:
		add_player(id)


func _join(ip_address: String = "127.0.0.1") -> void:
	var result = peer.create_client(ip_address, 2137)
	if result == OK:
		multiplayer.multiplayer_peer = peer


func add_player(id: int) -> void:
	if not multiplayer.is_server():
		return

	var container = get_node(spawner.spawn_path)
	if container.has_node(str(id)):
		return

	var player: PlayerBody3D = player_scene.instantiate()
	player.name = str(id)
	container.add_child(player, true)

func del_player(id) -> void:
	if not multiplayer.is_server():
		return

	var container = get_node(spawner.spawn_path)
	var player_node = container.get_node_or_null(str(id))

	if player_node:
		player_node.queue_free()
