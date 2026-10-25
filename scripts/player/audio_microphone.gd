extends Node

var audio_player: AudioStreamPlayer
var send_timer: Timer
var peer_audio_buffers = {} 
var effect: AudioEffectCapture
var mic_stream = AudioStreamMicrophone.new()

var recording := true
const SAMPLE_RATE := 48000
const CHUNK_SIZE := 960 
const BUFFER_SIZE := 4800
const TIMER_INTERVAL := 0.02



func _ready():
	var idx = AudioServer.get_bus_index("Microphone")
	effect = AudioServer.get_bus_effect(idx, 0)
	if effect:
		effect.buffer_length = 0.05
		
	send_timer = Timer.new()
	add_child(send_timer)
	send_timer.timeout.connect(_on_send_timer)
	send_timer.wait_time = TIMER_INTERVAL
	send_timer.start()
	
	#AudioServer.set_bus_mute(AudioServer.get_bus_index("Microphone"), true)


func _on_send_timer():
	if effect and effect.can_get_buffer(CHUNK_SIZE):
		var mono = effect.get_buffer(CHUNK_SIZE)
		
		var audio_data = PackedFloat32Array()
		for frame in mono:
			audio_data.append(clamp(frame.x * 2.0, -1.0, 1.0))
		
		#_buffer_audio(multiplayer.get_unique_id(), audio_data)
		NetworkHandler.sync_player_voice.rpc(audio_data)


func _process(_delta):
	if !recording: return
	#var effect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Microphone"), 0)
	if effect is not AudioEffectCapture: return
	if effect.can_get_buffer(4096):
		var buffer = effect.get_buffer(4096)
		
		var max_val = 0.0
		for sample in buffer:
			max_val = max(max_val, abs(sample.x))
			max_val = max(max_val, abs(sample.y))
		var byte_data = buffer.to_byte_array()
		var compressed_buffer = byte_data.compress(FileAccess.COMPRESSION_DEFLATE)
		
		NetworkHandler.sync_player_voice.rpc(compressed_buffer)
