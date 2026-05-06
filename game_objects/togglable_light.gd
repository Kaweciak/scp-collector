extends Light3D

func toggle() -> void:
	if !visible:
		enable()
	else:
		disable()

func enable() -> void:
	rpc("_enable")

func disable() -> void:
	rpc("_disable")

@rpc("call_local", "any_peer")
func _enable() -> void:
	if visible:
		return
	visible = true

@rpc("call_local", "any_peer")
func _disable() -> void:
	if !visible:
		return
	visible = false
