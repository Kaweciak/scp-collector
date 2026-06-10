extends Node

#Sanity variables
var toaster_present = false
var sanity_drain_first_activated: bool = false
var time_since_sanity_drain_first_activated: float = 0.0
var sanity_regeneration_rate: float = 0.5

#Miscelleanous variables
var is_game_in_progress = false
var total_time_elapsed: float = 0.0
var current_game_time_elapsed: float = 0.0

var lobby_message: String = ""

#Preloaded arrays with important objects to save computation time
var alive_players: Array[Node] = []
var active_portals: Array[Node] = []
var active_anomalies: Array[Node] = []

#Debug variable
var global_cheats_enabled: bool = true

func _process(delta: float) -> void:
	#Check if the peer is null before querying the server status
	if multiplayer.multiplayer_peer == null:
		return
	
	#Process global timers
	if multiplayer.is_server():
		total_time_elapsed += delta

		if is_game_in_progress:
			current_game_time_elapsed += delta

		if sanity_drain_first_activated:
			time_since_sanity_drain_first_activated += delta

#Used to reset all variables to the initial state
@rpc("authority", "call_local", "reliable")
func reset_game_state() -> void:
	PortalManager._reset_portal_state()
	
	current_game_time_elapsed = 0.0
	is_game_in_progress = false
	
	sanity_drain_first_activated = false
	sanity_regeneration_rate = 0.5
	time_since_sanity_drain_first_activated = 0.0

#Allows the server to set the global sanity mechanic state
@rpc("authority", "call_local", "reliable")
func sync_sanity_state(is_active: bool, current_timer: float = 0.0) -> void:
	sanity_drain_first_activated = is_active
	time_since_sanity_drain_first_activated = current_timer

#Allows the server to set the global timer
@rpc("authority", "call_local", "reliable")
func sync_global_timers(current_timer: float = 0.0, current_game_timer: float = 0.0) -> void:
	total_time_elapsed = current_timer
	current_game_time_elapsed = current_game_timer

#Allows any peer to request the server to update the sanity state
@rpc("any_peer", "call_local", "reliable")
func request_sanity_activation() -> void:
	if multiplayer.is_server() and not sanity_drain_first_activated:
		sync_sanity_state.rpc(true, 0.0)

#Allows the server to set the global toaster state
@rpc("authority", "call_local", "reliable")
func sync_toaster_state(is_present: bool, new_regen_rate: float) -> void:
	toaster_present = is_present
	sanity_regeneration_rate = new_regen_rate

#Allows the server to activate the toaster
@rpc("any_peer", "call_local", "reliable")
func request_toaster_activation(new_rate: float) -> void:
	if multiplayer.is_server() and not toaster_present:
		sync_toaster_state.rpc(true, new_rate)

#Sync the current toaster regeneration rate
@rpc("authority", "call_local", "unreliable")
func update_toaster_rate(new_rate: float) -> void:
	sanity_regeneration_rate = new_rate
	
@rpc("authority", "call_remote", "reliable")
func sync_game_progress(in_progress: bool) -> void:
	is_game_in_progress = in_progress

#Connect the signal for updating joining peers about the state of the game
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

#Sync newly joined players
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		sync_toaster_state.rpc_id(id, toaster_present, sanity_regeneration_rate)
		sync_sanity_state.rpc_id(id, sanity_drain_first_activated, time_since_sanity_drain_first_activated)
		sync_global_timers.rpc_id(id, total_time_elapsed, current_game_time_elapsed)
		sync_game_progress.rpc_id(id, is_game_in_progress)
		sync_cheats_state.rpc_id(id, global_cheats_enabled)
		
#Allows the host/server to enable or disable cheats during runtime
@rpc("authority", "call_local", "reliable")
func sync_cheats_state(is_enabled: bool) -> void:
	global_cheats_enabled = is_enabled

#Called by the server when the level is fully loaded and ready
@rpc("authority", "call_local", "reliable")
func start_game(cheats_allowed: bool) -> void:
	reset_game_state()
	
	is_game_in_progress = true
	global_cheats_enabled = cheats_allowed

#Handles the end game sequence
@rpc("authority", "call_local", "reliable")
func trigger_end_game(message: String) -> void:
	if not is_game_in_progress:
		return
		
	is_game_in_progress = false
	lobby_message = message
	
	_go_to_lobby.rpc(message)

#Changes the scene to the lobby when the game ends
@rpc("authority", "call_local", "reliable")
func _go_to_lobby(message: String) -> void:
	lobby_message = message
	get_tree().change_scene_to_file.call_deferred("res://levels/lobby/lobby.tscn")

#Registers a new portal that has entered the scene
func register_portal(portal: Node) -> void:
	if not active_portals.has(portal):
		active_portals.append(portal)

#Removes a portal that exited the scene
func unregister_portal(portal: Node) -> void:
	active_portals.erase(portal)

#Registers a new anomaly that has entered the scene
func register_anomaly(anomaly: Node) -> void:
	if not active_anomalies.has(anomaly):
		active_anomalies.append(anomaly)

#Removes an anomaly that exited the scene
func unregister_anomaly(anomaly: Node) -> void:
	if active_anomalies.has(anomaly):
		active_anomalies.erase(anomaly)
