extends Node

var audio_capture: AudioEffectCapture
var recording_buffer: = PackedFloat32Array()
const BUFFER_SIZE = 960  # 20ms at 48kHz
const MAX_BACKLOG := BUFFER_SIZE * 10
const SILENCE_PEAK := 0.004

func _ready() -> void:
	var capture_effect = AudioEffectCapture.new()
	capture_effect.buffer_length = 0.2
	var bus_idx = AudioServer.get_bus_index("Microphone")
	if bus_idx == -1:
		push_error("Audio bus 'Microphone' not found!")
		return
	AudioServer.set_bus_mute(bus_idx, true)
	
	AudioServer.add_bus_effect(bus_idx, capture_effect, 0)
	audio_capture = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture
	audio_capture.clear_buffer()
	
	var mic_stream = AudioStreamMicrophone.new()
	var audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Microphone"
	audio_player.stream = mic_stream
	add_child(audio_player)
	audio_player.play()


func _process(_delta: float) -> void:
	_capture_audio()

func _capture_audio() -> void:
	if not audio_capture:
		return
	
	var frames_available = audio_capture.get_frames_available()
	if frames_available <= 0:
		return
	
	var frame_data = audio_capture.get_buffer(frames_available)
	for frame in frame_data:
		recording_buffer.append(frame.x)
	
	if recording_buffer.size() > MAX_BACKLOG:
		recording_buffer = recording_buffer.slice(recording_buffer.size() - MAX_BACKLOG)

	while recording_buffer.size() >= BUFFER_SIZE:
		var packet_audio := recording_buffer.slice(0, BUFFER_SIZE)
		recording_buffer = recording_buffer.slice(BUFFER_SIZE)
		_send_voice(packet_audio)

func _send_voice(packet_audio: PackedFloat32Array) -> void:
	var peer := NetworkHandler.peer
	if peer == null or peer.peer == null:
		return

	var peak := 0.0
	for s in packet_audio:
		peak = maxf(peak, absf(s))
	if peak < SILENCE_PEAK:
		return

	VoiceData.create(0, packet_audio).sent(peer.peer)
