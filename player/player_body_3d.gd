class_name PlayerBody3D extends CharacterBody3D

#Movement export variables
@export_group("Movement")
@export_range(1, 35, 1) var speed: float = 10
@export_range(10, 400, 1) var acceleration: float = 100

@export_range(0.1, 3.0, 0.1) var jump_height: float = 1
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1

@export_range(1.1, 2.0, 0.05) var sprint_factor: float = 1.1
@export_range(0.1, 0.9, 0.05) var crouch_factor: float = 0.9

@export_range(0.01, 0.5, 0.01) var coyote_time: float = 0.2

#Variable giving the player time to jump after they start falling
var coyote_timer: float = 0.0

#Physic interaction variables
@export_group("Physics Interaction")
@export var push_force: float = 0.1
@export var player_mass: float = 80.0
@export var terminal_velocity: float = -30.0

#Movement variables
var sprinting: bool = false
var crouching: bool = false
var jumping: bool = false
var mouse_captured: bool = false
var was_on_floor: bool = true
var tried_uncroaching: bool = false

#Gravity strength variable
var gravity_factor: float = ProjectSettings.get_setting("physics/3d/default_gravity")

#Acceleration and velocity related variables
var move_dir: Vector2
var look_dir: Vector2

var walk_vel: Vector3
var grav_vel: Vector3
var jump_vel: Vector3

#Sanity variables
@export_group("Sanity")
@export var sanity: float = 100.0
var sanity_drain_active: bool = false

#Blinking variables
@export_group("Blinking")
@export var blink_limit: float = 20.0
@export var time_since_last_blink: float = 0.0
@export var blink_duration: float = 1.0 / 10.0
@export var eyes_open_duration: float = 1.0 / 15.0
@export var eyes_close_duration: float = 1.0 / 15.0
enum Eyes_state {OPEN, CLOSING, CLOSED, OPENING}
var current_eyes_state: Eyes_state = Eyes_state.OPEN

#Object held by the player
var held: RigidBody3D

#Flag for whether the player is dead
var dead: bool = false

#Debug mode variable
static var debug_mode_enabled: bool = false

#Current animation state variable
var current_anim_state: String = ""

#Spectator variables
var spectator_target: PlayerBody3D = null
var last_spectator_target: PlayerBody3D = null
var spectator_index: int = 0

#Admin variables
var admin_privelege: bool = false
var admin_sanity_enabled: bool = false
var admin_blinking_enabled: bool = false
var admin_noclip_enabled: bool = false
var admin_immortality_enabled: bool = false

#Flashlight variables
@export_group("Flashlight")
@export var flashlight_energy: float = 2.0
var is_flashlight_on: bool = false
@onready var flashlight: SpotLight3D = $MainCamera/Flashlight
var max_flashlight_clones: int = 3
var clone_flashlights: Array[SpotLight3D] = []

@onready var camera: Camera3D = $MainCamera
@onready var base_collision: CollisionShape3D = $BaseCollision
@onready var crouch_collision: CollisionShape3D = $CrouchCollision
@onready var interaction_raycast: RayCast3D = $MainCamera/InteractionRaycast

@onready var animation_player: AnimationPlayer = $ModelHolder/Model/AnimationPlayer
@onready var model: Node3D = $ModelHolder/Model

@onready var hud: CanvasLayer = $MainCamera/HUD
@onready var blink_timer: Timer = $BlinkTimer

@onready var pause_menu: Control = $MainCamera/PauseMenu

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

	if multiplayer.is_server():
		admin_privelege = true

func _ready() -> void:
	#Get the mouse to focus on the screen once the player spawn
	_capture_mouse()
	
	#Assign the authority to the camera
	camera.current = is_multiplayer_authority()
	
	
	#Setup the portal clone flashlight pool
	for i in range(max_flashlight_clones):
		var clone = SpotLight3D.new()
		clone.light_energy = flashlight_energy
		clone.spot_range = flashlight.spot_range
		clone.spot_angle = flashlight.spot_angle
		clone.light_projector = flashlight.light_projector
		
		get_tree().root.call_deferred("add_child", clone)
		clone.hide()
		clone_flashlights.append(clone)
	
	if is_multiplayer_authority():
		#If the instance owns the player make the model invisible so that the player doesn't see visual glitches
		camera.set_cull_mask_value(2, false)
		camera.set_cull_mask_value(19, false)
		
		#Aplly the invisibility mask to the children meshes as well
		var all_meshes = model.find_children("*", "MeshInstance3D", true, false)
		for m in all_meshes:
			m.set_layer_mask_value(1, false)
			m.set_layer_mask_value(2, true)
		
		#Inject the camera for all portals in the scene
		var all_portals = get_tree().get_nodes_in_group("Portals") 
		for portal in all_portals:
			if portal.back_portal is Portal3D:
				portal.back_portal.player_camera = camera
			if portal.front_portal is Portal3D:
				portal.front_portal.player_camera = camera


func _physics_process(delta: float) -> void:
	#If the player is attached to the current instance
	if is_multiplayer_authority():
		#process spectator logic if dead
		if dead:
			_update_spectator_camera()
			return
		
		#Calculate coyote timer for better feeling jump mechanics
		var on_floor: bool = is_on_floor()
		if on_floor:
			coyote_timer = coyote_time
		else:
			coyote_timer = max(coyote_timer - delta, 0.0)
		
		#Check if the player jumped
		if Input.is_action_just_pressed("jump"):
			jumping = true
		
		#Check for and process the player crouching
		if tried_uncroaching:
			_try_uncroach()
		
		#Process movement logic
		velocity = _walk(delta) + _gravity(delta) + _jump(delta)
		move_and_slide()
		
		#Apply force to RigidBody collision objects
		_push_objects(delta)
		
		#Process player animation
		_update_animation()
		
		#Process sanity drain for SCP-426
		_process_sanity(delta)
		
		#Process blinking mechanics
		_process_blinking(delta)

	#Process entity holding mechanics
	if is_multiplayer_authority() or multiplayer.is_server():
		if held != null:
			_update_held()
			
	
	if not dead:
		_update_portal_flashlight()

#Process unhandled input
func _unhandled_input(event: InputEvent) -> void:
	#Only the owner instance can process input for the player
	if not is_multiplayer_authority():
		return
		
	#Debug logic processing
	if event is InputEventKey:
		if event.is_action_pressed("debug_activate"):
			debug_mode_enabled = !debug_mode_enabled
			DebugOverlay._toggle_debug_mode(debug_mode_enabled)
		elif debug_mode_enabled:
			if event.is_action_pressed("debug_death"):
				death.rpc()
		
	#Process spectator inputs
	if dead:
		if event is InputEventKey:
			if event.is_action_pressed("interact"):
				_find_next_spectate_target()
		return
		
	#Process mouse inputs
	if event is InputEventMouseMotion:
		look_dir = event.relative * 0.001
		if mouse_captured: _rotate_camera()
		
	#Process player input
	if event is InputEventKey and not dead:
		if event.is_action_pressed("sprint"):
			if(!Input.is_action_pressed("crouch")):
				_sprint()
		elif event.is_action_released("sprint"):
			if sprinting:
				_unsprint()
		elif event.is_action_pressed("crouch"):
			_crouch()
			if sprinting:
				_unsprint()
		elif event.is_action_released("crouch"):
			_try_uncroach()
			if(Input.is_action_pressed("sprint")):
				_sprint()
				
		elif event.is_action_pressed("toggle_flashlight"):
			_toggle_flashlight.rpc(!is_flashlight_on)
				
		elif event.is_action_pressed("interact"):
			_interact()
		
		#Helper for releaseing mouse capture -> should be replaced by the game menu
		#TODO
		elif event.is_action_pressed("pause"):
			if !pause_menu.visible:
				_pause()
			else:
				_unpause()

func _push_objects(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
	
		if collider is RigidBody3D:
			#Get the direction of the collision
			var push_dir = -collision.get_normal()
			
			#Get contact point relative to the center of the object
			var contact_point = collision.get_position() - collider.global_position
			
			#Calculate velocity relative to the object
			var velocity_diff = velocity.dot(push_dir) - collider.linear_velocity.dot(push_dir)
			velocity_diff = max(0.0, velocity_diff)
			
			#Scale the force by mass
			var mass_ratio = min(1.0, player_mass / collider.mass)
			
			#Base push impulse calculation
			var impulse = push_dir * speed * push_force * mass_ratio
			
			#Weight logic for standing on objects
			if collision.get_normal().y > 0.5:
				var weight_impulse = Vector3.DOWN * gravity_factor * delta * mass_ratio
				impulse += weight_impulse
			
			#Apply the final impulse
			collider.apply_impulse(impulse, contact_point)

func _pause() -> void:
	pause_menu.visible = true
	_release_mouse()
	pause_menu.set_process_unhandled_input(true)

func _unpause() -> void:
	pause_menu.visible = false
	_capture_mouse()
	pause_menu.set_process_unhandled_input(false)

func _crouch() -> void:
	tried_uncroaching = false
	crouching = true
	base_collision.disabled = true
	crouch_collision.disabled = false
	crouch_collision.visible = true
	base_collision.visible = false
	camera.position.y = 0.2


#Checks if the player has space above in order to uncrouch
func _can_uncrouch() -> bool:
	var space_state = get_world_3d().direct_space_state

	var shape_rid = base_collision.shape.get_rid()
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape_rid = shape_rid
	params.transform = global_transform
	params.transform.origin.y += 0.05
	params.exclude = [self]

	var result = space_state.intersect_shape(params, 1)

	return result.size() == 0

#Process the player trying to uncroach
func _try_uncroach() -> void:
	if _can_uncrouch():
		_uncrouch()
	else:
		tried_uncroaching = true

#Uncrouch mechanic processing -> should be adjusted to play an animation
#TODO
func _uncrouch() -> void:
	crouching = false
	base_collision.disabled = false
	crouch_collision.disabled = true
	base_collision.visible = true
	crouch_collision.visible = false
	camera.position.y = 0.7

#Process sprinting mechanics
func _sprint() -> void:
	sprinting = true
func _unsprint() -> void:
	sprinting = false

#Process mouse capture requests
func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

#Process the player changing mouse position in order to move the camera
func _rotate_camera(sens_mod: float = 1.0) -> void:
	rotation.y -= look_dir.x * camera_sens * sens_mod
	camera.rotation.x = clamp(camera.rotation.x - look_dir.y * camera_sens * sens_mod, -1.5, 1.5)

#Process the camera after player death
func _update_spectator_camera() -> void:
	if spectator_target == null:
		return
	
	if is_instance_valid(spectator_target):
		#Adjust spectator players' visibility
		if spectator_target != last_spectator_target:
			if is_instance_valid(last_spectator_target):
				last_spectator_target.model.show()
			last_spectator_target = spectator_target
			spectator_target.model.hide()
		
		camera.global_position = spectator_target.camera.global_position
		camera.global_rotation = spectator_target.camera.global_rotation

#Process walking mechanics
func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector(&"left", &"right", &"forwards", &"backwards")
	var _forward: Vector3 = camera.global_transform.basis * Vector3(move_dir.x, 0, move_dir.y)
	var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized() * (sprint_factor if sprinting else 1.0) * (crouch_factor if crouching else 1.0)
	walk_vel = walk_vel.move_toward(walk_dir * speed * move_dir.length(), acceleration * delta)
	return walk_vel

#Process gravity based on player position in world space
func _gravity(delta: float) -> Vector3:
	var grounded: bool = is_on_floor()
	
	if grounded: #Apply a small grounding force
		grav_vel = Vector3.ZERO
	else: #Apply gravity and clamp it to a terminal velocity
		grav_vel.y = max(grav_vel.y - gravity_factor * delta, terminal_velocity)
	
	return grav_vel

#Process jumping mechanics
func _jump(delta: float) -> Vector3:
	#Check if the player is touching the floor
	var on_floor: bool = is_on_floor()
	
	#If the player pressed the jump button process the logic
	if jumping:
		#Additional check for whether the player is touchign the ground or was doing so recently
		if coyote_timer > 0.0:
			var base_jump = sqrt(4 * jump_height * gravity_factor)
			
			var bonus := Vector3.ZERO
			#Add the velocity of the ground to the jump velocity
			if on_floor:
				var floor_velocity = get_platform_velocity()
				if floor_velocity.y >= 0.0:
					bonus = floor_velocity
			
			jump_vel = Vector3(0, base_jump, 0) + bonus
			
			coyote_timer = 0.0
		jumping = false
		return jump_vel
	
	#Add gravity to the player
	if on_floor or is_on_ceiling_only():
		jump_vel = Vector3.ZERO
	else:
		jump_vel = jump_vel.move_toward(Vector3.ZERO, gravity_factor * delta)
		
	return jump_vel

#Interaction processing logic
func _interact() -> void:
	#Drop any held entity
	if held != null:
		_server_drop.rpc()
		return
	
	#Get the initial interaction object
	var collider = interaction_raycast.get_collider()
	
	#Check if the player is looking at any interactable entity, if so -> process it
	if collider is Interactable:
		collider.interact()
	elif collider is RigidBody3D:
		_server_pick_up.rpc(collider.get_path())

#Multiplayer synched death processing logic
@rpc("call_local", "any_peer")
func death() -> void:
	if dead: return
	dead = true
	
	#Drop any currently held item
	_server_drop.rpc()
	
	#Reparent model as a corpse
	model.reparent(get_parent(), true)
	#Hide the model for everyone but the dead player
	model.visible = !is_multiplayer_authority()


#Find the next spectator POV
func _find_next_spectate_target() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	var alive_players = players.filter(func(p): return !p.dead)
	
	#Change the perspective and the visibility of the spectated player's body
	if alive_players.size() > 0:
		spectator_index = (spectator_index + 1) % alive_players.size()
		spectator_target = alive_players[spectator_index]
		
		model.visible = true
	else:
		spectator_target = null

#func set_dialog_image(texture: CompressedTexture2D) -> void:
	#hud.set_dialog_image(texture)
#
#func remove_dialog_image() -> void:
	#hud.remove_dialog_image()

#Multiplayer synched entity pickup processing logic
@rpc("any_peer", "call_local")
func _server_pick_up(path: NodePath):
	var object = get_node_or_null(path)
	if object is RigidBody3D:
		held = object
		held.gravity_scale = 0

#Multiplayer synched entity dropping processing logic
@rpc("any_peer", "call_local")
func _server_drop():
	if is_instance_valid(held):
		held.gravity_scale = 1
		
	held = null

#Process logic for held items regarding their velocity and rotation
func _update_held():
	var target: Vector3 = self.global_position - 1.75 * camera.global_transform.basis.z
	var target_rotation = Vector3(camera.rotation.x, self.rotation.y, held.rotation.z)
	
	#Check if the held object and target are physically separated
	if held.global_position.distance_squared_to(target) > 6.0:
		var all_portals = get_tree().get_nodes_in_group("Portals")
		var closest_portal_to_held = null
		var min_dist_to_held = INF
		
		#Find the portal closest to the held object
		for p in all_portals:
			if p.back_portal is Portal3D and p.back_portal.exit_portal != null:
				var dist = p.back_portal.global_position.distance_squared_to(held.global_position)
				if dist < min_dist_to_held:
					min_dist_to_held = dist
					closest_portal_to_held = p.back_portal
			if p.front_portal is Portal3D and p.front_portal.exit_portal != null:
				var dist = p.front_portal.global_position.distance_squared_to(held.global_position)
				if dist < min_dist_to_held:
					min_dist_to_held = dist
					closest_portal_to_held = p.front_portal
					
		#If a portal was found, verify the player is near its connected exit
		if closest_portal_to_held != null:
			var player_portal = closest_portal_to_held.exit_portal
			if player_portal.global_position.distance_squared_to(target) < 25.0:
				#Transform the target point through the portal back to the object's side
				target = player_portal.to_exit_position(target)
				
				#Transform the target rotation to match the new space
				var target_basis = Basis.from_euler(target_rotation)
				var target_transform = Transform3D(target_basis, target)
				var exit_transform = player_portal.to_exit_transform(target_transform)
				target_rotation = exit_transform.basis.get_euler()
	
	held.linear_velocity = 10 * (target - held.global_position)
	held.angular_velocity = 1 * (target_rotation - held.global_rotation)

#Decrease the player sanity when interacting with the Toaster
func _process_sanity(delta: float) -> void:
	if not GameState.toaster_present or dead:
		return
	
	var sanity_drain = 0.0
	
	#Check if the player's eyes are closed for the visual sanity drain
	if not current_eyes_state == Eyes_state.CLOSED:
		#Find the Toaster in the scene
		var anomalies = get_tree().get_nodes_in_group("Anomaly")
		for anomaly in anomalies:
			if anomaly is Toaster:
				#Get the corners of the model
				var points_container = anomaly.get_node_or_null("VisibilityPoints")
				if not points_container:
					printerr("Missing pointers on the Toaster model!")
					continue
				var points_to_check = points_container.get_children()
				
				#Cast a ray for each marker on the model
				for marker in points_to_check:
					var pt = marker.global_position
					#Check if the Toaster is visible on the screen
					if camera.is_position_in_frustum(pt):
						#Raycast for walls to block the effect
						var space_state = get_world_3d().direct_space_state
						var query = PhysicsRayQueryParameters3D.create(camera.global_position, pt)
						query.exclude = [self]
						var result = space_state.intersect_ray(query)
						
						if result.is_empty() or result.collider == anomaly:
							sanity_drain = anomaly.vision_sanity_drain_rate
							break
						
				#Check if the player is within the proximity of the Toaster and apply drain
				var dist_squared = global_position.distance_squared_to(anomaly.global_position)
				var radius_squared = anomaly.proximity_sanity_drain_radius * anomaly.proximity_sanity_drain_radius
				if dist_squared <= radius_squared:
					sanity_drain = max(sanity_drain, anomaly.proximity_sanity_drain_rate)
	
	#Check if the player is touching the Toaster and apply drain
	if held is Toaster:
		sanity_drain = max(sanity_drain, held.touch_sanity_drain_rate)
	
	#Update current sanity checkpoint
	if not GameState.sanity_drain_first_activated and sanity_drain > 0.0:
		GameState.request_sanity_activation.rpc()
			
	#Drain or regain sanity
	if sanity_drain > 0.0 and not dead:
		sanity = max(0, sanity - sanity_drain * delta)
	else:
		sanity = min(100, sanity + GameState.sanity_regeneration_rate * delta)

	#Update the HUD shader strength
	var strength = (100.0 - sanity) / 100.0
	hud.update_distortion(strength)

	#Kill the player if sanity reaches zero
	if sanity <= 0:
		sanity = 100.0
		hud.update_distortion(0.0)
		death.rpc()

#Process the player's blinking timer and input
func _process_blinking(delta) -> void:
	var blinking_detected: bool = false
	
	#Increment the time since last blink
	if current_eyes_state == Eyes_state.OPEN:
		time_since_last_blink += delta
	
	#Check if the player blinked
	if Input.is_action_pressed("blink") or time_since_last_blink >= blink_limit:
		time_since_last_blink = 0.0
		blinking_detected = true
	
	#If the player blinked show a black screen
	if blinking_detected:
		match current_eyes_state:
			Eyes_state.OPEN, Eyes_state.OPENING:
				hud.update_blinking(eyes_close_duration, "close_eyes")
				current_eyes_state = Eyes_state.CLOSING
				print("Eyes closing!")
			Eyes_state.CLOSED:
				blink_timer.start(blink_duration)
				print("Blink duration extended!")

#Closes the eyes once the blink animation finishes
func _on_hud_blink_closed() -> void:
	current_eyes_state = Eyes_state.CLOSED
	print("Eyes closed!")
	blink_timer.start(blink_duration)

#Changes the eyes state to open as a mark of the blinking process finishing
func _on_hud_blink_opened() -> void:
	current_eyes_state = Eyes_state.OPEN
	print("Eyes open!")

#Opens the eyes once the timer runs out
func _on_blink_timer_timeout() -> void:
	if current_eyes_state == Eyes_state.CLOSED:
		current_eyes_state = Eyes_state.OPENING
		hud.update_blinking(eyes_open_duration, "open_eyes")
		print("Eyes opening!")
		time_since_last_blink = 0.0
	
#Run correct animation for player actions
func _update_animation():
	if dead:
		return
	var is_moving := move_dir.length() > 0.1
	
	var anim := "idle"
	
	if crouching:
		anim = "crouch_walking" if is_moving else "crouch_idle"
	else:
		anim = "walking" if is_moving else "idle"
	
	if anim != current_anim_state:
		play_animation.rpc(anim)
		current_anim_state = anim
	
#Plays animation on both remote and local peers
@rpc("call_local")
func play_animation(anim_name: String) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
		
#Returns all MeshInstance3D nodes that make up the player so the portal can clone them
func get_teleportable_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	
	var found_meshes = model.find_children("*", "MeshInstance3D", true, false)
	for m in found_meshes:
		if m is MeshInstance3D:
			meshes.append(m)
	
	return meshes
	
#Called automatically by the Portal3D plugin when the player steps through
func on_teleport(portal: Portal3D) -> void:
	walk_vel = portal.to_exit_direction(walk_vel)
	grav_vel = portal.to_exit_direction(grav_vel)
	jump_vel = portal.to_exit_direction(jump_vel)
	velocity = portal.to_exit_direction(velocity)
	
#Multiplayer synched flashlight toggle
@rpc("call_local", "any_peer")
func _toggle_flashlight(state: bool) -> void:
	is_flashlight_on = state
	if flashlight:
		flashlight.visible = state
		flashlight.light_energy = flashlight_energy
		
#Projects the flashlight through any portals within the light cone
func _update_portal_flashlight() -> void:
	#If the flashlight is off, hide all clones and exit
	if not is_flashlight_on:
		for clone in clone_flashlights:
			if is_instance_valid(clone):
				clone.hide()
		return
	
	#Variable for storing how many flashlight copies are in use
	var used_clones = 0
	
	#Get all portals in the scene
	var all_portals = get_tree().get_nodes_in_group("Portals")
	#Pre-calculate cone boundaries
	var max_dist_sq = flashlight.spot_range * flashlight.spot_range
	
	for p in all_portals:
		#Stop if the flashlight clones were exhausted
		if used_clones >= max_flashlight_clones:
			break
			
		#Check both the front and back of the portal system
		var portal_nodes = p.get_portals()
		for sub_portal in portal_nodes:
			#Stop if the flashlight clones were exhausted
			if used_clones >= max_flashlight_clones:
				break
			
			#Check if the portal is active
			if sub_portal is Portal3D and sub_portal.exit_portal != null:
				if sub_portal.forward_distance(camera) <= 0.0:
					continue
				
				#Check the distance between the portal and the camera
				var dist_sq = sub_portal.global_position.distance_squared_to(camera.global_position)
				if dist_sq < max_dist_sq:
					#Fetch physical dimensions to calculate the boundary corners
					var width_modifier = 0.8
					var height_modifier = 1.5
					var collider = sub_portal.get_node_or_null("TeleportArea/Collider")
					if collider and collider.shape is BoxShape3D:
						width_modifier = collider.shape.size.x / 2.0
						height_modifier = collider.shape.size.y / 2.0
						
					var right = sub_portal.global_transform.basis.x * width_modifier
					var up = sub_portal.global_transform.basis.y * height_modifier
					
					#Define the center and 4 corners of the portal frame
					var points_to_check = [
						sub_portal.global_position, #Center
						sub_portal.global_position + right + up, #Top Right
						sub_portal.global_position - right + up, #Top Left
						sub_portal.global_position + right - up, #Bottom Right
						sub_portal.global_position - right - up  #Bottom Left
					]
					
					#Check if any of the portal corners are inside the player camera frustum
					var is_visible_on_screen = false
					for pt in points_to_check:
						if camera.is_position_in_frustum(pt):
							is_visible_on_screen = true
							break
					
					#Raycast if visible to ensure no walls are blocking the portal
					if is_visible_on_screen:
						var space_state = get_world_3d().direct_space_state
						var is_not_blocked = false
						
						#Grid resolution variables
						var grid_rows = 5
						var grid_cols = 5
						
						#Rayscast across the portal coordinates
						for row in range(grid_rows):
							for col in range(grid_cols):
								#Map coordinates evenly from -1.0 to 1.0 across the surface
								var u = lerp(-1.0, 1.0, float(col) / max(1, grid_cols - 1))
								var v = lerp(-1.0, 1.0, float(row) / max(1, grid_rows - 1))
								
								var point = sub_portal.global_position + (right * u) + (up * v)
								
								var query = PhysicsRayQueryParameters3D.create(camera.global_position, point)
								query.exclude = [self]
								var result = space_state.intersect_ray(query)
								
								if result.is_empty() or sub_portal.is_ancestor_of(result.collider):
									is_not_blocked = true
									break
									
							if is_not_blocked:
								break;
						
						if is_not_blocked:
							var clone = clone_flashlights[used_clones]
							var exit_transform = sub_portal.to_exit_transform(flashlight.global_transform)
							clone.global_transform = exit_transform
							clone.show()
							used_clones += 1
							
	#Hide any remaining clones in the pool that weren't used this frame
	for i in range(used_clones, max_flashlight_clones):
		if is_instance_valid(clone_flashlights[i]):
			clone_flashlights[i].hide()
