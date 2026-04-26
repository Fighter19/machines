extends Node
class_name GameMode

enum MachineGameMode
{
	PLAY,
	EDIT
}

var current_mode: MachineGameMode = MachineGameMode.PLAY
@export var game_mode_button: Button
@export var game_mode_label: Label
@export var play_icon_texture: Texture2D = preload("res://sprites/ui/Button_Play.png")
@export var edit_icon_texture: Texture2D = preload("res://sprites/ui/Button_Edit.png")
@export var bubble_texture: Texture2D = preload("res://sprites/ui/bubble.png")
@export var bubble_frame_count: int = 4
@export var bubble_frame_size: Vector2i = Vector2i(128, 128)
@export var bubble_animation_fps: float = 14.0

var play_button: Button
var edit_button: Button
var pending_mode: int = -1

# Synchronize UI with state
func update_mode():
	if play_button == null or edit_button == null:
		return

	_set_button_state(play_button, true, current_mode == MachineGameMode.PLAY)
	_set_button_state(edit_button, false, current_mode == MachineGameMode.EDIT)

	if game_mode_label != null:
		game_mode_label.visible = false

func _set_button_state(button: Button, is_play_button: bool, is_active: bool) -> void:
	if button == null:
		return

	button.text = ""
	button.toggle_mode = false
	button.disabled = is_active

	var icon := _get_button_icon(button)
	if icon != null:
		icon.texture = play_icon_texture if is_play_button else edit_icon_texture

	var bubble := _get_button_bubble(button)
	if bubble == null:
		return

	bubble.visible = !is_active
	if is_active:
		bubble.stop()
		bubble.frame = 0

func notify_children(base: Node, new_mode: MachineGameMode):
	for child in base.get_children():
		if child is MachinePhysicsObject:
			# Notify
			(child as MachinePhysicsObject).on_mode_changed(new_mode)
			# Done, no further submachines of subobjects expected
			continue
		elif child is Machine:
			(child as Machine).machine_on_mode_changed(new_mode)
			# Same here
			continue
		else:
			# Recursively descent into all other node (not that sexy)
			# Register them on the controller (this script) in the future,
			# when they get ready, then just iterate
			notify_children(child, new_mode)

func change_mode(new_mode: MachineGameMode):
	if current_mode != new_mode:
		notify_children(get_parent(), new_mode)
	current_mode = new_mode
	pending_mode = -1
	update_mode()

# Connected to play/edit button
func _on_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		change_mode(MachineGameMode.PLAY)
	else:
		change_mode(MachineGameMode.EDIT)

func _on_play_button_down() -> void:
	_request_mode_change(MachineGameMode.PLAY)

func _on_edit_button_down() -> void:
	_request_mode_change(MachineGameMode.EDIT)

func _request_mode_change(target_mode: MachineGameMode) -> void:
	if target_mode == current_mode:
		return

	var target_button := _button_for_mode(target_mode)
	var bubble := _get_button_bubble(target_button)
	if bubble == null:
		change_mode(target_mode)
		return

	pending_mode = int(target_mode)
	bubble.visible = true
	bubble.stop()
	bubble.frame = 0
	bubble.play("pop")

func _on_bubble_animation_finished(mode: int) -> void:
	var mode_value := mode as MachineGameMode
	var button := _button_for_mode(mode_value)
	var bubble := _get_button_bubble(button)
	if bubble == null:
		if pending_mode == mode:
			change_mode(mode_value)
		return

	bubble.stop()
	bubble.frame = 0

	if pending_mode == mode:
		change_mode(mode_value)

func _button_for_mode(mode: MachineGameMode) -> Button:
	if mode == MachineGameMode.PLAY:
		return play_button
	return edit_button

func _get_button_icon(button: Button) -> TextureRect:
	if button == null:
		return null
	return button.get_node_or_null("ModeIcon") as TextureRect

func _get_button_bubble(button: Button) -> AnimatedSprite2D:
	if button == null:
		return null
	return button.get_node_or_null("BubblePop") as AnimatedSprite2D

func _sync_button_visual_positions(button: Button) -> void:
	if button == null:
		return

	var bubble := _get_button_bubble(button)
	if bubble == null:
		return

	bubble.position = button.size * 0.5

	if bubble_frame_size.x > 0 and bubble_frame_size.y > 0:
		var scale_factor: float = min(
			button.size.x / float(bubble_frame_size.x),
			button.size.y / float(bubble_frame_size.y)
		)
		bubble.scale = Vector2(scale_factor, scale_factor)

func _build_bubble_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("pop")
	frames.set_animation_speed("pop", bubble_animation_fps)
	frames.set_animation_loop("pop", false)

	if bubble_texture == null or bubble_frame_count <= 0:
		return frames

	for frame_index in bubble_frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = bubble_texture
		atlas.region = Rect2(
			frame_index * bubble_frame_size.x,
			0,
			bubble_frame_size.x,
			bubble_frame_size.y
		)
		frames.add_frame("pop", atlas)

	return frames

func _ensure_mode_buttons() -> void:
	play_button = game_mode_button
	if play_button == null:
		return

	edit_button = play_button.get_parent().get_node_or_null("EditButton") as Button
	if edit_button == null:
		edit_button = Button.new()
		edit_button.name = "EditButton"
		play_button.get_parent().add_child(edit_button)

	_ensure_mode_button_visuals(play_button, MachineGameMode.PLAY)
	_ensure_mode_button_visuals(edit_button, MachineGameMode.EDIT)

	if !play_button.button_down.is_connected(_on_play_button_down):
		play_button.button_down.connect(_on_play_button_down)
	if !edit_button.button_down.is_connected(_on_edit_button_down):
		edit_button.button_down.connect(_on_edit_button_down)

func _ensure_mode_button_visuals(button: Button, mode: MachineGameMode) -> void:
	button.text = ""
	button.toggle_mode = false

	var icon := _get_button_icon(button)
	if icon == null:
		icon = TextureRect.new()
		icon.name = "ModeIcon"
		button.add_child(icon)

	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Keep icon inside the larger bubble by reducing its effective size.
	icon.offset_left = 38
	icon.offset_top = 38
	icon.offset_right = -38
	icon.offset_bottom = -38
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = play_icon_texture if mode == MachineGameMode.PLAY else edit_icon_texture
	icon.z_index = 2

	var bubble := _get_button_bubble(button)
	if bubble == null:
		bubble = AnimatedSprite2D.new()
		bubble.name = "BubblePop"
		button.add_child(bubble)

	bubble.centered = true
	bubble.z_index = 1
	bubble.sprite_frames = _build_bubble_frames()
	bubble.animation = &"pop"
	bubble.stop()
	bubble.frame = 0

	var finished_callback := Callable(self, "_on_bubble_animation_finished").bind(int(mode))
	if !bubble.animation_finished.is_connected(finished_callback):
		bubble.animation_finished.connect(finished_callback)

	var resized_callback := Callable(self, "_sync_button_visual_positions").bind(button)
	if !button.resized.is_connected(resized_callback):
		button.resized.connect(resized_callback)

	_sync_button_visual_positions(button)

func _ready() -> void:
	_ensure_mode_buttons()

	# current_mode needs to be on !EDIT for this to work
	change_mode(MachineGameMode.EDIT)
