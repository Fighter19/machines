extends Node2D
class_name Machine

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@export var activate_startup_time: float = 2

var startup_timer: Timer
	
func machine_on_activate() -> void:
	print("Activate over")
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("active"):
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

func machine_on_collided(_node: Node2D) -> void:
	print("Something touched this machine")

func machine_on_mode_changed(_mode: GameMode.MachineGameMode):
	# Virtual function to be overloaded
	pass

func _ready() -> void:
	if sprite != null:
		print(sprite.animation)
