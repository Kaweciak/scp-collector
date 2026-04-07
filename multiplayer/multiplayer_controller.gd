extends Node

var peer = ENetMultiplayerPeer.new()
var player_scene: PackedScene = preload("res://player/player_body_3d.tscn")


func _ready() -> void:
	var args = OS.get_cmdline_args()
	if "--host" in args:
		_host()
	elif "--join" in args:
		_join()

func _host() -> void:
	peer.create_server(2137)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	add_player()


func _join() -> void:
	peer.create_client("127.0.0.1",2137)
	multiplayer.multiplayer_peer = peer


func add_player(id = 1) -> void:
	var player: PlayerBody3D = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)


func exit_game(id) -> void:
	multiplayer.peer_disconnected.connect(del_player)
	del_player(id)

func del_player(id) -> void:
	rpc("_del_player", id)

@rpc("any_peer","call_local")
func _del_player(id):
	get_node(str(id)).queue_free()
