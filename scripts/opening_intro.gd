extends Control
class_name OpeningIntro

@export var next_scene_path: String = "res://scenes/main.tscn"
@export var flash_duration: float = 0.16

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var flash_rect: ColorRect = $FlashRect

var is_transitioning: bool = false

func _ready() -> void:
	flash_rect.color = Color(1, 1, 1, 0)
	video_player.finished.connect(_on_video_finished)
	video_player.play()

func _on_video_finished() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 1.0, flash_duration)
	tween.finished.connect(_go_to_main_level)

func _go_to_main_level() -> void:
	get_tree().change_scene_to_file(next_scene_path)
