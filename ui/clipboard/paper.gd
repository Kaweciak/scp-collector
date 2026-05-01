class_name Paper
extends Node3D

signal screen_event(event_name: String)

@onready var sub_viewport: SubViewport = $SubViewport
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var screen_scene: PackedScene
var screen: Control

func _ready() -> void:
	screen = screen_scene.instantiate()
	sub_viewport.add_child(screen)
	var excluded := []
	var cls := "BaseButton"

	while cls != "":
		for sig in ClassDB.class_get_signal_list(cls):
			excluded.append(sig.name)
		cls = ClassDB.get_parent_class(cls)

	for sig in screen.get_signal_list():
		if sig.name in excluded:
			continue

		screen.connect(sig.name, Callable(self, "_screen_signal").bind(sig.name))


func flip_forward() -> void:
	animation_player.play("FlipNext")

func flip_back() -> void:
	animation_player.play_backwards("FlipNext")

func _screen_signal(signal_name: String):
	emit_signal("screen_event", signal_name)

func forward_input(event: InputEvent, ray_result: Dictionary):
	var ev := event.duplicate()

	var hit_pos: Vector3 = ray_result.position

	var local_pos: Vector3 = global_transform.affine_inverse() * hit_pos

	var box_shape: BoxShape3D = $StaticBody3D/CollisionShape3D.shape
	var extents: Vector3 = box_shape.size

	var uv_x = (local_pos.x + extents.x * 0.5) / extents.x # idk why I have to add extents only here, but it works i guess
	var uv_y = (local_pos.z) / extents.z

	var viewport_size: Vector2 = sub_viewport.size
	var pixel_pos = Vector2(uv_x, uv_y) * viewport_size

	ev.position = Vector2(pixel_pos)

	sub_viewport.push_input(ev, false)
