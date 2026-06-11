class_name Toaster extends TeleportableItem

#Current properties for sanity mechanics
@export var vision_sanity_drain_rate: float = 2.0
@export var touch_sanity_drain_rate: float = 1.0
@export var proximity_sanity_drain_rate: float = 0.0
@export var proximity_sanity_drain_radius: float = 1.0
@export var sanity_regeneration_rate: float = 0.5

#Checkppoints are used to define which properties change at what rate
@export var sanity_checkpoint: int = 0
@export var checkpoints: Array[SanityResourceCheckpoint] = []

func _ready() -> void:
	#Only the server should process physics for this object
	set_multiplayer_authority(1)
	
	#Backup call for when checkpoints arent' initialized
	if checkpoints.is_empty():
		printerr("Sanity checkpoints cannot be empty!")
	else:
		_apply_static_checkpoint_values(0)

	if multiplayer.is_server():
		GameState.request_toaster_activation(sanity_regeneration_rate)

#Adds itself to the maintained anomaly list
func _enter_tree() -> void:
	GameState.register_anomaly(self)

#Removes itself from the maintained anomaly list
func _exit_tree() -> void:
	GameState.unregister_anomaly(self)


func _process(_delta: float) -> void:
	#Adjust sanity drain effect based on the time since first encountered
	if multiplayer.is_server() and GameState.sanity_drain_first_activated:
		if checkpoints.size() - 1 > sanity_checkpoint:
			#Increment the checkpoint if enough time passed
			if GameState.time_since_sanity_drain_first_activated >= checkpoints[sanity_checkpoint+1].time_to_increment_sanity_checkpoint:
				sanity_checkpoint += 1
			#Update the intensity of the sanity drain
			set_interpolated_sanity_values()

			#Inform the game that the regeneration value changed
			GameState.update_toaster_rate.rpc(sanity_regeneration_rate)

#Sets the values based on the set checkpoint values for the Toaster sanity drain process
func set_interpolated_sanity_values() -> void:
	if checkpoints.is_empty():
		return
	
	#Do not increase values if the last checkpoint was reached
	if sanity_checkpoint >= checkpoints.size() - 1:
		var last_index = checkpoints.size() - 1
		_apply_static_checkpoint_values(last_index)
		return

	#Calculate interpolation weight
	var start_point = checkpoints[sanity_checkpoint]
	var end_point = checkpoints[sanity_checkpoint + 1]
	var start_time = checkpoints[sanity_checkpoint].time_to_increment_sanity_checkpoint if sanity_checkpoint > 0 else 0.0
	var end_time = checkpoints[sanity_checkpoint+1].time_to_increment_sanity_checkpoint
	var segment_duration = end_time - start_time
	var elapsed_in_segment = GameState.time_since_sanity_drain_first_activated - start_time
	var t = 0.0
	if segment_duration > 0.0:
		t = clamp(elapsed_in_segment / segment_duration, 0.0, 1.0)

	#Set the interpolated values
	var vision_rate = lerp(start_point.vision_sanity_drain_rate, end_point.vision_sanity_drain_rate, t)
	var touch_rate = lerp(start_point.touch_sanity_drain_rate, end_point.touch_sanity_drain_rate, t)
	var proximity_rate = lerp(start_point.proximity_sanity_drain_rate, end_point.proximity_sanity_drain_rate, t)
	var proximity_radius = lerp(start_point.proximity_sanity_drain_radius, end_point.proximity_sanity_drain_radius, t)
	var regeneration_rate = lerp(start_point.sanity_regeneration_rate, end_point.sanity_regeneration_rate, t)
	
	#Sync toaster values across all players
	rpc("sync_toaster_values", sanity_checkpoint, vision_rate, touch_rate, proximity_rate, proximity_radius, regeneration_rate)
	GameState.update_toaster_rate.rpc(sanity_regeneration_rate)

#Backup function for setting checkpoint values when sanity checkpoints aren't set
func _apply_static_checkpoint_values(idx: int) -> void:
	var cp = checkpoints[idx]
	rpc("sync_toaster_values", idx, cp.vision_sanity_drain_rate, cp.touch_sanity_drain_rate, cp.proximity_sanity_drain_rate, cp.proximity_sanity_drain_radius, cp.sanity_regeneration_rate)
	if multiplayer.is_server():
		GameState.update_toaster_rate.rpc(sanity_regeneration_rate)

#Synchronizes sanity metrics across players
@rpc("any_peer", "call_local", "unreliable")
func sync_toaster_values(p_checkpoint: int, v_rate: float, t_rate: float, p_rate: float, p_radius: float, r_rate: float) -> void:
	sanity_checkpoint = p_checkpoint
	vision_sanity_drain_rate = v_rate
	touch_sanity_drain_rate = t_rate
	proximity_sanity_drain_rate = p_rate
	proximity_sanity_drain_radius = p_radius
	sanity_regeneration_rate = r_rate
