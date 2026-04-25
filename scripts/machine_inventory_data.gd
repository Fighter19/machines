extends Node
class_name MachineInventoryData

enum MachineType {
	MARBLE,
	MOUSE,
	ERASER,
	PENCIL
}

@export var marble_count: int = 7
@export var mouse_count: int = 4
@export var eraser_count: int = 2
@export var pencil_count: int = 3

func get_amount(machine_type: MachineType) -> int:
	match machine_type:
		MachineType.MARBLE:
			return marble_count
		MachineType.MOUSE:
			return mouse_count
		MachineType.ERASER:
			return eraser_count
		MachineType.PENCIL:
			return pencil_count
	return 0

func has(machine_type: MachineType) -> bool:
	return get_amount(machine_type) > 0

func consume(machine_type: MachineType) -> bool:
	if !has(machine_type):
		return false

	match machine_type:
		MachineType.MARBLE:
			marble_count -= 1
		MachineType.MOUSE:
			mouse_count -= 1
		MachineType.ERASER:
			eraser_count -= 1
		MachineType.PENCIL:
			pencil_count -= 1

	return true

func add(machine_type: MachineType, amount: int = 1) -> void:
	if amount <= 0:
		return

	match machine_type:
		MachineType.MARBLE:
			marble_count += amount
		MachineType.MOUSE:
			mouse_count += amount
		MachineType.ERASER:
			eraser_count += amount
		MachineType.PENCIL:
			pencil_count += amount

func get_available_types() -> Array[int]:
	var available: Array[int] = []
	for machine_type in [MachineType.MARBLE, MachineType.MOUSE, MachineType.ERASER, MachineType.PENCIL]:
		if has(machine_type):
			available.append(machine_type)
	return available
