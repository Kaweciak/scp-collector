extends Node3D

var alive_players: Array = []

#Variables for anomaly spawning
@export var anomaly_scenes: Array[PackedScene] = []
@onready var anomaly_spawns: Array = $AnomalySpawns.get_children()
@onready var anomaly_container: Node3D = $AnomalyContainer
@onready var anomaly_spawner: MultiplayerSpawner = $AnomalySpawner

func _ready() -> void:
	MultiplayerController.spawner.spawn_path = $PlayerContainer.get_path()
	MultiplayerController.spawn_players_in_new_scene()

	$NavigationRegion3D/Van/AnomalyDetactionArea3D.body_entered.connect(_on_van_area_body_entered)

	#Listen for players added mid-round
	$PlayerContainer.child_entered_tree.connect(register_player)

	await get_tree().process_frame

	for player in $PlayerContainer.get_children():
		register_player(player)

	if multiplayer.is_server():
		_spawn_random_anomaly()


func register_player(player: Node) -> void:
	#Prevent errors if a non-player node is added to the container
	if not player.has_signal("died"):
		return

	#Prevent duplicate registration if caught by both the ready loop and signal
	if alive_players.has(player):
		return

	alive_players.append(player)
	player.died.connect(_on_player_died.bind(player))

	#Handle node removal dynamically to clean up array on disconnects
	player.tree_exiting.connect(_on_player_exited_tree.bind(player))

func _on_player_died(player: Node) -> void:
	if not multiplayer.is_server():
		return

	remove_player_and_check_win(player)

func _on_player_exited_tree(player: Node) -> void:
	if not multiplayer.is_server():
		return

	remove_player_and_check_win(player)

func remove_player_and_check_win(player: Node) -> void:
	if alive_players.has(player):
		alive_players.erase(player)

	print("Players alive: ", alive_players.size())

	if alive_players.is_empty():
		GameState.lobby_message = "All players died. You lost."
		go_to_lobby.rpc()

func _on_van_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Anomaly"):
		if multiplayer.is_server():
			GameState.lobby_message = "SCP has been safely retrieved. You won."
			go_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func go_to_lobby() -> void:
	get_tree().change_scene_to_file("res://levels/lobby/lobby.tscn")

#Spawns one of the available anomalies in one of the designated spots
#TODO has to be replace by a choosing mechanism in the level selector
func _spawn_random_anomaly() -> void:
	if anomaly_scenes.is_empty() or anomaly_spawns.is_empty():
		printerr("Missing anomaly scenes or spawn points in the level!")
		return

	#Register all possible anomalies to the spawner so clients can replicate them
	for scene in anomaly_scenes:
		anomaly_spawner.add_spawnable_scene(scene.resource_path)

	#Select a random anomaly and a random spawn point
	var selected_scene: PackedScene = anomaly_scenes.pick_random()
	var spawn_point: Marker3D = anomaly_spawns.pick_random()

	#Instantiate, position, and add to the network container
	var anomaly_instance = selected_scene.instantiate()
	anomaly_instance.global_position = spawn_point.global_position
	anomaly_container.add_child(anomaly_instance, true)
