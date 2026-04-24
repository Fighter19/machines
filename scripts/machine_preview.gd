extends Node2D
class_name MachinePreview

@export var inventory_data: MachineInventoryData
@export var spawn_parent: Node
@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")
@export var mouse_scene: PackedScene = preload("res://scenes/mouse.tscn")
@export var eraser_scene: PackedScene = preload("res://scenes/eraser.tscn")
@export var inventory_bar_texture: Texture2D = preload("res://sprites/ui/inventory.png")
@export var preview_alpha: float = 0.55
@export var menu_width: float = 170.0
@export var game_mode_controller: GameMode

var selected_type: MachineInventoryData.MachineType = MachineInventoryData.MachineType.MARBLE
var preview_instance: Node
var is_dragging_machine: bool = false

var menu_layer: CanvasLayer
var menu_panel: Control
var inventory_background: TextureRect
var menu_title_label: Label
var menu_content: HBoxContainer
var menu_buttons: Dictionary = {}
var menu_button_labels: Dictionary = {}
var last_known_mode: int = -1

func _ready() -> void:
	add_to_group("machine_preview")

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
	_position_game_mode_button()
	_update_inventory_bar_layout()
	get_viewport().size_changed.connect(_update_inventory_bar_layout)
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
			_set_preview_position(preview_instance, cursor)

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

func try_return_item_to_inventory(item_node: Node, viewport_position: Vector2) -> bool:
	if !_is_edit_mode():
		return false

	if inventory_data == null:
		return false

	if !_is_point_over_menu(viewport_position):
		return false

	var item_root := _get_instanced_scene_root(item_node)
	var machine_type := _machine_type_from_node(item_root)
	if machine_type == -1:
		return false

	inventory_data.add(machine_type as MachineInventoryData.MachineType, 1)
	item_root.queue_free()
	selected_type = _first_available_type(selected_type)
	_update_menu_contents()
	return true

func _get_instanced_scene_root(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.scene_file_path != "":
			return current
		current = current.get_parent()
	return node

func _machine_type_from_node(node: Node) -> int:
	if node == null:
		return -1

	if node is Mouse:
		return MachineInventoryData.MachineType.MOUSE
	if node is Eraser:
		return MachineInventoryData.MachineType.ERASER

	var path := String(node.scene_file_path).to_lower()
	if path.ends_with("marble.tscn"):
		return MachineInventoryData.MachineType.MARBLE
	if path.ends_with("mouse.tscn"):
		return MachineInventoryData.MachineType.MOUSE
	if path.ends_with("eraser.tscn"):
		return MachineInventoryData.MachineType.ERASER

	var lower_name := String(node.name).to_lower()
	if lower_name.contains("marble"):
		return MachineInventoryData.MachineType.MARBLE
	if lower_name.contains("mouse"):
		return MachineInventoryData.MachineType.MOUSE
	if lower_name.contains("eraser"):
		return MachineInventoryData.MachineType.ERASER

	return -1

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
	_set_preview_position(preview_instance, get_global_mouse_position())

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

	menu_panel = Control.new()
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(menu_panel)

	inventory_background = TextureRect.new()
	inventory_background.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	inventory_background.offset_left = 0
	inventory_background.offset_right = 0
	inventory_background.offset_bottom = 0
	inventory_background.offset_top = -160
	inventory_background.texture = inventory_bar_texture
	inventory_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inventory_background.stretch_mode = TextureRect.STRETCH_SCALE
	inventory_background.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_child(inventory_background)

	menu_content = HBoxContainer.new()
	menu_content.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	menu_content.offset_left = 20
	menu_content.offset_right = -220
	menu_content.offset_bottom = -18
	menu_content.offset_top = -138
	menu_content.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_content.add_theme_constant_override("separation", 10)
	menu_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(menu_content)

	menu_title_label = Label.new()
	menu_title_label.text = "Inventory"

	for machine_type in [
		MachineInventoryData.MachineType.MARBLE,
		MachineInventoryData.MachineType.MOUSE,
		MachineInventoryData.MachineType.ERASER
	]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 84)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.button_down.connect(_on_machine_button_down.bind(machine_type))
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		menu_content.add_child(button)

		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_top = 4
		content.offset_right = -6
		content.offset_bottom = -4
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 3)
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

func _update_inventory_bar_layout() -> void:
	if inventory_background == null:
		return

	var texture := inventory_background.texture
	if texture == null:
		return

	var tex_size := texture.get_size()
	if tex_size.x <= 0:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var bar_height := (viewport_size.x / tex_size.x) * tex_size.y

	inventory_background.offset_top = -bar_height

	if menu_content != null:
		menu_content.offset_top = -bar_height + 10
		menu_content.offset_bottom = -10

	for button in menu_buttons.values():
		var item_button := button as Button
		if item_button == null:
			continue

		var button_height: float = clamp(bar_height - 26.0, 64.0, 90.0)
		item_button.custom_minimum_size = Vector2(112, button_height)

		var content := item_button.get_child(0) as VBoxContainer
		if content != null and content.get_child_count() > 0:
			var icon := content.get_child(0) as TextureRect
			if icon != null:
				var icon_side: float = clamp(button_height * 0.45, 30.0, 44.0)
				icon.custom_minimum_size = Vector2(icon_side, icon_side)

func _position_game_mode_button() -> void:
	if menu_content == null:
		return

	if game_mode_controller == null:
		return

	var game_mode_button := game_mode_controller.get_node_or_null("Button") as Button
	if game_mode_button == null:
		return

	if game_mode_button.get_parent() != menu_panel:
		game_mode_button.reparent(menu_panel)

	game_mode_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	game_mode_button.offset_right = -18
	game_mode_button.offset_left = -218
	game_mode_button.offset_bottom = -26
	game_mode_button.offset_top = -82
	game_mode_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	game_mode_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	game_mode_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	game_mode_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	game_mode_button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())

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
	if inventory_background == null:
		return false

	if inventory_background.get_global_rect().has_point(viewport_position):
		return true

	if game_mode_controller != null:
		var game_mode_button := game_mode_controller.get_node_or_null("Button") as Button
		if game_mode_button != null and game_mode_button.get_global_rect().has_point(viewport_position):
			return true

	return false

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

func _set_preview_position(node: Node, target_position: Vector2) -> bool:
	var visual_root := _find_visual_root(node)
	if visual_root != null:
		visual_root.global_position = target_position
		return true

	return _set_spawn_position(node, target_position)

func _find_visual_root(node: Node) -> Node2D:
	if node is Sprite2D:
		var parent := node.get_parent()
		if parent is Node2D:
			return parent as Node2D

	for child in node.get_children():
		var found := _find_visual_root(child)
		if found != null:
			return found

	return null

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
