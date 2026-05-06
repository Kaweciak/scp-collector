extends MarginContainer

signal host_pressed
signal join_pressed
signal return_pressed

func _on_host_button_pressed() -> void:
	emit_signal("host_pressed")


func _on_join_button_pressed() -> void:
	emit_signal("join_pressed")


func _on_return_button_pressed() -> void:
	emit_signal("return_pressed")
