extends MultiplayerSynchronizer
class_name PhysicsSynchronizer

#Array format: [Frame, Position, Quaternion Rotation, Linear Velocity, Angular Velocity]
@export var sync_bstate_array: Array = [0, Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO]

@onready var sync_object: RigidBody3D = get_parent()

var frame: int = 0
var last_frame: int = 0

func _ready() -> void:
	#Connect the sync signal to the validation function
	synchronized.connect(_on_synchronized)

func _physics_process(_delta: float) -> void:
	#Authority writes the true physics state into the array
	if is_multiplayer_authority() and is_instance_valid(sync_object):
		frame += 1
		sync_bstate_array[0] = frame
		sync_bstate_array[1] = sync_object.global_position
		sync_bstate_array[2] = sync_object.global_basis.get_rotation_quaternion()
		sync_bstate_array[3] = sync_object.linear_velocity
		sync_bstate_array[4] = sync_object.angular_velocity
		
	#Clients smoothly interpolate toward the array data
	elif not is_multiplayer_authority() and is_instance_valid(sync_object):
		var target_pos: Vector3 = sync_bstate_array[1]
		var target_rot: Quaternion = sync_bstate_array[2]
		
		var diff: float = sync_object.global_position.distance_to(target_pos)
		
		#If the object teleported or dropped far away, snap instantly
		if diff > 3.0:
			sync_object.global_position = target_pos
			sync_object.global_basis = Basis(target_rot)
		#Otherwise, smoothly glide the object to correct minor network latency
		else:
			sync_object.global_position = sync_object.global_position.lerp(target_pos, 0.2)
			var current_rot = sync_object.global_basis.get_rotation_quaternion()
			sync_object.global_basis = Basis(current_rot.slerp(target_rot, 0.2))
			
		#Apply velocities so client-side collisions still react correctly
		sync_object.linear_velocity = sync_bstate_array[3]
		sync_object.angular_velocity = sync_bstate_array[4]

func _on_synchronized() -> void:
	#Discard out-of-order delayed network packets
	if sync_bstate_array[0] <= last_frame:
		return
	last_frame = sync_bstate_array[0]
