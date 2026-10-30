extends CharacterBody3D

@export var user_name: String = "0"
@onready var user_name_label: Label3D = $user_name
@onready var player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var audio_stream = AudioStreamGenerator.new()
var avatar: Node = null
var buffer_threshold = 3
var audio_buffers = []

var audio_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	load_player_model(SaveData.data["default_avatar"])
	
	_setup_playback()


func load_player_model(model_url: String):
	if avatar != null:
		remove_child(avatar)
		avatar.queue_free()
	avatar = await DataLoader.load_vrm_from_url(model_url)
	avatar.name = "avatar"
	add_child(avatar)
	await get_tree().process_frame
	# username shoud be there 
	user_name_label.text = user_name
	user_name_label.position = avatar.position + Vector3(0,2.5,0)
	print("remote player model loaded")


func _setup_playback() -> void:
	var audio_generator = AudioStreamGenerator.new()
	audio_generator.mix_rate = AudioServer.get_mix_rate()
	audio_generator.buffer_length = 0.1
	
	player.stream = audio_generator
	player.play()
	
	audio_playback = player.get_stream_playback()

func _play_audio(samples: PackedFloat32Array) -> void:
	if audio_playback == null:
		return

	var frames := PackedVector2Array()
	frames.resize(samples.size())
	for i in samples.size():
		var s := samples[i]
		frames[i] = Vector2(s, s)
	audio_playback.push_buffer(frames)
