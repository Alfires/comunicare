extends CharacterBody3D

@export var user_name: String = "0"
@onready var user_name_label: Label3D = $user_name
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var audio_stream = AudioStreamGenerator.new()
var avatar: Node = null
var buffer_threshold = 3
var audio_buffers = []

const SAMPLE_RATE := 48000

func _ready() -> void:
	load_player_model(SaveData.data["default_avatar"])
	
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.2 
	audio_player.stream = gen
	audio_player.play()


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
	user_name_label.position = avatar.position + Vector3(0,5,0)
	print("remote player model loaded")

func _buffer_audio(data: PackedFloat32Array):
	if not audio_buffers:
		audio_buffers = PackedFloat32Array()
	
	# Append incoming chunk
	audio_buffers.append_array(data)
	
	# Prevent buffer overflow (max 200ms)
	if audio_buffers.size() > SAMPLE_RATE * 0.2:
		var excess = audio_buffers.size() - (SAMPLE_RATE * 0.15)
		audio_buffers = audio_buffers.slice(excess)

func _push_to_playback():
	var playback = audio_player.get_stream_playback()
	if not playback:
		return
	
	var my_id = multiplayer.get_unique_id()
	if not audio_buffers.has(my_id):
		return
	
	var buffer = audio_buffers[my_id]
	
	# Push frames as much as playback can accept
	while playback.can_push_buffer(1):  # Push one frame at a time
		if buffer.size() < 1:
			break
		
		var sample = buffer[0]
		buffer = buffer.slice(1)  # Remove front
		playback.push_frame(Vector2(sample, sample))
	
	audio_buffers = buffer
