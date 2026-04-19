extends Node
class_name GameMode

enum MachineGameMode
{
	PLAY,
	EDIT
}

var current_mode: MachineGameMode = MachineGameMode.PLAY
@export var game_mode_button: = Button
@export var game_mode_label: = Label

# Synchronize UI with state
func update_mode():
	if current_mode == MachineGameMode.PLAY:
		game_mode_label.text = "Mode: Play"
	else:
		game_mode_label.text = "Mode: Edit"

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
	update_mode()

# Connected to play/edit button
func _on_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		change_mode(MachineGameMode.PLAY)
	else:
		change_mode(MachineGameMode.EDIT)

func _ready() -> void:
	# current_mode needs to be on !EDIT for this to work
	change_mode(MachineGameMode.EDIT)
