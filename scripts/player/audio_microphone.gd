extends Node

var mic_stream = AudioStreamMicrophone.new()
var audio_player: AudioStreamPlayer
var recording = true

func _ready():
	var capture_effect = AudioEffectCapture.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Microphone"), capture_effect)
	
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = mic_stream
	audio_player.bus = "Microphone"
	add_child(audio_player)
	audio_player.play()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Microphone"), true)

func _process(_delta):
	if !recording: return
	var effect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Microphone"), 0)
	if effect is not AudioEffectCapture: return
	if effect.can_get_buffer(4096):
		var buffer = effect.get_buffer(4096)
		
		var max_val = 0.0
		for sample in buffer:
			max_val = max(max_val, abs(sample.x))
			max_val = max(max_val, abs(sample.y))
		
		print("Mic captured: ", max_val)
		NetworkHandler.sent_audio_to_server.rpc(buffer.to_byte_array())
