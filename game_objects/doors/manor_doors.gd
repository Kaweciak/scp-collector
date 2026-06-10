extends Interactable

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var opened: bool = false
#Navigation link that allows enemies to walk through the open door
@onready var nav_link: NavigationLink3D = $NavigationLink3D

@onready var main_collision: CollisionShape3D = $CollisionShape3D

#Wings references
@onready var wing: StaticBody3D = $Meshes/Wing
@onready var wing_col: CollisionShape3D = $Meshes/Wing/CollisionShape3D
@onready var wing_mesh: MeshInstance3D = $Meshes/Wing/Door/Door

#References to the Portal related nodes
@onready var portal: Portal3D = $Portal
@export var is_portal: bool = false

@onready var blocker_back: StaticBody3D = $BackBlocker
@onready var blocker_back_col: CollisionShape3D = $BackBlocker/CollisionShape3D

var connected_door: Node = null


func _ready() -> void:
	update_walls()

#Adds the portals to the maintained portal list
func _enter_tree() -> void:
	GameState.register_portal(self)

#Removes the portals from the maintained portal list
func _exit_tree() -> void:
	GameState.unregister_portal(self)

#Allows the player to open and close the door upon interaction
func interact() -> void:
	if opened:
		close()
	else:
		open()


func open() -> void:
	rpc("_open")


func close() -> void:
	rpc("_close")

#Opens the door for all players
@rpc("call_local", "any_peer")
func _open(is_partner: bool = false) -> void:
	if opened:
		return
	opened = true
	
	animation_player.play("doors_open_animation", 0.5)
	#Update blockers
	update_walls()
	
	#Activate the portal connection
	if is_portal and portal.exit_portal != null:
		portal.activate()
		if not is_partner:
			var partner_door = portal.exit_portal.get_parent()
			partner_door.rpc("_open", true)
				
	#Update the navigation link
	nav_link.enabled = true
		
#Closes the door for all players
@rpc("call_local", "any_peer")
func _close(is_partner: bool = false) -> void:
	if !opened:
		return
	opened = false
		
	#Deactivate the portal connection
	if is_portal and portal.exit_portal != null:
		if not is_partner:
			var partner_door = portal.exit_portal.get_parent()
			partner_door.rpc("_close", true)
			
	animation_player.play("doors_close_animation", 0.5)
		
	#Update the navigation link
	nav_link.enabled = false

#Connect to the animation player to deactivate the portal upon closing
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if is_portal and anim_name == "doors_close_animation":
		if portal.exit_portal != null:
			portal.deactivate(true)
				
	#Update blockers
	update_walls()

#Returns portals on this door that are not currently linked
func get_portals() -> Array[Portal3D]:
	var available: Array[Portal3D] = []
	available.append(portal)
	return available

#Toggle the physical walls depending on portal status
func update_walls() -> void:
	#The back wall appears if the portal is active
	var should_block = portal.exit_portal != null
	if blocker_back:
		blocker_back.visible = should_block
		blocker_back.collision_layer = 32769 if should_block else 0
		
	#Recalculate AI navigation tracks
	update_navigation_link()

#Updates the navigation link for proper ai agent pathfinding
func update_navigation_link() -> void:
	if not nav_link:
		return
		
	var active_portal: Portal3D = null
	
	#Get the current active portal
	for p in get_portals():
		if p and p.exit_portal != null:
			active_portal = p
			break
	
	#If the portal is active connect the exit and enter navigation links
	if is_portal and active_portal and active_portal.exit_portal:
		var partner_portal = active_portal.exit_portal
		
		#Reset the start position of the navigation link
		nav_link.start_position = Vector3(0, 0, 0.74)
		
		#Calculate where the ai should leave the portal on the other side
		var local_exit_offset = Vector3(-0.3 * 0.405, 0, 0.74 * 0.405)
		var global_end_pos = partner_portal.global_transform * local_exit_offset
		
		#Set the end position using the calculated coordinates set to local space
		nav_link.end_position = nav_link.to_local(global_end_pos)
		
		#Since single door portals are one-way, disable bidirectionality
		nav_link.bidirectional = false
	else:
		#Reset the link settings if the door was opened normally
		nav_link.start_position = Vector3(0, 0, 0.74)
		nav_link.end_position = Vector3(0, 0, -0.74)
		nav_link.bidirectional = true
