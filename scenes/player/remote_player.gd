extends CharacterBody3D

@export var player_model: String = SaveData.data["plyer_model_url"]
@export var user_name: String = "0"
@onready var user_name_label: Label3D = $user_name
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var audio_stream = AudioStreamGenerator.new()

func _ready() -> void:
	load_player_model()
	audio_stream.mix_rate = 48000
	audio_stream.buffer_length = 10.0 
	audio_player.stream = audio_stream
	audio_player.volume_db = 0
	audio_player.play()
	

func load_player_model():
	var vrm_model = await DataLoader.load_vrm_from_url(player_model)
	add_child(vrm_model)
	await get_tree().process_frame
	# username shoud be there 
	user_name_label.text = user_name
	user_name_label.position = vrm_model.position + Vector3(0,1,0)
	print("remote player model loaded")


func play_audio(audio: PackedFloat32Array):
	var playback = audio_player.get_stream_playback()
	if playback == null:
		print("Error: Playback is null")
		return
	var frames_available = playback.get_frames_available()
	if frames_available < 4096:
		print("Warning: Buffer underrun detected, only %d frames available" % frames_available)

	var stereo_audio = PackedVector2Array()
	for i in range(0, audio.size(), 2):
		if i + 1 < audio.size():
			stereo_audio.append(Vector2(audio[i], audio[i + 1]))
		else:
			stereo_audio.append(Vector2(audio[i], 0.0))
	playback.push_buffer(stereo_audio)
	if not audio_player.playing:
		audio_player.play()
