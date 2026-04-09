extends CanvasLayer

@onready var color_rect: ColorRect = $SanityFilter

#Update the shader parameter based on the player's sanity level
func update_distortion(value: float) -> void:
	color_rect.material.set_shader_parameter("distortion_strength", value)
