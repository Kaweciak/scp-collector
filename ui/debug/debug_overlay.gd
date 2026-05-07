extends CanvasLayer

@onready var debug_label: Label = $MarginContainer/VBoxContainer/DebugLabel

#Debug mode variable
static var debug_mode_enabled: bool = false

func _process(_delta: float) -> void:
	#Only calculate and update the text if the debug mode has been enabled
	if debug_mode_enabled:
		_update_debug_text()

func _toggle_debug_mode(state: bool) -> void:
	if is_multiplayer_authority():
		debug_mode_enabled = state
		visible = state

#Displays important game state information
func _update_debug_text() -> void:
	var text: String = "GAME STATE\n"
	text += "Game in Progress: %s\n" % GameState.is_game_in_progress
	text += "Total Time Elapsed: %.2f s\n" % GameState.total_time_elapsed
	text += "Current Game Time: %.2f s\n" % GameState.current_game_time_elapsed
	
	text += "\nSANITY VARIABLES\n"
	text += "Toaster Present: %s\n" % GameState.toaster_present
	text += "Sanity Drain Active: %s\n" % GameState.sanity_drain_first_activated
	text += "Sanity Regen Rate: %.2f\n" % GameState.sanity_regeneration_rate
	
	#Dynamically locate the Toaster to read its properties
	if GameState.toaster_present:
		var toaster_instance: Toaster = null
		var anomalies = get_tree().get_nodes_in_group("Anomaly")
		
		for anomaly in anomalies:
			if anomaly is Toaster:
				toaster_instance = anomaly
				break
				
		#Display the values if a valid instance was found
		if is_instance_valid(toaster_instance):
			text += "Toaster Checkpoint: %d\n" % toaster_instance.sanity_checkpoint
			text += "Vision Drain Rate: %.2f\n" % toaster_instance.vision_sanity_drain_rate
			text += "Touch Drain Rate: %.2f\n" % toaster_instance.touch_sanity_drain_rate
			text += "Prox. Drain Rate: %.2f\n" % toaster_instance.proximity_sanity_drain_rate
			text += "Prox. Drain Radius: %.2f\n" % toaster_instance.proximity_sanity_drain_radius
	
	text += "\nPORTAL VARIABLES\n"
	text += "Anomaly Active: %s\n" % PortalManager.is_active
	text += "Portal Checkpoint: %d\n" % PortalManager.portal_checkpoint
	
	#Using arrays for multiple format specifiers on a single line
	text += "Next Portal In: %.2f / %.2f\n" % [PortalManager.time_since_last_portal_creation, PortalManager.portal_creation_cooldown]
	text += "Next Room In: %.2f / %.2f\n" % [PortalManager.time_since_last_room_creation, PortalManager.room_creation_cooldown]
	text += "Next Item In: %.2f / %.2f\n" % [PortalManager.time_since_last_item_duplication, PortalManager.item_duplication_cooldown]
	
	debug_label.text = text
