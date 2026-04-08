extends Node3D

func _ready() -> void:
	MultiplayerController.spawner.spawn_path = $PlayerContainer.get_path()
	MultiplayerController.spawn_players_in_new_scene()
	
	$Van/AnomalyDetactionArea3D.body_entered.connect(_on_van_area_body_entered)

func _on_van_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Anomaly"):
		if multiplayer.is_server():
			get_tree().reload_current_scene()
