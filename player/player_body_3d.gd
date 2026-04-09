class_name PlayerBody3D extends CharacterBody3D

@onready var hud: CanvasLayer = $MainCamera/HUD

@export_range(1, 35, 1) var speed: float = 10
@export_range(10, 400, 1) var acceleration: float = 100

@export_range(0.1, 3.0, 0.1) var jump_height: float = 1
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1

@export_range(1.1, 2.0, 0.05) var sprint_factor: float = 1.1
@export_range(0.1, 0.9, 0.05) var crouch_factor: float = 0.9

@export_range(0.01, 0.5, 0.01) var coyote_time: float = 0.2
var coyote_timer: float = 0.0

#Sanity variable
@export var sanity: float = 100.0
@export var sanity_drain_rate = 5

var sprinting: bool = false
var crouching: bool = false
var jumping: bool = false
var mouse_captured: bool = false
var was_on_floor: bool = true
var tried_uncroaching: bool = false

var gravity_factor: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_dir: Vector2
var look_dir: Vector2

var walk_vel: Vector3
var grav_vel: Vector3
var jump_vel: Vector3

var held: RigidBody3D

var dead: bool = false

static var debug_mode_enabled: bool = false

var current_anim_state: String = ""

#Spectator variables
var spectator_target: PlayerBody3D = null
var last_spectator_target: PlayerBody3D = null
var spectator_index: int = 0

@onready var camera: Camera3D = $MainCamera
@onready var base_collision: CollisionShape3D = $BaseCollision
@onready var crouch_collision: CollisionShape3D = $CrouchCollision
@onready var interaction_raycast: RayCast3D = $MainCamera/InteractionRaycast

@onready var animation_player: AnimationPlayer = $ModelHolder/Model/AnimationPlayer
@onready var model: Node3D = $ModelHolder/Model

# @onready var pause_menu: PauseMenu = $MainCamera/PauseMenu
# @onready var hud: Hud = $MainCamera/Hud


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	#Get the mouse to focus on the screen once the player spawn
	_capture_mouse()
	#Assign the authority to the camera
	camera.current = is_multiplayer_authority()
	#If the instance owns the player make the model invisible so that the player doesn't see visual glitches
	if is_multiplayer_authority():
		model.visible = false


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
		
		#Process player animation
		_update_animation()
		
		#Process sanity drain for SCP-426
		_process_sanity(delta)

	#Process entity holding mechanics
	if is_multiplayer_authority() or multiplayer.is_server():
		if held != null:
			_update_held()

#Process unhandled input
func _unhandled_input(event: InputEvent) -> void:
	#Only the owner instance can process input for the player
	if not is_multiplayer_authority():
		return
		
	#Debug logic processing
	elif event.is_action_pressed("debug_activate"):
		debug_mode_enabled = true
	elif event.is_action_released("debug_activate"):
		debug_mode_enabled = false
		
	#Process spectator inputs
	if dead:
		if event.is_action_pressed("interact"):
			_find_next_spectate_target()
		return
		
	#Process mouse inputs
	if event is InputEventMouseMotion:
		look_dir = event.relative * 0.001
		if mouse_captured: _rotate_camera()
		
	#Process player input
	if event is InputEventKey:
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
				
		elif event.is_action_pressed("interact") and not dead:
			_interact()
		
		#Helper for releaseing mouse capture -> should be replaced by the game menu
		#TODO
		elif event.is_action_pressed("pause"):
			if mouse_captured:
				_release_mouse()
			else:
				_capture_mouse()
		
		if debug_mode_enabled:
			if event.is_action_pressed("debug_death"):
				death.rpc()


#func _pause() -> void:
	#pause_menu.show()
	#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#set_process_unhandled_input(false)
	#pause_menu.set_process_unhandled_input(true)
	#set_physics_process(false)

#Crouch mechanic processing -> should be adjusted to play an animation
#TODO
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
		#Adjust spectate players' visibility
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
	if is_on_floor():
		grav_vel = Vector3.ZERO
	else:
		grav_vel = grav_vel.move_toward(Vector3(0, velocity.y - gravity_factor, 0), gravity_factor * delta)
		
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
	#Check if the player is looking at any interactable entity, if so -> process it
	var collider = interaction_raycast.get_collider()
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
#
#func _bus_enabled(idx: int) -> void:
	#hud.bus_enabled(idx)
#
#func _bus_disabled(idx: int) -> void:
	#hud.bus_disabled(idx)

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
	var target_rotation = Vector3(camera.rotation.x, self.rotation.y, held.rotation.z)
	var target: Vector3 = self.global_position - 1.75 * camera.global_transform.basis.z
	held.linear_velocity = 10 * (target - held.global_position)
	held.angular_velocity = 1 * (target_rotation - held.global_rotation)

#Decrease the player sanity if looking at the Toaster
func _process_sanity(delta: float) -> void:
	var anomalies = get_tree().get_nodes_in_group("Anomaly")
	var is_draining = false

	#Check if the Toaster is visible on the screen
	for anomaly in anomalies:
		if anomaly is Toaster:
			if camera.is_position_in_frustum(anomaly.global_position):
				#Raycast for walls to block the effect
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(camera.global_position, anomaly.global_position)
				query.exclude = [self]
				var result = space_state.intersect_ray(query)

				if result.is_empty() or result.collider == anomaly:
					is_draining = true
					break

	#Drain or regain sanity depending on if the anomaly is in sight
	if is_draining and not dead:
		sanity = max(0, sanity - sanity_drain_rate * delta)
	else:
		sanity = min(100, sanity + (sanity_drain_rate * 0.1) * delta)

	#Update the HUD shader strength
	var strength = (100.0 - sanity) / 100.0
	hud.update_distortion(strength)

	#Kill the player if sanity reaches zero
	if sanity <= 0:
		sanity = 100.0
		sanity_drain_rate = 0.0
		hud.update_distortion(0.0)
		death.rpc()

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
