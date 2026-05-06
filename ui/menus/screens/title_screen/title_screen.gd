extends MarginContainer

signal play_pressed
signal settings_pressed
signal extras_pressed
signal quit_pressed

func _on_play_button_pressed() -> void:
	emit_signal("play_pressed")


func _on_settings_button_pressed() -> void:
	emit_signal("settings_pressed")


func _on_extras_button_pressed() -> void:
	emit_signal("extras_pressed")


func _on_quit_button_pressed() -> void:
	emit_signal("quit_pressed")
