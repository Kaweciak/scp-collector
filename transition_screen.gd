extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	color_rect.hide()

func fade_out() -> void:
	color_rect.show()
	animation_player.play("fade_to_black")
	await animation_player.animation_finished

func fade_in() -> void:
	# waiting process frames forces the engine to clear its rendering and initialization backlog
	await get_tree().process_frame
	await get_tree().process_frame
	
	animation_player.play("fade_in")
	await animation_player.animation_finished
	color_rect.hide()
