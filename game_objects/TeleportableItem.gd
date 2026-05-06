class_name TeleportableItem extends RigidBody3D

#Allows the portal plugin to seemlessly telport meshes via duplication
func get_teleportable_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var found_meshes = self.find_children("*", "MeshInstance3D", true, false)
	
	for m in found_meshes:
		if m is MeshInstance3D:
			meshes.append(m)
			
	return meshes

#Called automatically by the Portal3D plugin when the item steps through
func on_teleport(portal: Portal3D) -> void:	
	angular_velocity = portal.to_exit_direction(angular_velocity)
