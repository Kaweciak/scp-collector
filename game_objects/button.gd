class_name InteractableButton extends Interactable

signal pressed

var interaction_enabled = true

func interact() -> void:
	if !interaction_enabled: return
	interaction_enabled = false
	emit_signal("pressed")
	await get_tree().create_timer(1).timeout
	interaction_enabled = true
