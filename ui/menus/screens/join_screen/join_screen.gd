extends MarginContainer

signal join_game(args: Array)
signal return_pressed

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _ready() -> void:
	error_label.modulate.a = 0.0
	
	MultiplayerController.connection_failed.connect(show_error)

func _on_join_button_pressed() -> void:
	#Hide previous errors when attempting a new connection
	error_label.modulate.a = 0.0
		
	emit_signal("join_game", [ip_input.text, name_input.text])

func _on_return_button_pressed() -> void:
	emit_signal("return_pressed")

func show_error(message: String) -> void:
	error_label.text = message
	error_label.modulate.a = 1.0
