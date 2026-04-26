extends Node

@export var song_stream: AudioStream = preload("res://audio/GameSong.mp3")
@export var volume_db: float = -8.0

var player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = AudioStreamPlayer.new()
	player.name = "GameSongPlayer"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = song_stream
	player.volume_db = volume_db
	add_child(player)

	if player.stream != null and !player.playing:
		player.play()
