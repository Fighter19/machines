extends Node2D
class_name MachinePhysicsObject

const MachineGameMode = GameMode.MachineGameMode
@export var draggable: bool = false
@export var drag_start_threshold: float = 12.0
@export var pinned_in_play: bool = false
var is_hovering: bool = false
var is_grabbed: bool = false
var is_press_candidate: bool = false
var press_start_viewport_position: Vector2 = Vector2.ZERO
# This shouldn't be here, but should be taken from a Singleton
# Still it's easier to just do it here
var current_mode = MachineGameMode.EDIT

var edit_position: Vector2
var edit_rotation: float = 0.0
var has_saved_edit_position: bool = false
static var cursor_owner: MachinePhysicsObject = null

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
			self_rigid.freeze = pinned_in_play
			if pinned_in_play:
				self_rigid.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				self_rigid.linear_velocity = Vector2.ZERO
				self_rigid.angular_velocity = 0.0

func is_rigidbody_machine() -> bool:
	return $"." is RigidBody2D

func set_pinned_in_play(value: bool) -> void:
	pinned_in_play = value

func is_pinned_in_play() -> bool:
	return pinned_in_play

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

var grab_cursor_neutral = load("res://sprites/ui/cursor_grab1.png")
var grab_cursor_pressed = load("res://sprites/ui/cursor_grab2.png")

func _update_grab_cursor() -> void:
	if !draggable or !is_hovering or current_mode != MachineGameMode.EDIT:
		if cursor_owner == self:
			Input.set_custom_mouse_cursor(null)
			cursor_owner = null
		return

	var cursor_texture = grab_cursor_neutral
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		cursor_texture = grab_cursor_pressed
	cursor_owner = self
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(4, 11))

func _on_mouse_entered() -> void:
	if !draggable:
		return
	if current_mode == MachineGameMode.EDIT:
		is_hovering = true
		_update_grab_cursor()


func _on_mouse_exited() -> void:
	if !draggable:
		return
	is_hovering = false
	_update_grab_cursor()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !draggable:
		if is_hovering:
			Input.set_custom_mouse_cursor(null)
		is_hovering = false
		is_grabbed = false
		is_press_candidate = false
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and is_hovering and current_mode == MachineGameMode.EDIT:
			is_press_candidate = true
			is_grabbed = false
			press_start_viewport_position = mouse_event.position
			var preview_controller := _get_preview_controller()
			if preview_controller != null:
				preview_controller.select_machine_item_silent(self, _get_drag_target())
		# This also wouldn't work reliably
		#elif event.button_index == 1 && event.pressed == false:
			#is_grabbed = false
			
	# Can't check for motion event here to move object,
	# if the object is moved too fast, it will not receive further events


func _process(_delta: float) -> void:
	if !draggable:
		if cursor_owner == self:
			Input.set_custom_mouse_cursor(null)
			cursor_owner = null
		is_hovering = false
		is_grabbed = false
		is_press_candidate = false
		return

	if is_hovering or cursor_owner == self:
		_update_grab_cursor()

	var drag_target := _get_drag_target()
	if is_press_candidate and !is_grabbed and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var cursor_viewport_position := get_viewport().get_mouse_position()
		if cursor_viewport_position.distance_to(press_start_viewport_position) >= drag_start_threshold:
			is_grabbed = true
			is_press_candidate = false
			var preview_controller := _get_preview_controller()
			if preview_controller != null:
				preview_controller.clear_selected_machine_item(self)

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
		elif is_press_candidate and current_mode == MachineGameMode.EDIT:
			var preview_controller := _get_preview_controller()
			if preview_controller != null:
				preview_controller.select_machine_item(self, drag_target, get_viewport().get_mouse_position())
		is_press_candidate = false
		is_grabbed = false

func rotate_clockwise(degrees: float) -> void:
	var drag_target := _get_drag_target()
	drag_target.global_rotation += deg_to_rad(degrees)
	_save_edit_pose(drag_target)

	if $"." is RigidBody2D:
		var self_rigid = $"." as RigidBody2D
		self_rigid.linear_velocity = Vector2.ZERO
		self_rigid.angular_velocity = 0.0

func _get_preview_controller() -> MachinePreview:
	var preview_controller := get_tree().get_first_node_in_group("machine_preview")
	if preview_controller == null:
		return null

	if !(preview_controller is MachinePreview):
		return null

	return preview_controller as MachinePreview

func _try_return_to_inventory(item_node: Node) -> bool:
	var preview_controller := _get_preview_controller()
	if preview_controller == null:
		return false

	var viewport_position := get_viewport().get_mouse_position()
	return preview_controller.try_return_item_to_inventory(item_node, viewport_position)
