extends Machine
class_name Mouse

func _on_static_body_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	print("Static Body Input Event")
	print(event.as_text())
	pass # Replace with function body.

func machine_on_collided(node: Node2D) -> void:
	print("Something touched this mouse machine, activating")
	machine_start_activate()

func _ready() -> void:
	activate_startup_time = 0
	super._ready()
