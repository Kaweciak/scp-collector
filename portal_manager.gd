extends Node

#Current properties for reality warping mechanics
@export var is_active: bool = false
@export var time_since_last_portal_creation: float = 0.0
@export var portal_creation_cooldown: float = 10.0
@export var time_since_last_room_creation: float = 0.0
@export var room_creation_cooldown: float = 1000.0
@export var time_since_last_item_duplication: float = 0.0
@export var item_duplication_cooldown: float = 1000.0

#Checkpoint storing variables used to modify the portal effect intensity
@export var portal_checkpoint: int = -1
@export var checkpoints: Array[PortalResourceCheckpoint] = []

#Used to reset all the variables to the initial state
func _reset_portal_state():
	portal_checkpoint = -1
	is_active = false
	
	time_since_last_portal_creation = 0.0
	time_since_last_room_creation = 0.0
	time_since_last_item_duplication = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	if checkpoints.is_empty():
		printerr("Portal checkpoints cannot be empty!")


func _process(delta: float) -> void:
	if not is_active or not multiplayer.is_server():
		return
	
	#Update the current checkpoint value
	var elapsed = GameState.current_game_time_elapsed
	if checkpoints.size() - 1 > portal_checkpoint:
		if elapsed >= checkpoints[portal_checkpoint+1].time_to_increment_portal_checkpoint:
			portal_checkpoint += 1
			
		#Update the intensity of the anomalous effect
		set_interpolated_portal_values(elapsed)
	
	#Control the portal anomalous effect
	time_since_last_portal_creation += delta
	if time_since_last_portal_creation >= portal_creation_cooldown:
		time_since_last_portal_creation = 0.0
		_trigger_portal_anomaly()
		
	#Control the duplication anomalous effect
	time_since_last_item_duplication += delta
	if time_since_last_item_duplication >= item_duplication_cooldown:
		time_since_last_item_duplication = 0.0
		_trigger_item_anomaly()
		
	#Control the room creation anomalous effect
	time_since_last_room_creation += delta
	if time_since_last_room_creation >= room_creation_cooldown:
		time_since_last_room_creation = 0.0
		_trigger_room_anomaly()

#Called from by SCP-184 on initialization
func activate_anomaly() -> void:
	if not is_active:
		is_active = true
		
		print("Portal anomaly activated!")

func set_interpolated_portal_values(elapsed: float) -> void:
	#Check if the checkpoints are correctly formatted
	if portal_checkpoint < 0 or checkpoints.is_empty():
		portal_checkpoint += 1
		return
	elif checkpoints.size() - 1 <= portal_checkpoint:
		portal_creation_cooldown = checkpoints[checkpoints.size() - 1].portal_creation_cooldown
		room_creation_cooldown = checkpoints[checkpoints.size() - 1].room_creation_cooldown
		item_duplication_cooldown = checkpoints[checkpoints.size() - 1].item_duplication_cooldown
		return
	
	#Calculate interpolation weight
	var start_point = checkpoints[portal_checkpoint]
	var end_point = checkpoints[portal_checkpoint+1]
	var segment_duration = end_point.time_to_increment_portal_checkpoint - start_point.time_to_increment_portal_checkpoint
	var elapsed_in_segment = elapsed - start_point.time_to_increment_portal_checkpoint
	var t = elapsed_in_segment / segment_duration
	
	#Set the interpolated values
	portal_creation_cooldown = lerp(start_point.portal_creation_cooldown, end_point.portal_creation_cooldown, t)
	room_creation_cooldown = lerp(start_point.room_creation_cooldown, end_point.room_creation_cooldown, t)
	item_duplication_cooldown = lerp(start_point.item_duplication_cooldown, end_point.item_duplication_cooldown, t)
	
#Finds a pair of portals to connect
func _trigger_portal_anomaly() -> void:
	var all_portals = get_tree().get_nodes_in_group("Portals")
	
	if all_portals.size() >= 2:
		all_portals.shuffle()
		var portal_a = all_portals[0]
		
		var portal_b = null
		for i in range(1, all_portals.size()):
			var candidate = all_portals[i]
			if portal_a != candidate and portal_a.connected_front_portal != candidate and portal_a.connected_back_portal != candidate:
				portal_b = candidate
				break
				
		if portal_b != null:
			#Get available sides and pick one randomly for each door
			var portals_a = portal_a.get_portals()
			var portals_b = portal_b.get_portals()
			portals_a.shuffle()
			portals_b.shuffle()
			
			var side_portal_a = portals_a[0]
			var side_portal_b = portals_b[0]
		
			#Send an RPC to all clients to link the two portals
			sync_link_portals.rpc(side_portal_a.get_path(), side_portal_b.get_path())

#Links portals together for all players
@rpc("authority", "call_local", "reliable")
func sync_link_portals(path_a: NodePath, path_b: NodePath) -> void:
	var portal_a = get_node_or_null(path_a)
	var portal_b = get_node_or_null(path_b)
	
	if portal_a is Portal3D and portal_b is Portal3D:
		var door_a = portal_a.get_parent()
		var door_b = portal_b.get_parent()
		
		#Cleanup variables
		var doors_to_close = []
		var both_open = door_a.opened and door_b.opened
		
		#Identify any old portal links that need their doors closed
		if portal_a.exit_portal != null:
			var old_door_a = portal_a.exit_portal.get_parent()
			if old_door_a.opened:
				if not (both_open and (old_door_a == door_a or old_door_a == door_b)):
					doors_to_close.append(old_door_a)
		
		if portal_b.exit_portal != null:
			var old_door_b = portal_b.exit_portal.get_parent()
			if old_door_b.opened and not doors_to_close.has(old_door_b):
				if not (both_open and (old_door_b == door_a or old_door_b == door_b)):
					doors_to_close.append(old_door_b)
		
		#Check if the doors of the new portals need to be cleaned up
		if not both_open:
			if door_a.opened and not doors_to_close.has(door_a):
				doors_to_close.append(door_a)
			if door_b.opened and not doors_to_close.has(door_b):
				doors_to_close.append(door_b)
				
		#Close collected doors locally and wait for the animation to finish
		if doors_to_close.size() > 0:
			for door in doors_to_close:
				#Calling _close directly avoids duplicating RPC calls since we are inside one
				door._close(true)
				
			#Waits slightly longer than the 0.5s animation to ensure states settle
			await get_tree().create_timer(0.55).timeout
		
		#Clean up old portal links
		_unlink_portal(portal_a)
		_unlink_portal(portal_b)
		
		door_a.is_portal = true
		door_b.is_portal = true
		
		portal_a.exit_portal = portal_b
		portal_b.exit_portal = portal_a
		
		#Record the connections to prevent double-links
		if portal_a == door_a.front_portal:
			door_a.connected_front_portal = door_b
		else:
			door_a.connected_back_portal = door_b
		
		if portal_b == door_b.front_portal:
			door_b.connected_front_portal = door_a
		else:
			door_b.connected_back_portal = door_a
			
		#Update the physical blocking walls
		door_a.update_walls()
		door_b.update_walls()
		
		portal_a.activate()
		portal_b.activate()
		
		print("Portal link created!")
		
#Fixes broken portal links
func _unlink_portal(portal: Portal3D) -> void:
	#Check if this portal is currently acting as a portal and has a destination
	if portal.exit_portal != null:
		
		var partner_portal = portal.exit_portal
		var door = portal.get_parent()
		var partner_door = partner_portal.get_parent()
		
		#Disconnect exits
		portal.exit_portal = null
		partner_portal.exit_portal = null
		portal.deactivate(true)
		partner_portal.deactivate(true)
		
		#Clear tracked connections
		if door.front_portal == portal:
			door.connected_front_portal = null
		else:
			door.connected_back_portal = null
		
		if partner_door.front_portal == partner_portal:
			partner_door.connected_front_portal = null
		else:
			partner_door.connected_back_portal = null
			
		#Update portal flags
		door.is_portal = (door.front_portal.exit_portal != null or door.back_portal.exit_portal != null)
		partner_door.is_portal = (partner_door.front_portal.exit_portal != null or partner_door.back_portal.exit_portal != null)
		
		#Update the physical blocking walls
		door.update_walls()
		partner_door.update_walls()


func _trigger_item_anomaly() -> void:
	return


func _trigger_room_anomaly() -> void:
	return

#Sync newly joined players
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		#Sync the timers and active state
		sync_portal_state.rpc_id(id, is_active, time_since_last_portal_creation, time_since_last_room_creation, time_since_last_item_duplication, portal_checkpoint)
		
		#Tell the new player about all currently active portal pairs
		var all_portals = get_tree().get_nodes_in_group("Portals")
		for portal in all_portals:
			if portal.is_portal:
				if portal.front_portal.exit_portal != null:
					var partner = portal.front_portal.exit_portal
					if str(portal.front_portal.get_path()) > str(partner.get_path()):
						sync_link_portals.rpc_id(id, portal.front_portal.get_path(), partner.get_path())
						
				if portal.back_portal.exit_portal != null:
					var partner = portal.back_portal.exit_portal
					if str(portal.back_portal.get_path()) > str(partner.get_path()):
						sync_link_portals.rpc_id(id, portal.back_portal.get_path(), partner.get_path())

#Sync the data to the new client
@rpc("authority", "call_local", "reliable")
func sync_portal_state(active: bool, t_portal: float, t_room: float, t_item: float, checkpoint: int) -> void:
	is_active = active
	time_since_last_portal_creation = t_portal
	time_since_last_room_creation = t_room
	time_since_last_item_duplication = t_item
	portal_checkpoint = checkpoint
