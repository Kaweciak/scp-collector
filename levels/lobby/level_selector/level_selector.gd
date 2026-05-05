extends Control

@onready var panels = [
	$MenusContainer/PlayersContainer/PlayerPanel1,
	$MenusContainer/PlayersContainer/PlayerPanel2,
	$MenusContainer/PlayersContainer/PlayerPanel3,
	$MenusContainer/PlayersContainer/PlayerPanel4
]

@onready var ready_button = $MenusContainer/ButtonsContainer/ReadyButton
@onready var start_button = $MenusContainer/ButtonsContainer/StartButton

var is_ready := false
var ready_state := {}

func _ready():
	for p in panels:
		p.modulate.a = 0.0

	start_button.disabled = true

	MultiplayerController.players_updated.connect(_update_ui)

	_update_ui()
	_update_ready_button_text()


func _on_ready_button_pressed():
	is_ready = !is_ready
	var id = multiplayer.get_unique_id()
	ready_state[id] = is_ready
	rpc_id(1, "set_ready_state", is_ready)
	_update_ready_button_text()
	_update_ui()


func _update_ready_button_text():
	ready_button.text = "Not Ready" if is_ready else "Ready Up"


@rpc("any_peer", "reliable", "call_local")
func set_ready_state(state: bool):
	var id = multiplayer.get_remote_sender_id()
	ready_state[id] = state
	if multiplayer.is_server():
		rpc("sync_ready_state", ready_state)
	_update_ui()


@rpc("authority", "reliable")
func sync_ready_state(state_dict: Dictionary):
	ready_state = state_dict
	_update_ui()


func _update_ui():
	if multiplayer.is_server():
		rpc("sync_ready_state", ready_state)

	var ids = MultiplayerController.connected_peer_ids
	var names = MultiplayerController.player_names

	for i in range(panels.size()):
		panels[i].modulate.a = 0.0

	for i in range(min(ids.size(), panels.size())):
		var id = ids[i]
		var panel = panels[i]

		panel.modulate.a = 1.0

		var name_label = panel.get_node("PlayerVBox/PlayerStatusMargin/PlayerStatus/PlayerName")
		var checkbox = panel.get_node("PlayerVBox/PlayerStatusMargin/PlayerStatus/IsReadyCheckbox")

		name_label.text = names.get(id, "Player")
		checkbox.button_pressed = ready_state.get(id, false)

	_check_all_ready()


func _check_all_ready():
	var ids = MultiplayerController.connected_peer_ids

	if ids.is_empty():
		start_button.disabled = true
		return

	for id in ids:
		if not ready_state.get(id, false):
			start_button.disabled = true
			return

	start_button.disabled = not multiplayer.is_server()


func _on_start_button_pressed():
	if not multiplayer.is_server():
		return

	if start_button.disabled:
		return

	rpc("start_game")


@rpc("authority", "reliable", "call_local")
func start_game():
	print("Game starting")
