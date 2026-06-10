extends MarginContainer

signal return_pressed

@onready var fullscreen_checkbox = $VBoxContainer/FullScreenContainer/FullScreenCheckbox
@onready var volume_slider = $VBoxContainer/AudioSliderContainer/AudioSlider

func _ready() -> void:
	fullscreen_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	var bus_index = AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))

func _on_return_button_pressed() -> void:
	emit_signal("return_pressed")

func _on_fullscreen_check_box_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_slider_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
