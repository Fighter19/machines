extends Node2D
class_name MachinePreview

const INVENTORY_CONTENT_VERTICAL_SHIFT: float = 12.0
const SPEAKER_UNMUTED_GLYPH: String = "🔊\uFE0E"
const SPEAKER_MUTED_GLYPH: String = "🔇\uFE0E"

@export var inventory_data: MachineInventoryData
@export var spawn_parent: Node
@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")
@export var battery_scene: PackedScene
@export var eraser_scene: PackedScene = preload("res://scenes/eraser.tscn")
@export var pencil_scene: PackedScene = preload("res://scenes/pencil.tscn")
@export var inventory_bar_texture: Texture2D = preload("res://sprites/ui/inventory.png")
@export var rotate_button_texture: Texture2D = preload("res://sprites/ui/rotate.png")
@export var pin_button_texture: Texture2D
@export var ui_click_cursor_neutral_texture: Texture2D = preload("res://sprites/ui/cursor_click1.png")
@export var ui_click_cursor_pressed_texture: Texture2D = preload("res://sprites/ui/cursor_click2.png")
@export var ui_grab_cursor_neutral_texture: Texture2D = preload("res://sprites/ui/cursor_grab1.png")
# The hotspot of the click cursor
@export var ui_cursor_hotspot: Vector2 = Vector2(5, 2)
@export var speaker_icon_font: Font = preload("res://font/NotoSansSymbols2-Regular.ttf")
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
var menu_button_icons: Dictionary = {}
var menu_button_icon_slots: Dictionary = {}
var last_known_mode: int = -1
var item_action_menu: HBoxContainer
var rotate_action_button: Button
var pin_action_button: Button
var mute_audio_button: Button
var master_bus_index: int = -1
var selected_machine_object: MachinePhysicsObject
var selected_drag_target: Node2D
var was_left_mouse_pressed: bool = false

func _ready() -> void:
	add_to_group("machine_preview")

	if inventory_data == null:
		inventory_data = get_parent().find_child("MachineInventoryData", false, false) as MachineInventoryData

	if spawn_parent == null:
		spawn_parent = get_parent()
	_set_draggable_for_existing_machine_nodes(false)

	if pin_button_texture == null:
		pin_button_texture = load("res://sprites/ui/pin.png") as Texture2D
	if battery_scene == null:
		battery_scene = load("res://scenes/battery.tscn") as PackedScene

	if game_mode_controller == null:
		game_mode_controller = get_parent().find_child("GameModeController", false, false) as GameMode
	if game_mode_controller != null:
		last_known_mode = game_mode_controller.current_mode
	_apply_ui_cursor_textures()

	selected_type = _first_available_type(selected_type)
	_create_left_menu()
	_create_mute_button()
	_create_item_action_menu()
	_position_game_mode_button()
	# GameModeController may create EditButton in its own _ready after this node.
	call_deferred("_position_game_mode_button")
	_update_inventory_bar_layout()
	get_viewport().size_changed.connect(_update_inventory_bar_layout)
	_update_menu_contents()
	_refresh_preview_instance()

func _apply_ui_cursor_textures() -> void:
	if ui_grab_cursor_neutral_texture != null:
		Input.set_custom_mouse_cursor(ui_grab_cursor_neutral_texture, Input.CURSOR_DRAG, Vector2(4, 11))

	_update_ui_click_cursor_state(true)

func _update_ui_click_cursor_state(force_update: bool = false) -> void:
	var is_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if !force_update and is_pressed == was_left_mouse_pressed:
		return

	was_left_mouse_pressed = is_pressed
	var click_texture := ui_click_cursor_neutral_texture
	if is_pressed and ui_click_cursor_pressed_texture != null:
		click_texture = ui_click_cursor_pressed_texture

	if click_texture != null:
		Input.set_custom_mouse_cursor(click_texture, Input.CURSOR_POINTING_HAND, ui_cursor_hotspot)

func _process(_delta: float) -> void:
	if game_mode_controller != null and game_mode_controller.current_mode != last_known_mode:
		last_known_mode = game_mode_controller.current_mode
		_update_menu_contents()
		if !_is_edit_mode():
			clear_selected_machine_item()

	if selected_machine_object != null and !is_instance_valid(selected_machine_object):
		clear_selected_machine_item()

	if selected_drag_target != null and !is_instance_valid(selected_drag_target):
		clear_selected_machine_item()

	if is_dragging_machine and !_is_edit_mode():
		_cancel_drag()
		return

	if is_dragging_machine:
		var cursor := get_global_mouse_position()
		global_position = cursor
		if preview_instance != null:
			_set_preview_position(preview_instance, cursor)

	_update_ui_click_cursor_state()

func _input(event: InputEvent) -> void:
	if !is_dragging_machine:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
				if _is_point_over_item_action_menu(mouse_event.position):
					return
				clear_selected_machine_item()
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

	_set_draggable_for_machine_nodes(machine, true)
	_set_spawn_position(machine, get_global_mouse_position())

	spawn_parent.add_child(machine)
	_apply_mode_to_spawned_deferred(machine)

	if inventory_data != null:
		selected_type = _first_available_type(selected_type)

	_update_menu_contents()

func _set_draggable_for_machine_nodes(node: Node, enabled: bool) -> void:
	if node is MachinePhysicsObject:
		(node as MachinePhysicsObject).draggable = enabled

	for child in node.get_children():
		_set_draggable_for_machine_nodes(child, enabled)

func _set_draggable_for_existing_machine_nodes(enabled: bool) -> void:
	if spawn_parent == null:
		return

	for child in spawn_parent.get_children():
		_set_draggable_for_machine_nodes(child, enabled)

func select_machine_item(item: MachinePhysicsObject, drag_target: Node2D, viewport_position: Vector2) -> void:
	if !_is_edit_mode():
		return

	selected_machine_object = item
	selected_drag_target = drag_target
	_show_item_action_menu(viewport_position)

func select_machine_item_silent(item: MachinePhysicsObject, drag_target: Node2D) -> void:
	if !_is_edit_mode():
		return

	selected_machine_object = item
	selected_drag_target = drag_target
	_hide_item_action_menu()

func is_machine_item_selected(item: MachinePhysicsObject) -> bool:
	return selected_machine_object == item

func clear_selected_machine_item(expected_item: MachinePhysicsObject = null) -> void:
	if expected_item != null and selected_machine_object != expected_item:
		return

	selected_machine_object = null
	selected_drag_target = null
	_hide_item_action_menu()

func _create_item_action_menu() -> void:
	item_action_menu = HBoxContainer.new()
	item_action_menu.visible = false
	item_action_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	item_action_menu.mouse_filter = Control.MOUSE_FILTER_PASS
	item_action_menu.add_theme_constant_override("separation", 4)
	menu_panel.add_child(item_action_menu)

	rotate_action_button = Button.new()
	rotate_action_button.custom_minimum_size = Vector2(44, 44)
	rotate_action_button.icon = rotate_button_texture
	rotate_action_button.expand_icon = true
	rotate_action_button.tooltip_text = "Rotate 45 deg CW"
	rotate_action_button.focus_mode = Control.FOCUS_NONE
	rotate_action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rotate_action_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rotate_action_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	rotate_action_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	rotate_action_button.pressed.connect(_on_rotate_selected_pressed)
	item_action_menu.add_child(rotate_action_button)

	pin_action_button = Button.new()
	pin_action_button.custom_minimum_size = Vector2(44, 44)
	if pin_button_texture != null:
		pin_action_button.icon = pin_button_texture
		pin_action_button.expand_icon = true
	else:
		pin_action_button.text = "Pin"
		pin_action_button.custom_minimum_size = Vector2(52, 44)
	pin_action_button.toggle_mode = true
	pin_action_button.tooltip_text = "Keep rigidbody frozen during play mode"
	pin_action_button.focus_mode = Control.FOCUS_NONE
	pin_action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pin_action_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	pin_action_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	pin_action_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	pin_action_button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	pin_action_button.toggled.connect(_on_pin_selected_toggled)
	item_action_menu.add_child(pin_action_button)

func _show_item_action_menu(viewport_position: Vector2) -> void:
	if item_action_menu == null:
		return

	_sync_item_action_menu_state()

	var button_size := item_action_menu.get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var target := viewport_position + Vector2(16, -52)
	target.x = clamp(target.x, 8.0, viewport_size.x - button_size.x - 8.0)
	target.y = clamp(target.y, 8.0, viewport_size.y - button_size.y - 8.0)

	item_action_menu.position = target
	item_action_menu.visible = true

func _hide_item_action_menu() -> void:
	if item_action_menu != null:
		item_action_menu.visible = false

func _is_point_over_item_action_menu(viewport_position: Vector2) -> bool:
	if item_action_menu == null or !item_action_menu.visible:
		return false

	return item_action_menu.get_global_rect().has_point(viewport_position)

func _is_over_machine_item(viewport_position: Vector2) -> bool:
	if spawn_parent == null:
		return false

	var query := PhysicsPointQueryParameters2D.new()
	query.position = _viewport_to_world(viewport_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := get_world_2d().direct_space_state.intersect_point(query, 8)
	for hit in result:
		var hit_dict: Dictionary = hit
		var collider: Object = hit_dict.get("collider") as Object
		if collider is MachinePhysicsObject:
			return true

	return false

func _viewport_to_world(viewport_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position

func _on_rotate_selected_pressed() -> void:
	if selected_machine_object == null or !is_instance_valid(selected_machine_object):
		clear_selected_machine_item()
		return

	selected_machine_object.rotate_clockwise(45.0)

func _on_pin_selected_toggled(toggled_on: bool) -> void:
	if selected_machine_object == null or !is_instance_valid(selected_machine_object):
		clear_selected_machine_item()
		return

	if !selected_machine_object.is_rigidbody_machine():
		_sync_item_action_menu_state()
		return

	selected_machine_object.set_pinned_in_play(toggled_on)
	_sync_item_action_menu_state()

func _sync_item_action_menu_state() -> void:
	if pin_action_button == null:
		return

	var has_valid_selection := selected_machine_object != null and is_instance_valid(selected_machine_object)
	if !has_valid_selection:
		pin_action_button.set_pressed_no_signal(false)
		pin_action_button.disabled = true
		pin_action_button.tooltip_text = "Select an item"
		return

	var can_pin := selected_machine_object.is_rigidbody_machine()
	pin_action_button.disabled = !can_pin
	if can_pin:
		pin_action_button.tooltip_text = "Keep rigidbody frozen during play mode"
		pin_action_button.set_pressed_no_signal(selected_machine_object.is_pinned_in_play())
	else:
		pin_action_button.tooltip_text = "Pin only applies to rigidbody items"
		pin_action_button.set_pressed_no_signal(false)

func try_return_item_to_inventory(item_node: Node, viewport_position: Vector2) -> bool:
	if !_is_edit_mode():
		return false

	if inventory_data == null:
		return false

	if !_is_point_over_menu(viewport_position):
		return false

	var item_root := _get_instanced_scene_root(item_node)
	if selected_machine_object != null and is_instance_valid(selected_machine_object) and item_root.is_ancestor_of(selected_machine_object):
		clear_selected_machine_item()
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

	if node is Eraser:
		return MachineInventoryData.MachineType.ERASER

	var path := String(node.scene_file_path).to_lower()
	if path.ends_with("marble.tscn"):
		return MachineInventoryData.MachineType.MARBLE
	if path.ends_with("battery.tscn"):
		return MachineInventoryData.MachineType.BATTERY
	if path.ends_with("eraser.tscn"):
		return MachineInventoryData.MachineType.ERASER
	if path.ends_with("pencil.tscn"):
		return MachineInventoryData.MachineType.PENCIL

	var lower_name := String(node.name).to_lower()
	if lower_name.contains("marble"):
		return MachineInventoryData.MachineType.MARBLE
	if lower_name.contains("battery"):
		return MachineInventoryData.MachineType.BATTERY
	if lower_name.contains("eraser"):
		return MachineInventoryData.MachineType.ERASER
	if lower_name.contains("pencil"):
		return MachineInventoryData.MachineType.PENCIL

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
		MachineInventoryData.MachineType.BATTERY:
			return battery_scene
		MachineInventoryData.MachineType.ERASER:
			return eraser_scene
		MachineInventoryData.MachineType.PENCIL:
			return pencil_scene
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
	menu_content.offset_bottom = -18 - INVENTORY_CONTENT_VERTICAL_SHIFT
	menu_content.offset_top = -138 - INVENTORY_CONTENT_VERTICAL_SHIFT
	menu_content.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_content.add_theme_constant_override("separation", 10)
	menu_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(menu_content)

	menu_title_label = Label.new()
	menu_title_label.text = "Inventory"

	for machine_type in [
		MachineInventoryData.MachineType.MARBLE,
		MachineInventoryData.MachineType.BATTERY,
		MachineInventoryData.MachineType.ERASER,
		MachineInventoryData.MachineType.PENCIL
	]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 84)
		button.mouse_default_cursor_shape = Control.CURSOR_DRAG
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
		content.alignment = BoxContainer.ALIGNMENT_END
		content.add_theme_constant_override("separation", 3)
		button.add_child(content)

		var icon_slot := CenterContainer.new()
		icon_slot.custom_minimum_size = Vector2(0, 44)
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon_slot)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _get_machine_preview_texture(machine_type)
		icon_slot.add_child(icon)

		var button_label := Label.new()
		button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_label.custom_minimum_size = Vector2(0, 20)
		button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(button_label)

		menu_buttons[machine_type] = button
		menu_button_labels[machine_type] = button_label
		menu_button_icons[machine_type] = icon
		menu_button_icon_slots[machine_type] = icon_slot

func _create_mute_button() -> void:
	if menu_panel == null:
		return

	master_bus_index = AudioServer.get_bus_index("Master")

	mute_audio_button = Button.new()
	mute_audio_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mute_audio_button.offset_left = -64
	mute_audio_button.offset_right = -16
	mute_audio_button.offset_top = 14
	mute_audio_button.offset_bottom = 62
	mute_audio_button.custom_minimum_size = Vector2(48, 48)
	mute_audio_button.focus_mode = Control.FOCUS_NONE
	mute_audio_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mute_audio_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	mute_audio_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	mute_audio_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	mute_audio_button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	mute_audio_button.add_theme_color_override("font_color", Color.BLACK)
	mute_audio_button.add_theme_color_override("font_hover_color", Color.DARK_GRAY)
	# mute_audio_button.add_theme_color_override("font_pressed_color", Color.BLACK)
	# mute_audio_button.add_theme_color_override("font_disabled_color", Color.BLACK)
	if speaker_icon_font != null:
		mute_audio_button.add_theme_font_override("font", speaker_icon_font)
		mute_audio_button.add_theme_font_size_override("font_size", 30)
	mute_audio_button.pressed.connect(_on_mute_audio_button_pressed)
	menu_panel.add_child(mute_audio_button)

	_update_mute_button_label()

func _on_mute_audio_button_pressed() -> void:
	if master_bus_index < 0:
		return

	var is_muted: bool = AudioServer.is_bus_mute(master_bus_index)
	AudioServer.set_bus_mute(master_bus_index, !is_muted)
	_update_mute_button_label()

func _update_mute_button_label() -> void:
	if mute_audio_button == null:
		return

	if master_bus_index < 0:
		mute_audio_button.text = SPEAKER_UNMUTED_GLYPH
		mute_audio_button.tooltip_text = "Mute"
		return

	var is_muted: bool = AudioServer.is_bus_mute(master_bus_index)
	if is_muted:
		mute_audio_button.text = SPEAKER_MUTED_GLYPH
		mute_audio_button.tooltip_text = "Unmute"
	else:
		mute_audio_button.text = SPEAKER_UNMUTED_GLYPH
		mute_audio_button.tooltip_text = "Mute"

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
		menu_content.offset_top = -bar_height + 10 - INVENTORY_CONTENT_VERTICAL_SHIFT
		menu_content.offset_bottom = -10 - INVENTORY_CONTENT_VERTICAL_SHIFT

	for machine_type in menu_buttons.keys():
		var item_button := menu_buttons[machine_type] as Button
		if item_button == null:
			continue

		var button_height: float = clamp(bar_height - 26.0, 64.0, 90.0)
		item_button.custom_minimum_size = Vector2(112, button_height)
		var shared_icon_slot_height: float = _inventory_icon_size_for(MachineInventoryData.MachineType.MARBLE, button_height)

		var icon_slot := menu_button_icon_slots.get(machine_type) as CenterContainer
		if icon_slot != null:
			icon_slot.custom_minimum_size = Vector2(0, shared_icon_slot_height)

		var icon := menu_button_icons.get(machine_type) as TextureRect
		if icon != null:
			var icon_side := _inventory_icon_size_for(machine_type, button_height)
			icon.custom_minimum_size = Vector2(icon_side, icon_side)

	_position_game_mode_button()

func _inventory_icon_size_for(machine_type: MachineInventoryData.MachineType, button_height: float) -> float:
	# Keep pencil at the previous visual size; increase other inventory icons.
	if machine_type == MachineInventoryData.MachineType.PENCIL:
		return clamp(button_height * 0.45, 30.0, 44.0)
	return clamp(button_height * 0.90, 57.0, 84.0)

func _position_game_mode_button() -> void:
	if menu_content == null:
		return

	if game_mode_controller == null:
		return

	var play_mode_button := _get_mode_button("Button")
	if play_mode_button == null:
		return
	var edit_mode_button := _get_mode_button("EditButton")

	if play_mode_button.get_parent() != menu_panel:
		play_mode_button.reparent(menu_panel)
	if edit_mode_button != null and edit_mode_button.get_parent() != menu_panel:
		edit_mode_button.reparent(menu_panel)

	var viewport_size := get_viewport().get_visible_rect().size
	var right_margin := 18.0
	var left_margin := 8.0
	var button_gap := -26.0
	var button_side := 148.0
	var min_required_width := right_margin + left_margin + button_gap + button_side * 2.0
	if viewport_size.x < min_required_width:
		button_side = max(64.0, (viewport_size.x - right_margin - left_margin - button_gap) * 0.5)

	var bar_height := 128.0
	if inventory_background != null and inventory_background.texture != null:
		var tex_size := inventory_background.texture.get_size()
		if tex_size.x > 0.0:
			bar_height = (viewport_size.x / tex_size.x) * tex_size.y

	# Center with inventory bar, nudged slightly downward.
	var vertical_nudge := -32.0
	var bar_center_offset := -bar_height * 0.5 + vertical_nudge
	var button_top: float = bar_center_offset - button_side * 0.5
	var button_bottom: float = bar_center_offset + button_side * 0.5

	for button in [play_mode_button, edit_mode_button]:
		if button == null:
			continue
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		button.offset_bottom = button_bottom
		button.offset_top = button_top
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.custom_minimum_size = Vector2(button_side, button_side)

		var mode_label := button.get_node_or_null("Label") as Label
		if mode_label != null:
			mode_label.visible = false

	play_mode_button.offset_right = -right_margin
	play_mode_button.offset_left = play_mode_button.offset_right - button_side

	if edit_mode_button != null:
		edit_mode_button.offset_right = play_mode_button.offset_left - button_gap
		edit_mode_button.offset_left = edit_mode_button.offset_right - button_side

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

	_position_game_mode_button()
func _on_machine_button_down(machine_type: MachineInventoryData.MachineType) -> void:
	if !_is_edit_mode():
		return

	clear_selected_machine_item()

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
		var play_mode_button := _get_mode_button("Button")
		if play_mode_button != null and play_mode_button.get_global_rect().has_point(viewport_position):
			return true

		var edit_mode_button := _get_mode_button("EditButton")
		if edit_mode_button != null and edit_mode_button.get_global_rect().has_point(viewport_position):
			return true

	if mute_audio_button != null and mute_audio_button.get_global_rect().has_point(viewport_position):
		return true

	return false

func _get_mode_button(button_name: String) -> Button:
	if menu_panel != null:
		var in_menu := menu_panel.get_node_or_null(button_name) as Button
		if in_menu != null:
			return in_menu

	if game_mode_controller != null:
		var in_controller := game_mode_controller.get_node_or_null(button_name) as Button
		if in_controller != null:
			return in_controller

	return null

func _type_name(machine_type: MachineInventoryData.MachineType) -> String:
	match machine_type:
		MachineInventoryData.MachineType.MARBLE:
			return "Marble"
		MachineInventoryData.MachineType.BATTERY:
			return "Battery"
		MachineInventoryData.MachineType.ERASER:
			return "Eraser"
		MachineInventoryData.MachineType.PENCIL:
			return "Pencil"
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
