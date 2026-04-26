extends Node
class_name Marble

const SILENT_DB: float = -80.0

@export var roll_volume_scale: float = 0.15
@export var transition_volume_scale: float = 0.15
@export var required_contact_time: float = 0.06
@export var start_linear_speed: float = 10.0
@export var stop_linear_speed: float = 5.0
@export var near_stop_linear_speed: float = 7.0
@export var velocity_check_interval: float = 0.06
@export var transition_to_roll_delay: float = 0.05
@export var roll_fade_in_time: float = 0.4
@export var roll_fade_out_time: float = 0.4

@onready var rigid_body: RigidBody2D = $RigidBody2D
@onready var roll_player: AudioStreamPlayer2D = $RigidBody2D/AudioStreamPlayer2D
@onready var transition_player: AudioStreamPlayer2D = $RigidBody2D/TransitionAudioStreamPlayer2D

var is_rolling: bool = false
var contact_time: float = 0.0
var no_contact_time: float = 0.0
var velocity_check_elapsed: float = 0.0
var audio_tween: Tween
var volume_tween: Tween

func _ready() -> void:
	if roll_player == null or transition_player == null:
		return
	roll_player.volume_db = SILENT_DB
	transition_player.volume_db = linear_to_db(max(transition_volume_scale, 0.001))


func _physics_process(delta: float) -> void:
	var is_touching := rigid_body.get_contact_count() > 0
	var linear_speed := rigid_body.linear_velocity.length()

	if is_touching:
		contact_time += delta
		no_contact_time = 0.0
	else:
		contact_time = 0.0
		no_contact_time += delta

	var can_start_roll := is_touching \
		and contact_time >= required_contact_time \
		and linear_speed >= start_linear_speed
	var should_stop_roll := no_contact_time >= required_contact_time

	if is_rolling:
		if should_stop_roll:
			_stop_roll_sound()
		else:
			velocity_check_elapsed += delta
			if velocity_check_elapsed >= max(velocity_check_interval, 0.01):
				velocity_check_elapsed = 0.0
				_update_roll_volume(linear_speed)
	elif can_start_roll:
		_start_roll_sound()

func _start_roll_sound() -> void:
	is_rolling = true
	velocity_check_elapsed = 0.0
	if roll_player == null or transition_player == null:
		return
	_cancel_audio_tween()
	_cancel_volume_tween()
	transition_player.stop()
	transition_player.play()
	if !roll_player.playing:
		roll_player.play()
	roll_player.volume_db = SILENT_DB
	audio_tween = create_tween()
	if transition_to_roll_delay > 0.0:
		audio_tween.tween_interval(transition_to_roll_delay)
	audio_tween.tween_property(
		roll_player,
		"volume_db",
		linear_to_db(max(roll_volume_scale, 0.001)),
		roll_fade_in_time
	)
	audio_tween.finished.connect(_on_roll_fade_in_finished)

func _stop_roll_sound() -> void:
	is_rolling = false
	velocity_check_elapsed = 0.0
	if roll_player == null or transition_player == null:
		return
	_cancel_audio_tween()
	_cancel_volume_tween()
	transition_player.stop()
	transition_player.play()
	audio_tween = create_tween()
	audio_tween.tween_property(roll_player, "volume_db", SILENT_DB, roll_fade_out_time)
	audio_tween.finished.connect(_on_roll_fade_out_finished)

func _on_roll_fade_out_finished() -> void:
	audio_tween = null
	if is_rolling:
		return
	if roll_player == null:
		return
	if roll_player.playing:
		roll_player.stop()

func _on_roll_fade_in_finished() -> void:
	audio_tween = null

func _cancel_audio_tween() -> void:
	if audio_tween != null and is_instance_valid(audio_tween):
		audio_tween.kill()
	audio_tween = null

func _update_roll_volume(linear_speed: float) -> void:
	if roll_player == null:
		return
	if audio_tween != null and is_instance_valid(audio_tween):
		return

	var full_roll_db := linear_to_db(max(roll_volume_scale, 0.001))
	var target_db := full_roll_db
	if linear_speed <= near_stop_linear_speed:
		var speed_range: float = max(near_stop_linear_speed - stop_linear_speed, 0.001)
		var ratio: float = clamp((linear_speed - stop_linear_speed) / speed_range, 0.0, 1.0)
		target_db = lerp(SILENT_DB, full_roll_db, ratio)

	if absf(roll_player.volume_db - target_db) < 0.25:
		return

	_cancel_volume_tween()
	volume_tween = create_tween()
	volume_tween.tween_property(roll_player, "volume_db", target_db, max(velocity_check_interval, 0.05))

func _cancel_volume_tween() -> void:
	if volume_tween != null and is_instance_valid(volume_tween):
		volume_tween.kill()
	volume_tween = null
