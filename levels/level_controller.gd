extends Node3D

var alive_players: Array = []

func _ready() -> void:
	MultiplayerController.spawner.spawn_path = $PlayerContainer.get_path()
	MultiplayerController.spawn_players_in_new_scene()

	$Van/AnomalyDetactionArea3D.body_entered.connect(_on_van_area_body_entered)

	await get_tree().process_frame

	for player in $PlayerContainer.get_children():
		register_player(player)

func register_player(player: Node) -> void:
	alive_players.append(player)

	player.died.connect(_on_player_died.bind(player))

func _on_player_died(player: Node) -> void:
	if not multiplayer.is_server():
		return

	alive_players.erase(player)

	print("Players alive: ", alive_players.size())

	if alive_players.is_empty():
		go_to_lobby.rpc()

func _on_van_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Anomaly"):
		if multiplayer.is_server():
			go_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func go_to_lobby() -> void:
	get_tree().change_scene_to_file("res://levels/lobby/lobby.tscn")
