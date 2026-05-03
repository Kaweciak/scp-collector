extends Node3D
class_name Room

@export var room_id: String
@export var is_corridor: bool = false

var original_furniture_positions: Array[Transform3D] = []
var active_portals: Dictionary = {}
var current_intensity: float = 0.0


func expand_interior(factor: float):
	pass
	
	
func duplicate_furniture():
	pass
	
	
func generate_maze(intensity: float):
	pass
	
	
func remap_door(portal_name: String, target_room: Room):
	pass
