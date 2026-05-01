extends MarginContainer

signal return_pressed

func _on_return_button_pressed() -> void:
	emit_signal("return_pressed")
