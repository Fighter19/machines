extends Node2D
class_name MachinePhysicsObject

const MachineGameMode = GameMode.MachineGameMode
var is_hovering: bool = false
var is_grabbed: bool = false
# This shouldn't be here, but should be taken from a Singleton
# Still it's easier to just do it here
var current_mode = MachineGameMode.EDIT

var edit_position: Vector2
var edit_rotation: float = 0.0
var has_saved_edit_position: bool = false

func _ready() -> void:
	# Seed restore position from the current transform so freshly spawned
	# objects do not jump when edit mode is applied.
	var drag_target := _get_drag_target()
	_save_edit_pose(drag_target)

func _save_edit_pose(drag_target: Node2D) -> void:
	edit_position = drag_target.global_position
	edit_rotation = drag_target.global_rotation
	has_saved_edit_position = true

func _get_drag_target() -> Node2D:
	# For machine scenes where this script is attached to a child collider,
	# move the machine root instead so visuals and collision stay aligned.
	if get_parent() is Node2D and get_parent() is Machine:
		return get_parent() as Node2D
	return self as Node2D

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
	current_mode = mode
	var drag_target := _get_drag_target()
	if mode == MachineGameMode.EDIT:
		if has_saved_edit_position:
			# Restore old position captured when switching into play mode.
			drag_target.global_position = edit_position
			drag_target.global_rotation = edit_rotation
		if $"." is RigidBody2D:
			print("This is a rigid body and the mode changed to play")
			var self_rigid = $"." as RigidBody2D
			self_rigid.freeze = true
			self_rigid.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			self_rigid.linear_velocity = Vector2.ZERO
			self_rigid.angular_velocity = 0.0
	elif mode == MachineGameMode.PLAY:
		# This assumes the previous mode was edit, so save it
		# in order to restore it later
		_save_edit_pose(drag_target)
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
	if current_mode == MachineGameMode.EDIT:
		Input.set_custom_mouse_cursor(grab_cursor, Input.CURSOR_ARROW, Vector2(12, 18))
		is_hovering = true


func _on_mouse_exited() -> void:
	Input.set_custom_mouse_cursor(null)
	is_hovering = false


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == 1 && event.pressed == true && is_hovering:
			is_grabbed = true
		# This also wouldn't work reliably
		#elif event.button_index == 1 && event.pressed == false:
			#is_grabbed = false
			
	# Can't check for motion event here to move object,
	# if the object is moved too fast, it will not receive further events


func _process(_delta: float) -> void:
	var drag_target := _get_drag_target()
	if is_grabbed:
		drag_target.global_position = get_global_mouse_position()

	if current_mode == MachineGameMode.EDIT and $"." is RigidBody2D and !is_grabbed and has_saved_edit_position:
		# Keep rigidbodies glued to their saved edit pose while editing,
		# so physics cannot slowly mutate edit_position.
		drag_target.global_position = edit_position
		drag_target.global_rotation = edit_rotation
		var self_rigid = $"." as RigidBody2D
		self_rigid.linear_velocity = Vector2.ZERO
		self_rigid.angular_velocity = 0.0

	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_grabbed and current_mode == MachineGameMode.EDIT:
			var returned_to_inventory := _try_return_to_inventory(drag_target)
			if !returned_to_inventory:
				# Commit final user placement as the new edit pose.
				_save_edit_pose(drag_target)
		is_grabbed = false

func _try_return_to_inventory(item_node: Node) -> bool:
	var preview_controller := get_tree().get_first_node_in_group("machine_preview")
	if preview_controller == null:
		return false

	if !(preview_controller is MachinePreview):
		return false

	var viewport_position := get_viewport().get_mouse_position()
	return (preview_controller as MachinePreview).try_return_item_to_inventory(item_node, viewport_position)
