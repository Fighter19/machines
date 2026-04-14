extends Node2D
class_name Machine

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var activate_startup_time: float = 2

var startup_timer: Timer
	
func machine_on_activate() -> void:
	print("Activate over")
	if sprite.sprite_frames.has_animation("active"):
		sprite.animation = "active"

func machine_start_activate() -> void:
	if activate_startup_time == 0:
		machine_on_activate()
		return

	startup_timer = Timer.new()
	
	startup_timer.one_shot = true
	startup_timer.timeout.connect(machine_on_activate)
	add_child(startup_timer)
	startup_timer.start(activate_startup_time)


func _ready() -> void:
	# For now activate immediately
	print(sprite.animation)
	machine_start_activate()
