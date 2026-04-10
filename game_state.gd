extends Node

#Global game variables
var sanity_drain_first_activated: bool = false
var time_since_sanity_drain_first_activated: float = 0.0
var total_time_elapsed: float = 0.0


func _process(delta: float) -> void:
	#Process global timers
	if multiplayer.is_server():
		total_time_elapsed += delta
		if sanity_drain_first_activated:
			time_since_sanity_drain_first_activated += delta

#Allows the server to set the global sanity mechanic state
@rpc("authority", "call_local", "reliable")
func sync_sanity_state(is_active: bool, current_timer: float = 0.0) -> void:
	sanity_drain_first_activated = is_active
	time_since_sanity_drain_first_activated = current_timer

#Allows the server to set the global timer
@rpc("authority", "call_local", "reliable")
func sync_global_timer(current_timer: float = 0.0) -> void:
	total_time_elapsed = current_timer

##Allows any peer to request the server to update the sanity state
@rpc("any_peer", "call_local", "reliable")
func request_sanity_activation() -> void:
	if multiplayer.is_server() and not sanity_drain_first_activated:
		sync_sanity_state.rpc(true, 0.0)

#Connect the signal for updating joining peers about the state of the game
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

#Sync newly joined players
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		sync_sanity_state.rpc_id(id, sanity_drain_first_activated, time_since_sanity_drain_first_activated)
		sync_global_timer.rpc_id(id, total_time_elapsed)
