extends Node3D

func _ready() -> void:
	MultiplayerController.spawner.spawn_path = $PlayerContainer.get_path()
	MultiplayerController.spawn_players_in_new_scene()

@rpc("authority", "call_local", "reliable")
func sync_reload() -> void:
	get_tree().reload_current_scene()
