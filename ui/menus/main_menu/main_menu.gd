extends Node3D

var pages: Dictionary
var pages_arr: Array[Node]
var current_page: Node
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	pages_arr = get_node("Pages").get_children()
	for page in pages_arr:
		pages[page.name] = page
		page.deactivate()
	current_page = pages_arr[0]
	current_page.activate()

# taking button press signal back from paper
func _on_paper_screen_event(event_name: String) -> void:
	print(event_name)
	match event_name:
		"play_pressed":
			_flip_page_to("StartGameScreenPage")
		"extras_pressed":
			_flip_page_to("ExtrasScreenPage")
		"quit_pressed":
			get_tree().quit()
		"host_pressed":
			pass # hosting game logic
		"join_pressed":
			pass # joining game logic
		"return_pressed":
			_flip_page_to("TitleScreenPage")



func _flip_page_to(page_name: String) -> bool:
	if page_name not in pages:
		print(page_name + " not a valid page")
		return false

	var target: Node = pages[page_name]

	var current_index := pages_arr.find(current_page)
	var target_index := pages_arr.find(target)

	if current_index == -1 or target_index == -1:
		return false

	current_page.deactivate()
	target.activate()

	while current_index < target_index:
		current_page.flip_forward()
		current_index += 1
		current_page = pages_arr[current_index]

	while current_index > target_index:
		current_index -= 1
		current_page = pages_arr[current_index]
		current_page.flip_back()

	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# raycast on page and forward signal
		var mouse_pos = event.position

		var origin = camera.project_ray_origin(mouse_pos)
		var dir = camera.project_ray_normal(mouse_pos)
		var end = origin + dir * 10.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(origin, end)

		var result = space_state.intersect_ray(query)

		if not result:
			return

		var collider = result.collider
		if not collider:
			return
		var node = collider
		while node:
			if node is Paper:
				node.forward_input(event, result)
				return
			node = node.get_parent()
