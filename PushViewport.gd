extends SubViewportContainer

func _unhandled_input(event: InputEvent) -> void:
 $SubViewport.push_unhandled_input(event)