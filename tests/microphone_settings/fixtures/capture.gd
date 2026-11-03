extends "res://scripts/player/audio_microphone.gd"

var packets: Array = []

func _create_microphone_player() -> AudioStreamPlayer:
	# Exercise real ready/lifecycle with looping silence, never a device.
	var player = AudioStreamPlayer.new()
	player.bus = "Microphone"
	var silence = AudioStreamWAV.new()
	silence.data = PackedByteArray([0, 0, 0, 0])
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 4
	player.stream = silence
	return player

func _transmit_voice(samples: PackedFloat32Array):
	packets.append(samples.duplicate())
