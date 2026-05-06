extends MarginContainer

signal unpause

@onready var pause_menu_panel = $HBoxContainer/PauseMenuContainer
@onready var anomalies_menu = $HBoxContainer/AnomaliesMenuContainer

var anomaly_info_panels: Dictionary = {}

func _ready() -> void:
	anomaly_info_panels[173] = $HBoxContainer/AnomaliesMenuContainer/InfoContainer173
	anomaly_info_panels[184] = $HBoxContainer/AnomaliesMenuContainer/InfoContainer184
	anomaly_info_panels[428] = $HBoxContainer/AnomaliesMenuContainer/InfoContainer428

func _on_pause_button_pressed() -> void:
	pause_menu_panel.visible = true
	anomalies_menu.visible = false

func _on_anomalies_button_pressed() -> void:
	anomalies_menu.visible = true
	pause_menu_panel.visible = false


func _on_resume_button_pressed() -> void:
	emit_signal("unpause")

func _on_quit_menu_button_pressed() -> void:
	pass

func _on_quit_dekstop_button_pressed() -> void:
	get_tree().quit()


func _on_scp_button_pressed(scp_number: int) -> void:
	for anomaly_info_panel in anomaly_info_panels.values():
		anomaly_info_panel.visible = false

	anomaly_info_panels[scp_number].visible = true
