extends CanvasLayer

@onready var sanity_rect: ColorRect = $SanityFilter
@onready var blinking_rect: ColorRect = $BlinkingFilter
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var cursor: TextureRect = $Cursor

var cross_cursor: Texture2D = preload("res://player/line_cross.png")
var hand_cursor: Texture2D = preload("res://player/hand_open.png")

#Signals for the player to know when to open their eyes
signal blink_closed
signal blink_opened

#Update the shader parameter based on the player's sanity level
func update_distortion(value: float) -> void:
	sanity_rect.material.set_shader_parameter("distortion_strength", value)

#Turn the screen to black when the player is blinking
func update_blinking(duration: float, anim_name: String) -> void:
	anim_player.play(anim_name, -1, 1.0 / duration)

#Sets the player's eyes to closed once the eye closing animation finishes
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "close_eyes":
		blink_closed.emit()
	elif anim_name == "open_eyes":
		blink_opened.emit()

func update_cursor(grabbing: bool) -> void:
	if not grabbing:
		cursor.texture = cross_cursor
	else:
		cursor.texture = hand_cursor
