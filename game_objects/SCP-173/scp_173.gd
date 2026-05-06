class_name SCP_173 extends CharacterBody3D

#Movement variables
@export var move_speed: float = 20.0
@export var kill_distance: float = 1.8
@export var teleport_interval: float = 0.05
@export var fov_dot_threshold: float = 0.5

var time_since_last_move: float = 0.0

#State Machine variables
var active_target: PlayerBody3D = null
var wander_target: Vector3 = Vector3.ZERO
var is_wandering: bool = false

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	#Only the server runs the pathfinding and visibility logic
	set_physics_process(multiplayer.is_server())
	
	#Ensure random seeds for the wandering vectors
	randomize()


func _physics_process(delta: float) -> void:
	#Wait for the map to sync on game start
	if NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
		return
	
	#Get all alive players 
	var players = get_tree().get_nodes_in_group("Player")
	var valid_players = players.filter(func(p): return not p.dead)
	if valid_players.is_empty():
		return
		
	#Gather which specific players are currently looking at the anomaly
	var observing_players = _get_observing_players(valid_players)
	var is_observed = not observing_players.is_empty()
	
	#Determine target aggro or de-aggro based on vision checks
	_update_target_state(valid_players, observing_players)
	
	#Freeze if any player is looking at the entity
	if is_observed:
		return
		
	#Process states, idle or hunting
	if active_target:
		_attempt_kill(active_target)
		_teleport_towards_position(active_target.global_position, delta)
	else:
		_handle_wandering(delta)

#Updates the active target based on aggro/de-aggro rules
func _update_target_state(valid_players: Array, observing_players: Array) -> void:
	var potential_targets = []
	
	#Get all players which are looking at the entity or are being looked at
	for player in valid_players:
		if player in observing_players or _sees_player(player):
			potential_targets.append(player)
	
	#Choose the closest player a target
	if not potential_targets.is_empty():
		active_target = _closest_from_list(potential_targets)
		is_wandering = false
		return
		
	#If currently hunting, check if vision is completely broken
	if active_target:
		var player_sees_scp = active_target in observing_players
		var scp_sees_player = _has_line_of_sight(active_target)
		#De-aggro if lost the player
		if not player_sees_scp and not scp_sees_player:
			active_target = null

#Processes wandering logic when idle
func _handle_wandering(delta: float) -> void:
	if not is_wandering or global_position.distance_to(wander_target) < 1.0:
		_generate_new_wander_target()
		
	_teleport_towards_position(wander_target, delta)

#Calculates a random, reachable point nearby
func _generate_new_wander_target() -> void:
	#Pick a random direction and distance
	var random_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	var random_dist = randf_range(3.0, 8.0)
	var desired_pos = global_position + (random_dir * random_dist)
	
	#Raycast to ensure a point outside a wall is not picked
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), desired_pos + Vector3(0, 1, 0))
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	var safe_pos = desired_pos
	if not result.is_empty():
		safe_pos = result.position
		
	#Snap to the closest valid navigation mesh coordinate
	var map = nav_agent.get_navigation_map()
	wander_target = NavigationServer3D.map_get_closest_point(map, safe_pos)
	is_wandering = true

#Returns an array of players who see the entity on their screen
func _get_observing_players(players: Array) -> Array:
	var observers = []
	var space_state = get_world_3d().direct_space_state
	
	#Get the corners of the model
	var points_container = get_node_or_null("VisibilityPoints")
	if not points_container:
		printerr("No visbility points set for the SCP-173!")
		return observers
	var points_to_check = points_container.get_children()
	
	for player in players:
		#If the player's eyes are closed, they cannot observe the entity
		if player.current_eyes_state == player.Eyes_state.CLOSED:
			continue
		
		var player_can_see = false
		
		#Cast a ray for each marker
		for marker in points_to_check:
			var pt = marker.global_position
			#Check if the entity is within the camera's viewing frustum
			if player.camera.is_position_in_frustum(pt):
				#Raycast to ensure no walls are in the way
				var query = PhysicsRayQueryParameters3D.create(player.camera.global_position, pt)
				#Exclude the entity itself and the player to prevent self-intersections
				query.exclude = [self, player] 
				var result = space_state.intersect_ray(query)
				
				#Break if the ray didn't hit anything, meaning the player can see it
				if result.is_empty():
					player_can_see = true
					break
			
		#Add the player to the total list of observers if they see the entity
		if player_can_see:
			observers.append(player)
	
	return observers

#Checks if the entity is looking at a specific player
func _sees_player(player: PlayerBody3D) -> bool:
	#Get which direction the entity is looking as well as the direction to the player
	var dir_to_player = global_position.direction_to(player.global_position)
	var forward = -global_transform.basis.z 
	
	#Check if the entity is looking at a specific player using a dot product simulated frustum
	if forward.dot(dir_to_player) > fov_dot_threshold:
		#Cast a ray towards the player to check if they aren't behind a wall
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0))
		query.exclude = [self, player]
		var result = space_state.intersect_ray(query)
		
		return result.is_empty()
	
	return false
	
#Checks if there is a clear physical path to the player
func _has_line_of_sight(player: PlayerBody3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0))
	query.exclude = [self, player]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty()

#Gets the closest player from a list
func _closest_from_list(target_list: Array) -> PlayerBody3D:
	var nearest = null
	var min_dist = INF
	for p in target_list:
		var dist = global_position.distance_squared_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = p
	return nearest

#Teleports instead of moving to avoid being spotted movign due to lag
func _teleport_towards_position(target_pos: Vector3, delta: float) -> void:
	nav_agent.target_position = target_pos
	
	#Skips movement if navigation in progress
	if nav_agent.is_navigation_finished():
		return
	
	#Wait between each teleport to limit movement speed
	time_since_last_move += delta
	if time_since_last_move >= teleport_interval:
		time_since_last_move = 0.0
		
		#Get the next node in the path
		var next_path_pos = nav_agent.get_next_path_position()
		
		#Calculate the distance it can travel in this interval
		var distance_to_move = move_speed * teleport_interval
		
		#Teleport the anomaly forward along the path
		global_position = global_position.move_toward(next_path_pos, distance_to_move)
		
		#Adjust the y rotation
		var flat_target = target_pos
		flat_target.y = global_position.y
		
		#Rotate to face the player so it aligns for the kill check
		look_at(flat_target, Vector3.UP, true)
		
		#Variables used to find where the floor is
		var space_state = get_world_3d().direct_space_state
		var ray_start = Vector3(global_position.x, global_position.y + 1.0, global_position.z)
		var ray_end = Vector3(global_position.x, global_position.y - 10.0, global_position.z)
		
		#Cast a ray to find the y position of the floor
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [self]
		#Snap to the correct y value
		var result = space_state.intersect_ray(query)
		if result:
			global_position.y = result.position.y

#Attempt to kill the player if they are behind and facing them
func _attempt_kill(target: PlayerBody3D) -> void:
	if global_position.distance_to(target.global_position) <= kill_distance:
		
		#Determine the direction from the player's camera to the anomaly
		var dir_to_scp = (global_position - target.camera.global_position).normalized()
		
		#Check if the entity is beghind the player
		var is_behind = target.camera.global_transform.basis.z.dot(dir_to_scp) > 0.0
		
		#Call the player feath function
		if is_behind:
			target.death.rpc()
