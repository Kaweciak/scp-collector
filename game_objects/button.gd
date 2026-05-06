class_name InteractableButton extends Interactable

signal pressed

var interaction_enabled = true

func interact() -> void:
	if !interaction_enabled: return
	emit_signal("pressed")
