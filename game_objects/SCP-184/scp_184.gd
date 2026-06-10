class_name SCP_184 extends TeleportableItem

func _ready() -> void:
	PortalManager.activate_anomaly()

#Adds itself to the maintained anomaly list
func _enter_tree() -> void:
	GameState.register_anomaly(self)

#Removes itself from the maintained anomaly list
func _exit_tree() -> void:
	GameState.register_anomaly(self)
	PortalManager.deactivate_anomaly()
