extends Machine
class_name Mouse

func machine_on_collided(_node: Node2D) -> void:
	print("Something touched this mouse machine, activating")
	machine_start_activate()

func _ready() -> void:
	activate_startup_time = 0
	super._ready()
