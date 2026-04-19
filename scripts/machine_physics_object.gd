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
