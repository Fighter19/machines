extends Machine
class_name Eraser

func machine_on_collided(node: Node2D) -> void:
	print("Collided with node " + node.to_string())
	if node is RigidBody2D:
		var rigidBody : RigidBody2D = node;
		rigidBody.apply_impulse(Vector2(0, -500))
	if sprite.sprite_frames.has_animation("active"):
		sprite.play("active")

func _ready() -> void:
	activate_startup_time = 0
	super._ready()


func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation == "active":
		sprite.play("idle")
	pass # Replace with function body.
