class_name Toaster extends RigidBody3D

func _ready() -> void:
	#Only the server should process physics for this object
	set_multiplayer_authority(1) 
	if not multiplayer.is_server():
		freeze = true
