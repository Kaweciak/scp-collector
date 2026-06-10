extends PortalInteractable

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var opened: bool = false
#Navigation link that allows enemies to walk through the open door
@onready var nav_link: NavigationLink3D = $NavigationLink3D

@onready var main_collision: CollisionShape3D = $CollisionShape3D

#Wings references
@onready var wing1: StaticBody3D = $Wing1
@onready var wing1_col: CollisionShape3D = $Wing1/CSGBakedCollisionShape3D
@onready var wing1_mesh: MeshInstance3D = $Wing1/CSGBakedMeshInstance3D
@onready var wing2: StaticBody3D = $Wing2
@onready var wing2_col: CollisionShape3D = $Wing2/CSGBakedCollisionShape3D
@onready var wing2_mesh: MeshInstance3D = $Wing2/CSGBakedMeshInstance3D

#References to the Portal related nodes
@onready var front_portal: Portal3D = $PortalFront
@onready var back_portal: Portal3D = $PortalBack
@export var is_portal: bool = false

@onready var blocker_front: StaticBody3D = $FrontBlocker
@onready var blocker_back: StaticBody3D = $BackBlocker

@onready var blocker_front_col: CollisionShape3D = $FrontBlocker/CollisionShape3D
@onready var blocker_back_col: CollisionShape3D = $BackBlocker/CollisionShape3D

var connected_front_portal: Node = null
var connected_back_portal: Node = null


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

	var front_active = front_portal.exit_portal != null
	var back_active = back_portal.exit_portal != null

	#Play the correct animation depending on what is the current door state
	if not front_active and back_active:
		animation_player.play("doors_open_animation_reversed", 0.5)
	else:
		animation_player.play("doors_open_animation", 0.5)

	#Update blockers
	update_walls()

	#Activate the portal connection
	if is_portal:
		if front_portal.exit_portal != null:
			front_portal.activate()
			if not is_partner:
				var partner_door = front_portal.exit_portal.get_parent()
				partner_door.rpc("_open", true)
		if back_portal.exit_portal != null:
			back_portal.activate()
			if not is_partner:
				var partner_door = back_portal.exit_portal.get_parent()
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
	if is_portal:
		if front_portal.exit_portal != null:
			if not is_partner:
				var partner_door = front_portal.exit_portal.get_parent()
				partner_door.rpc("_close", true)
		if back_portal.exit_portal != null:
			if not is_partner:
				var partner_door = back_portal.exit_portal.get_parent()
				partner_door.rpc("_close", true)

	var front_active = front_portal.exit_portal != null
	var back_active = back_portal.exit_portal != null

	#Open the correct way depending on which door is opened
	if not front_active and back_active:
		animation_player.play("doors_close_animation_reversed", 0.5)
	else:
		animation_player.play("doors_close_animation", 0.5)

	#Update the navigation link
	nav_link.enabled = false

#Connect to the animation player to deactivate the portal upon closing
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if is_portal:
		if anim_name == "doors_close_animation" or anim_name == "doors_close_animation_reversed":
			if front_portal.exit_portal != null:
				front_portal.deactivate(true)
			if back_portal.exit_portal != null:
				back_portal.deactivate(true)

	#Update blockers
	update_walls()

#Returns portals on this door that are not currently linked
func get_portals() -> Array[Portal3D]:
	var available: Array[Portal3D] = []
	available.append(front_portal)
	available.append(back_portal)
	return available

#Toggle the physical walls depending on portal status
func update_walls() -> void:
	var front_active = front_portal.exit_portal != null
	var back_active = back_portal.exit_portal != null

	#The back wall appears if the front is an active portal, but the back is empty
	var should_block_back = front_active and not back_active
	if (blocker_back.visible != should_block_back):
		blocker_back.visible = should_block_back
		blocker_back.collision_layer = 32769 if should_block_back else 0

	#The front wall appears if the back is an active portal, but the front is empty
	var should_block_front = back_active and not front_active
	if (blocker_front.visible != should_block_front):
		blocker_front.visible = should_block_front
		blocker_front.collision_layer = 32769 if should_block_front else 0
		
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
		nav_link.start_position = Vector3(0.69, -0.445, 0.0)
		
		#Calculate where the ai should leave the portal on the other side
		var local_exit_offset = Vector3(-0.69, -0.445, 0.0)
		var global_end_pos = partner_portal.global_transform * local_exit_offset
		
		#Set the end position using the calculated coordinates set to local space
		nav_link.end_position = nav_link.to_local(global_end_pos)
		
		#Since single door portals are one-way, disable bidirectionality
		nav_link.bidirectional = false
	else:
		#Reset the link settings if the door was opened normally
		nav_link.start_position = Vector3(0.69, -0.445, 0.0)
		nav_link.end_position = Vector3(-0.69, -0.445, 0.0)
		nav_link.bidirectional = true
