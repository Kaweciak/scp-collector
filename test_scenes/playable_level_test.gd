extends Node3D


func _ready() -> void:
	#Spawn players
	MultiplayerController.spawner.spawn_path = $PlayerContainer.get_path()
	MultiplayerController.spawn_players_in_new_scene()
	
	#Attach check for the win condition
	$NavigationRegion3D/Van/AnomalyDetactionArea3D.body_entered.connect(_on_van_area_body_entered)


func _process(_delta: float) -> void:
	#Check if game over has been triggered
	if multiplayer.is_server():
		_check_game_over()

#Reload the level if the Anomaly has been captured
func _on_van_area_body_entered(body: Node3D) -> void:
	if multiplayer.is_server():
		if body.is_in_group("Anomaly"):
			sync_reload.rpc()

#Multiplayer synchronized call for reloading the level
@rpc("authority", "call_local", "reliable")
func sync_reload() -> void:
	#Reset all variables to a starting state
	GameState.reset_game_state.rpc()
		
	#Reload the scene
	get_tree().reload_current_scene()

#Check game over conditions
func _check_game_over() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	
	#Do nothing if the players haven't spawned
	if players.size() == 0:
		return
	
	#Check if all players are dead
	var all_dead = true
	for player in players:
		if !player.dead:
			all_dead = false
			break
	
	#Reload the level if all players died
	if all_dead:
		sync_reload.rpc()
