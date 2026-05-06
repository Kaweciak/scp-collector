extends Interactable

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var opened: bool = false

@onready var main_collision: CollisionShape3D = $CollisionShape3D

#Reference to the Portal node
@onready var portal: Portal3D = $Portal3D
@export var is_portal: bool = false

func interact() -> void:
	if opened:
		close()
	else:
		open()

func open() -> void:
	rpc("_open")

func close() -> void:
	rpc("_close")

@rpc("call_local", "any_peer")
func _open() -> void:
	if opened:
		return
	opened = true
	animation_player.play("doors_open_animation", 0.5)
	
	#Activate the portal connection
	if is_portal:
		portal.activate()

@rpc("call_local", "any_peer")
func _close() -> void:
	if !opened:
		return
	opened = false
	animation_player.play("doors_close_animation", 0.5)
	
	#Deactivate the portal connection
	if is_portal:
		portal.deactivate(true)
