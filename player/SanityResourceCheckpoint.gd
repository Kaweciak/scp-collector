extends Resource
class_name SanityResourceCheckpoint

@export var vision_sanity_drain_rate: float = 2.0
@export var touch_sanity_drain_rate: float = 1.0
@export var proximity_sanity_drain_rate: float = 0.0
@export var proximity_sanity_drain_radius: float = 1.0
@export var sanity_regeneration_rate: float = 0.5
@export var time_to_increment_sanity_checkpoint: float = 5.0 * 60.0
