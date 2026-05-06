extends MarginContainer

signal host_game(args: Array)
signal return_pressed

@onready var name_input: LineEdit = $VBoxContainer/NameInput

func _on_join_button_pressed() -> void:
	emit_signal("host_game", [name_input.text])

func _on_return_button_pressed() -> void:
	emit_signal("return_pressed")
