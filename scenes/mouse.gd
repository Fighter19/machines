extends Machine
class_name Mouse

@onready var physics_object: MachinePhysicsObject = $StaticBody2D

func machine_on_collided(_node: Node2D) -> void:
	print("Something touched this mouse machine, activating")
	machine_start_activate()

func _ready() -> void:
	activate_startup_time = 0
	super._ready()

func machine_on_mode_changed(mode: GameMode.MachineGameMode):
	if physics_object != null:
		physics_object.on_mode_changed(mode)
