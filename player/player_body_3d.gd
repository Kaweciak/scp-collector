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
@export var sanity_drain_rate = 5.0

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

static var debug_mode_enabled: bool = false

var current_anim_state: String = ""

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
	_capture_mouse()
	camera.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		model.visible = false

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():

		var on_floor: bool = is_on_floor()

		if on_floor:
			coyote_timer = coyote_time
		else:
			coyote_timer = max(coyote_timer - delta, 0.0)

		if Input.is_action_just_pressed("jump"):
			jumping = true

		if tried_uncroaching:
			_try_uncroach()

		velocity = _walk(delta) + _gravity(delta) + _jump(delta)
		move_and_slide()
		
		_update_animation()
	
	if is_multiplayer_authority() or multiplayer.is_server():
		if held != null:
			_update_held()
	
	_process_sanity(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		look_dir = event.relative * 0.001
		if mouse_captured: _rotate_camera()
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

		elif event.is_action_pressed("interact"):
			_interact()

		elif event.is_action_pressed("debug_activate"):
			debug_mode_enabled = true
		elif event.is_action_released("debug_activate"):
			debug_mode_enabled = false

		elif event.is_action_pressed("pause"):
			if mouse_captured:
				_release_mouse()
			else:
				_capture_mouse()

		if debug_mode_enabled:
			if event.is_action_pressed("debug_death"):
				death()

#func _pause() -> void:
	#pause_menu.show()
	#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#set_process_unhandled_input(false)
	#pause_menu.set_process_unhandled_input(true)
	#set_physics_process(false)

func _crouch() -> void:
	tried_uncroaching = false
	crouching = true
	base_collision.disabled = true
	crouch_collision.disabled = false
	crouch_collision.visible = true
	base_collision.visible = false
	camera.position.y = 0.2

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

func _try_uncroach() -> void:
	if _can_uncrouch():
		_uncrouch()
	else:
		tried_uncroaching = true

func _uncrouch() -> void:
	crouching = false
	base_collision.disabled = false
	crouch_collision.disabled = true
	base_collision.visible = true
	crouch_collision.visible = false
	camera.position.y = 0.7

func _sprint() -> void:
	sprinting = true

func _unsprint() -> void:
	sprinting = false

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func _rotate_camera(sens_mod: float = 1.0) -> void:
	rotation.y -= look_dir.x * camera_sens * sens_mod
	camera.rotation.x = clamp(camera.rotation.x - look_dir.y * camera_sens * sens_mod, -1.5, 1.5)

func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector(&"left", &"right", &"forwards", &"backwards")
	var _forward: Vector3 = camera.global_transform.basis * Vector3(move_dir.x, 0, move_dir.y)
	var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized() * (sprint_factor if sprinting else 1.0) * (crouch_factor if crouching else 1.0)
	walk_vel = walk_vel.move_toward(walk_dir * speed * move_dir.length(), acceleration * delta)
	return walk_vel

func _gravity(delta: float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity_factor, 0), gravity_factor * delta)
	return grav_vel

func _jump(delta: float) -> Vector3:
	var on_floor: bool = is_on_floor()

	was_on_floor = on_floor

	if jumping:
		if coyote_timer > 0.0:
			var base_jump = sqrt(4 * jump_height * gravity_factor)

			var bonus := Vector3.ZERO
			if on_floor:
				var floor_velocity = get_platform_velocity()
				if floor_velocity.y >= 0.0:
					bonus = floor_velocity

			jump_vel = Vector3(0, base_jump, 0) + bonus

			coyote_timer = 0.0
		jumping = false
		return jump_vel

	jump_vel = Vector3.ZERO if on_floor or is_on_ceiling_only() else jump_vel.move_toward(Vector3.ZERO, gravity_factor * delta)
	return jump_vel


func _interact() -> void:
	if held != null:
		_server_drop.rpc()
		return
	var collider = interaction_raycast.get_collider()
	if collider is Interactable:
		collider.interact()
	elif collider is RigidBody3D:
		_server_pick_up.rpc(collider.get_path())


func death() -> void:
	get_tree().reload_current_scene()

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

@rpc("any_peer", "call_local")
func _server_pick_up(path: NodePath):
	var object = get_node_or_null(path)
	if object is RigidBody3D:
		held = object
		held.gravity_scale = 0

@rpc("any_peer", "call_local")
func _server_drop():
	if is_instance_valid(held):
		held.gravity_scale = 1
	
	held = null

func _update_held():
	var target_rotation = Vector3(camera.rotation.x, self.rotation.y, held.rotation.z)
	var target: Vector3 = self.global_position - 1.75* camera.global_transform.basis.z
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
	if is_draining:
		sanity = max(0, sanity - sanity_drain_rate * delta)
	else:
		sanity = min(100, sanity + (sanity_drain_rate * 0.1) * delta)
	
	#Update the HUD shader strength
	var strength = (100.0 - sanity) / 100.0
	hud.update_distortion(strength)
	
	#Kill the player if sanity reaches zero
	if sanity <= 0:
		sanity = 100.0
		death()
	
func _update_animation():
	var is_moving := move_dir.length() > 0.1
	
	var anim := "idle"
	
	if crouching:
		anim = "crouch_walking" if is_moving else "crouch_idle"
	else:
		anim = "walking" if is_moving else "idle"
	
	if anim != current_anim_state:
		play_animation.rpc(anim)
		current_anim_state = anim

@rpc("call_local")
func play_animation(anim_name: String) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
