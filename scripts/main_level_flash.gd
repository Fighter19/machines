extends CanvasLayer
class_name MainLevelFlash

@export var fade_duration: float = 0.45

@onready var flash_rect: ColorRect = $ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	flash_rect.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	flash_rect.color = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(flash_rect, "color:a", 0.0, fade_duration)
	tween.finished.connect(_finish_flash)

func _finish_flash() -> void:
	queue_free()
