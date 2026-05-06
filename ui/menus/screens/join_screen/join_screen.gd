extends MarginContainer

signal join_game(args: Array)
signal return_pressed

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var name_input: LineEdit = $VBoxContainer/NameInput

func _on_join_button_pressed() -> void:
	emit_signal("join_game", [ip_input.text, name_input.text])

func _on_return_button_pressed() -> void:
	emit_signal("return_pressed")
