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

func _process(delta: float) -> void:
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
	
	sanity_regeneration_rate = 0.5
	time_since_sanity_drain_first_activated = 0.0
	sanity_drain_first_activated = false
	toaster_present = false
	
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

#Connect the signal for updating joining peers about the state of the game
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

#Sync newly joined players
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		sync_toaster_state.rpc_id(id, toaster_present, sanity_regeneration_rate)
		sync_sanity_state.rpc_id(id, sanity_drain_first_activated, time_since_sanity_drain_first_activated)
		sync_global_timers.rpc_id(id, total_time_elapsed, current_game_time_elapsed)
