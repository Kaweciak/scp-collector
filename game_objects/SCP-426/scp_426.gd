class_name Toaster extends TeleportableItem

#Current properties for sanity mechanics
@export var vision_sanity_drain_rate: float = 2.0
@export var touch_sanity_drain_rate: float = 1.0
@export var proximity_sanity_drain_rate: float = 0.0
@export var proximity_sanity_drain_radius: float = 1.0
@export var sanity_regeneration_rate: float = 0.5

#Checkppoints are used to define which properties change at what rate
@export var sanity_checkpoint: int = -1
@export var checkpoints: Array[SanityResourceCheckpoint] = []

func _ready() -> void:
	#Only the server should process physics for this object
	set_multiplayer_authority(1) 
	if not multiplayer.is_server():
		freeze = true
		
	if multiplayer.is_server():
		GameState.request_toaster_activation(sanity_regeneration_rate)
		
func _process(_delta: float) -> void:
	#Adjust sanity drain effect based on the time since first encountered
	if multiplayer.is_server() and GameState.sanity_drain_first_activated:
		if checkpoints.size() - 1 >= sanity_checkpoint:
			#Increment the checkpoint if enough time passed
			if GameState.time_since_sanity_drain_first_activated >= checkpoints[sanity_checkpoint+1].time_to_increment_sanity_checkpoint:
				sanity_checkpoint += 1
			#Update the intensity of the sanity drain	
			set_interpolated_sanity_values()
			
			#Inform the game that the regeneration value changed
			GameState.request_toaster_activation(sanity_regeneration_rate)

#Sets the values based on the set checkpoint values for the Toaster sanity drain process
func set_interpolated_sanity_values() -> void:
	#Check if the checkpoints are correctly formatted
	if sanity_checkpoint < 0 or checkpoints.is_empty():
		sanity_checkpoint += 1
		return
	elif checkpoints.size() - 1 <= sanity_checkpoint:
		vision_sanity_drain_rate = checkpoints[checkpoints.size() - 1].vision_sanity_drain_rate
		touch_sanity_drain_rate = checkpoints[checkpoints.size() - 1].touch_sanity_drain_rate
		proximity_sanity_drain_rate = checkpoints[checkpoints.size() - 1].proximity_sanity_drain_rate
		proximity_sanity_drain_radius = checkpoints[checkpoints.size() - 1].proximity_sanity_drain_radius
		sanity_regeneration_rate = checkpoints[checkpoints.size() - 1].sanity_regeneration_rate
		return
	
	#Calculate interpolation weight
	var start_point = checkpoints[sanity_checkpoint]
	var end_point = checkpoints[sanity_checkpoint+1]
	var segment_duration = start_point.time_to_increment_sanity_checkpoint - end_point.time_to_increment_sanity_checkpoint
	var elapsed_in_segment = GameState.time_since_sanity_drain_first_activated - start_point.time_to_increment_sanity_checkpoint
	var t = elapsed_in_segment / segment_duration
	
	#Set the interpolated values
	vision_sanity_drain_rate = lerp(start_point.vision_sanity_drain_rate, end_point.vision_sanity_drain_rate, t)
	touch_sanity_drain_rate = lerp(start_point.touch_sanity_drain_rate, end_point.touch_sanity_drain_rate, t)
	proximity_sanity_drain_rate = lerp(start_point.proximity_sanity_drain_rate, end_point.proximity_sanity_drain_rate, t)
	proximity_sanity_drain_radius = lerp(start_point.proximity_sanity_drain_radius, end_point.proximity_sanity_drain_radius, t)
	sanity_regeneration_rate = lerp(start_point.sanity_regeneration_rate, end_point.sanity_regeneration_rate, t)
	
