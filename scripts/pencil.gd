extends Machine
class_name Pencil

@onready var physics_object: MachinePhysicsObject = $StaticBody2D

func _ready() -> void:
	activate_startup_time = 0
	super._ready()

func machine_on_mode_changed(mode: GameMode.MachineGameMode):
	if physics_object != null:
		physics_object.on_mode_changed(mode)
