extends Node2D
class_name GoalArea

signal level_completed

@export var target_object_path: NodePath
@export var next_level: PackedScene
@export_multiline var objective_description: String = "Get the marble onto the chair."
@export_multiline var completion_text: String = "The objective is complete."
@export var show_marker: bool = true:
	set(value):
		show_marker = value
		_update_marker()
@export var marker_color: Color = Color(0.2, 0.85, 0.2, 0.28):
	set(value):
		marker_color = value
		_update_marker()
@export var require_play_mode: bool = true
@export var auto_show_objective: bool = true

@onready var trigger_area: Area2D = $Area2D
@onready var trigger_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var marker: Polygon2D = $Marker

var completion_shown: bool = false
var overlay_layer: CanvasLayer
var objective_overlay: Control
var completion_overlay: Control
var game_mode_controller: GameMode

func _ready() -> void:
	game_mode_controller = get_parent().find_child("GameModeController", false, false) as GameMode
	_update_marker()
	call_deferred("_show_objective_if_needed")

func _physics_process(_delta: float) -> void:
	if completion_shown:
		return
	if require_play_mode and !_is_play_mode():
		return

	var target_node := _get_target_node()
	if target_node == null:
		return

	for body in trigger_area.get_overlapping_bodies():
		if _matches_target(body, target_node):
			_complete_level()
			return

func _on_area_2d_body_entered(body: Node2D) -> void:
	if completion_shown:
		return
	if require_play_mode and !_is_play_mode():
		return

	var target_node := _get_target_node()
	if target_node == null:
		return

	if _matches_target(body, target_node):
		_complete_level()

func _show_objective_if_needed() -> void:
	if !auto_show_objective:
		return
	if objective_description.strip_edges() == "":
		return

	objective_overlay = _create_overlay(
		"Objective",
		objective_description,
		"Start",
		_on_objective_dismissed
	)
	_show_overlay(objective_overlay)

func _on_objective_dismissed() -> void:
	_close_overlay(objective_overlay)

func _complete_level() -> void:
	if completion_shown:
		return

	completion_shown = true
	emit_signal("level_completed")

	var message := completion_text.strip_edges()
	if message == "":
		message = "The objective is complete."
	if next_level == null:
		message += "\n\nNo next level is configured."

	var button_text := "Next Level"
	if next_level == null:
		button_text = "Close"

	completion_overlay = _create_overlay(
		"Level Complete",
		message,
		button_text,
		_on_completion_confirmed
	)
	_show_overlay(completion_overlay)

func _on_completion_confirmed() -> void:
	if next_level != null:
		get_tree().paused = false
		get_tree().change_scene_to_packed(next_level)
		return

	_close_overlay(completion_overlay)

func _get_target_node() -> Node:
	if target_object_path.is_empty():
		return null
	return get_node_or_null(target_object_path)

func _matches_target(body: Node, target_node: Node) -> bool:
	if body == null or target_node == null:
		return false
	if body == target_node:
		return true
	if target_node.is_ancestor_of(body):
		return true
	if body.is_ancestor_of(target_node):
		return true

	var body_root := _get_instanced_scene_root(body)
	var target_root := _get_instanced_scene_root(target_node)
	return body_root == target_root

func _get_instanced_scene_root(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.scene_file_path != "":
			return current
		current = current.get_parent()
	return node

func _is_play_mode() -> bool:
	if game_mode_controller == null:
		return true
	return game_mode_controller.current_mode == GameMode.MachineGameMode.PLAY

func _update_marker() -> void:
	if marker == null:
		return

	marker.visible = show_marker
	marker.color = marker_color

	var rect_shape := trigger_shape.shape as RectangleShape2D
	if rect_shape == null:
		return

	var half_size := rect_shape.size * 0.5
	marker.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])

func _create_overlay(title: String, body_text: String, button_text: String, callback) -> Control:
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(overlay_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	overlay_layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240
	panel.offset_top = -110
	panel.offset_right = 240
	panel.offset_bottom = 110
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	content.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body_text
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(400, 0)
	content.add_child(body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(button_row)

	var confirm_button := Button.new()
	confirm_button.text = button_text
	confirm_button.custom_minimum_size = Vector2(140, 40)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_button.pressed.connect(callback)
	button_row.add_child(confirm_button)

	return root

func _show_overlay(overlay: Control) -> void:
	if overlay == null:
		return
	overlay.visible = true
	get_tree().paused = true

func _close_overlay(overlay: Control) -> void:
	if overlay == objective_overlay:
		objective_overlay = null
	elif overlay == completion_overlay:
		completion_overlay = null

	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()

	if objective_overlay == null and completion_overlay == null:
		get_tree().paused = false