extends Node2D
class_name MachinePhysicsObject

const MachineGameMode = GameMode.MachineGameMode

func _on_body_entered(body: Node) -> void:
	print("Rigid body ball entered")
	print(body)
	if body.get_parent() is MachinePhysicsObject:
		print("Touched another machine physics object")
	if body.get_parent() is Machine:
		print("Touched a machine")
		var machine : Machine = body.get_parent()
		machine.machine_on_collided(self)
	pass # Replace with function body.

func on_mode_changed(mode: MachineGameMode) -> void:
	if mode == MachineGameMode.EDIT:
		if $"." is RigidBody2D:
			print("This is a rigid body and the mode changed to play")
			var self_rigid = $"." as RigidBody2D
			self_rigid.freeze = true
			self_rigid.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	elif mode == MachineGameMode.PLAY:
		if $"." is RigidBody2D:
			print("This is a rigid body and the mode changed to edit")
			var self_rigid = $"." as RigidBody2D
			self_rigid.freeze = false

# This is needlessly complicated, godot has _on_mouse*
#func _input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#var query = PhysicsPointQueryParameters2D.new()
		#query.position = get_global_mouse_position()
		#query.collide_with_areas = true
		#query.collide_with_bodies = true
		#
		#var result = get_world_2d().direct_space_state.intersect_point(query, 1)
		#if result.size() > 0:
			#print("Collided with something")
			#print(result)
			#print(result[0].collider)
			#if result[0].collider is MachinePhysicsObject:
				#print("Collided with MachinePhysicsObject")

var grab_cursor = load("res://sprites/ui/grab.png")

func _on_mouse_entered() -> void:
	Input.set_custom_mouse_cursor(grab_cursor, 0, Vector2(12, 18))


func _on_mouse_exited() -> void:
	Input.set_custom_mouse_cursor(null)
