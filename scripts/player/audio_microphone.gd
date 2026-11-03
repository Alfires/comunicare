extends Node

var audio_capture: AudioEffectCapture
var audio_player: AudioStreamPlayer
var recording_buffer := PackedFloat32Array()
var muted := true
var owns_capture := false
const BUFFER_SIZE = 960
const MAX_BACKLOG = BUFFER_SIZE * 10
const SILENCE_PEAK = 0.004

func _ready() -> void:
	if "--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		return
	if not SaveData.voice.register_capture(self):
		return
	var bus_idx = AudioServer.get_bus_index("Microphone")
	if bus_idx == -1:
		SaveData.voice.set_availability("Microphone audio bus not found")
		return
	AudioServer.set_bus_mute(bus_idx, true)
	audio_capture = AudioEffectCapture.new()
	audio_capture.buffer_length = 0.2
	AudioServer.add_bus_effect(bus_idx, audio_capture)
	owns_capture = true
	audio_player = _create_microphone_player()
	add_child(audio_player)
	SaveData.voice.set_availability("")
	set_muted(SaveData.voice.is_muted())

func _create_microphone_player() -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = "Microphone"
	player.stream = AudioStreamMicrophone.new()
	return player

func is_muted() -> bool:
	return muted

func set_muted(value: bool):
	muted = value
	_clear_buffers()
	if is_instance_valid(audio_player):
		if muted:
			audio_player.stop()
		else:
			audio_player.play()

func _clear_buffers():
	recording_buffer.clear()
	if audio_capture != null:
		audio_capture.clear_buffer()

func _can_transmit() -> bool:
	var peer = NetworkHandler.peer
	return not muted and peer != null and peer.peer != null and peer.is_connected_to_relay \
		and not NetworkHandler.current_session_id.is_empty() and not NetworkHandler.session_busy

func _process(_delta):
	if not _can_transmit():
		_clear_buffers()
		return
	_capture_audio()

func _capture_audio():
	if muted or audio_capture == null:
		return
	var available = audio_capture.get_frames_available()
	if available <= 0:
		return
	for frame in audio_capture.get_buffer(available):
		recording_buffer.append(frame.x)
	if recording_buffer.size() > MAX_BACKLOG:
		recording_buffer = recording_buffer.slice(recording_buffer.size() - MAX_BACKLOG)
	while recording_buffer.size() >= BUFFER_SIZE:
		var packet_audio = recording_buffer.slice(0, BUFFER_SIZE)
		recording_buffer = recording_buffer.slice(BUFFER_SIZE)
		_send_voice(packet_audio)

func _send_voice(packet_audio: PackedFloat32Array):
	if not _can_transmit():
		return
	var peak := 0.0
	var gain = SaveData.store.get_value("audio.microphone_gain")
	var adjusted = packet_audio.duplicate()
	for index in adjusted.size():
		adjusted[index] = clampf(adjusted[index] * float(gain if gain != null else 1.0), -1, 1)
		peak = maxf(peak, absf(adjusted[index]))
	var threshold = SaveData.store.get_value("audio.voice_threshold")
	if peak >= float(threshold if threshold != null else SILENCE_PEAK):
		_transmit_voice(adjusted)

func _transmit_voice(packet_audio: PackedFloat32Array):
	VoiceData.create(0, packet_audio).sent(NetworkHandler.peer.peer)

func _exit_tree():
	if is_instance_valid(audio_player):
		audio_player.stop()
	_clear_buffers()
	if owns_capture:
		var bus_idx = AudioServer.get_bus_index("Microphone")
		if bus_idx >= 0:
			for index in range(AudioServer.get_bus_effect_count(bus_idx) - 1, -1, -1):
				if AudioServer.get_bus_effect(bus_idx, index) == audio_capture:
					AudioServer.remove_bus_effect(bus_idx, index)
	SaveData.voice.unregister_capture(self)
