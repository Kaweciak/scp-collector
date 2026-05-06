extends Control

@onready var panels = [
	$MenusContainer/PlayersContainer/PlayerPanel1,
	$MenusContainer/PlayersContainer/PlayerPanel2,
	$MenusContainer/PlayersContainer/PlayerPanel3,
	$MenusContainer/PlayersContainer/PlayerPanel4
]

@onready var ready_button = $MenusContainer/ButtonsContainer/ReadyButton
@onready var start_button = $MenusContainer/ButtonsContainer/StartButton

@onready var map_panels = [
	$MenusContainer/MapsContainer/MapPanel1,
	$MenusContainer/MapsContainer/MapPanel2,
	$MenusContainer/MapsContainer/MapPanel3
]

var is_ready := false
var ready_state := {}

var map_votes := {}

var maps := {
	"House": "TBA",
	"Factory": "TBA",
	"Lab": "TBA"
}

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


func _on_map_vote(map_name: String):
	rpc_id(1, "set_map_vote", map_name)


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


@rpc("any_peer", "reliable", "call_local")
func set_map_vote(map_name: String):
	var id = multiplayer.get_remote_sender_id()
	map_votes[id] = map_name

	if multiplayer.is_server():
		rpc("sync_map_votes", map_votes)

	_update_ui()


@rpc("authority", "reliable")
func sync_map_votes(votes: Dictionary):
	map_votes = votes
	_update_ui()


func _update_ui():
	if multiplayer.is_server():
		rpc("sync_ready_state", ready_state)
		rpc("sync_map_votes", map_votes)

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
	_update_map_votes(ids)


func _update_map_votes(ids: Array):
	for i in range(map_panels.size()):
		var map_name = maps.keys()[i]
		var votes_container = map_panels[i].get_node("MapContainer/VotesContainer")

		for j in range(4):
			var vote = votes_container.get_node("VotePlayer" + str(j + 1))
			vote.modulate.a = 0.2

		for j in range(min(ids.size(), 4)):
			var id = ids[j]

			if map_votes.get(id, "") == map_name:
				var vote = votes_container.get_node("VotePlayer" + str(j + 1))
				vote.modulate.a = 1.0


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

	var selected_map = _get_winning_map()

	rpc("start_game", selected_map)


func _get_winning_map() -> String:
	var counts = {}

	for map_name in maps.keys():
		counts[map_name] = 0

	for id in map_votes.keys():
		var vote = map_votes[id]
		if counts.has(vote):
			counts[vote] += 1

	var host_id = multiplayer.get_unique_id()
	var host_vote = map_votes.get(host_id, "")

	var best_map = maps.keys()[0]
	var best_score = -1

	for map_name in counts.keys():
		var score = counts[map_name]

		if map_name == host_vote:
			score += 0.5

		if score > best_score:
			best_score = score
			best_map = map_name

	return best_map


@rpc("authority", "reliable", "call_local")
func start_game(map_name: String):
	print("Loading map: ", map_name)
	get_tree().change_scene_to_file(maps[map_name])
