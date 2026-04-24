extends Node2D
class_name MachinePreview

@export var inventory_data: MachineInventoryData
@export var spawn_parent: Node
@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")
@export var mouse_scene: PackedScene = preload("res://scenes/mouse.tscn")
@export var eraser_scene: PackedScene = preload("res://scenes/eraser.tscn")
@export var preview_alpha: float = 0.55
@export var menu_width: float = 170.0
@export var game_mode_controller: GameMode

var selected_type: MachineInventoryData.MachineType = MachineInventoryData.MachineType.MARBLE
var preview_instance: Node
var is_dragging_machine: bool = false

var menu_layer: CanvasLayer
var menu_panel: PanelContainer
var menu_title_label: Label
var menu_content: VBoxContainer
var menu_buttons: Dictionary = {}
var menu_button_labels: Dictionary = {}
var last_known_mode: int = -1

func _ready() -> void:
	if inventory_data == null:
		inventory_data = get_parent().find_child("MachineInventoryData", false, false) as MachineInventoryData

	if spawn_parent == null:
		spawn_parent = get_parent()

	if game_mode_controller == null:
		game_mode_controller = get_parent().find_child("GameModeController", false, false) as GameMode
	if game_mode_controller != null:
		last_known_mode = game_mode_controller.current_mode

	selected_type = _first_available_type(selected_type)
	_create_left_menu()
	_attach_game_mode_controls_to_menu()
	_update_menu_contents()
	_refresh_preview_instance()

func _process(_delta: float) -> void:
	if game_mode_controller != null and game_mode_controller.current_mode != last_known_mode:
		last_known_mode = game_mode_controller.current_mode
		_update_menu_contents()

	if is_dragging_machine and !_is_edit_mode():
		_cancel_drag()
		return

	if is_dragging_machine:
		var cursor := get_global_mouse_position()
		global_position = cursor
		if preview_instance != null:
			_set_spawn_position(preview_instance, cursor)

func _input(event: InputEvent) -> void:
	if !is_dragging_machine:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
			_finish_drag(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()

func _select_type(machine_type: MachineInventoryData.MachineType) -> void:
	if inventory_data == null or inventory_data.has(machine_type):
		selected_type = machine_type
		_update_menu_contents()

func _place_selected_machine() -> void:
	if !_is_edit_mode():
		_update_menu_contents()
		return

	if inventory_data != null and !inventory_data.consume(selected_type):
		_update_menu_contents()
		return

	var machine := _instantiate_machine(selected_type)
	if machine == null:
		if inventory_data != null:
			inventory_data.add(selected_type, 1)
		_update_menu_contents()
		return

	_set_spawn_position(machine, get_global_mouse_position())

	spawn_parent.add_child(machine)
	_apply_mode_to_spawned_deferred(machine)

	if inventory_data != null:
		selected_type = _first_available_type(selected_type)

	_update_menu_contents()

func _first_available_type(fallback: MachineInventoryData.MachineType) -> MachineInventoryData.MachineType:
	if inventory_data == null:
		return fallback

	var available := inventory_data.get_available_types()
	if available.is_empty():
		return fallback

	if available.has(fallback):
		return fallback

	return available[0] as MachineInventoryData.MachineType

func _refresh_preview_instance() -> void:
	if preview_instance != null:
		preview_instance.queue_free()
		preview_instance = null

	if !is_dragging_machine:
		return

	if inventory_data != null and !inventory_data.has(selected_type):
		return

	preview_instance = _instantiate_machine(selected_type)
	if preview_instance == null:
		return

	add_child(preview_instance)
	_disable_preview_collisions(preview_instance)
	_set_preview_alpha(preview_instance)
	_set_spawn_position(preview_instance, get_global_mouse_position())

func _instantiate_machine(machine_type: MachineInventoryData.MachineType) -> Node:
	var scene := _scene_for_type(machine_type)
	if scene == null:
		return null
	return scene.instantiate()

func _scene_for_type(machine_type: MachineInventoryData.MachineType) -> PackedScene:
	match machine_type:
		MachineInventoryData.MachineType.MARBLE:
			return marble_scene
		MachineInventoryData.MachineType.MOUSE:
			return mouse_scene
		MachineInventoryData.MachineType.ERASER:
			return eraser_scene
	return null

func _disable_preview_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).input_pickable = false
	if node is PhysicsBody2D:
		(node as PhysicsBody2D).collision_layer = 0
		(node as PhysicsBody2D).collision_mask = 0
	if node is RigidBody2D:
		(node as RigidBody2D).freeze = true

	for child in node.get_children():
		_disable_preview_collisions(child)

func _set_preview_alpha(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).modulate.a = preview_alpha

	for child in node.get_children():
		_set_preview_alpha(child)

func _create_left_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	menu_panel.offset_right = menu_width
	menu_panel.offset_left = 0
	menu_panel.offset_top = 0
	menu_panel.offset_bottom = 0
	menu_layer.add_child(menu_panel)

	menu_content = VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu_content)

	menu_title_label = Label.new()
	menu_title_label.text = "Inventory"
	menu_content.add_child(menu_title_label)

	for machine_type in [
		MachineInventoryData.MachineType.MARBLE,
		MachineInventoryData.MachineType.MOUSE,
		MachineInventoryData.MachineType.ERASER
	]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_down.connect(_on_machine_button_down.bind(machine_type))
		menu_content.add_child(button)

		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_top = 6
		content.offset_right = -6
		content.offset_bottom = -6
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 4)
		button.add_child(content)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _get_machine_preview_texture(machine_type)
		content.add_child(icon)

		var button_label := Label.new()
		button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(button_label)

		menu_buttons[machine_type] = button
		menu_button_labels[machine_type] = button_label

	var hint_label := Label.new()
	hint_label.text = "Hold left mouse on an item,\ndrag into the world, release to drop."
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_content.add_child(hint_label)

func _attach_game_mode_controls_to_menu() -> void:
	if menu_content == null:
		return

	if game_mode_controller == null:
		return

	var game_mode_button := game_mode_controller.get_node_or_null("Button") as Button
	if game_mode_button == null:
		return

	if game_mode_button.get_parent() != menu_content:
		game_mode_button.reparent(menu_content)
	menu_content.move_child(game_mode_button, 0)

	game_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_mode_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var mode_label := game_mode_button.get_node_or_null("Label") as Label
	if mode_label != null:
		mode_label.visible = false

func _update_menu_contents() -> void:
	var edit_mode := _is_edit_mode()

	if menu_title_label != null:
		if !edit_mode:
			menu_title_label.text = "Inventory (Play mode)"
		elif is_dragging_machine:
			menu_title_label.text = "Inventory (Dragging %s)" % _type_name(selected_type)
		else:
			menu_title_label.text = "Inventory"

	for machine_type in menu_buttons.keys():
		var button: Button = menu_buttons[machine_type]
		var button_label: Label = menu_button_labels[machine_type]
		var amount := 0
		if inventory_data != null:
			amount = inventory_data.get_amount(machine_type)

		if button_label != null:
			button_label.text = "%s (%d)" % [_type_name(machine_type), amount]
		button.disabled = !edit_mode or amount <= 0

func _on_machine_button_down(machine_type: MachineInventoryData.MachineType) -> void:
	if !_is_edit_mode():
		return

	_select_type(machine_type)
	if inventory_data != null and !inventory_data.has(machine_type):
		return

	is_dragging_machine = true
	global_position = get_global_mouse_position()
	_refresh_preview_instance()
	_update_menu_contents()

func _finish_drag(viewport_position: Vector2) -> void:
	var should_place := !_is_point_over_menu(viewport_position)
	if should_place:
		_place_selected_machine()

	is_dragging_machine = false
	_refresh_preview_instance()
	_update_menu_contents()

func _cancel_drag() -> void:
	is_dragging_machine = false
	_refresh_preview_instance()
	_update_menu_contents()

func _is_point_over_menu(viewport_position: Vector2) -> bool:
	if menu_panel == null:
		return false
	return menu_panel.get_global_rect().has_point(viewport_position)

func _type_name(machine_type: MachineInventoryData.MachineType) -> String:
	match machine_type:
		MachineInventoryData.MachineType.MARBLE:
			return "Marble"
		MachineInventoryData.MachineType.MOUSE:
			return "Mouse"
		MachineInventoryData.MachineType.ERASER:
			return "Eraser"
	return "Unknown"

func _is_edit_mode() -> bool:
	if game_mode_controller == null:
		return true
	return game_mode_controller.current_mode == GameMode.MachineGameMode.EDIT

func _apply_mode_to_spawned_deferred(spawned: Node) -> void:
	var mode := GameMode.MachineGameMode.EDIT
	if game_mode_controller != null:
		mode = game_mode_controller.current_mode
	call_deferred("_apply_mode_to_node", spawned, mode)

func _apply_mode_to_node(node: Node, mode: GameMode.MachineGameMode) -> void:
	if !is_instance_valid(node):
		return

	if node is MachinePhysicsObject and !(node.get_parent() is Machine):
		(node as MachinePhysicsObject).on_mode_changed(mode)

	if node is Machine:
		(node as Machine).machine_on_mode_changed(mode)

	for child in node.get_children():
		_apply_mode_to_node(child, mode)

func _set_spawn_position(node: Node, target_position: Vector2) -> bool:
	if node is Node2D:
		(node as Node2D).global_position = target_position
		return true

	for child in node.get_children():
		if _set_spawn_position(child, target_position):
			return true

	return false

func _get_machine_preview_texture(machine_type: MachineInventoryData.MachineType) -> Texture2D:
	var preview_item := _instantiate_machine(machine_type)
	if preview_item == null:
		return null

	var texture := _find_preview_texture(preview_item)
	preview_item.queue_free()
	return texture

func _find_preview_texture(node: Node) -> Texture2D:
	if node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		if animated.sprite_frames != null:
			var animation_name := StringName("idle")
			if !animated.sprite_frames.has_animation(animation_name):
				animation_name = animated.sprite_frames.get_animation_names()[0]
			if animated.sprite_frames.get_frame_count(animation_name) > 0:
				return animated.sprite_frames.get_frame_texture(animation_name, 0)

	if node is Sprite2D:
		return (node as Sprite2D).texture

	for child in node.get_children():
		var texture := _find_preview_texture(child)
		if texture != null:
			return texture

	return null
