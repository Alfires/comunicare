extends CharacterBody3D

@export var user_name: String = "0"
@onready var user_name_label: Label3D = $user_name
@onready var player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var audio_stream = AudioStreamGenerator.new()
var avatar: Node = null
var avatar_generation := 0
var avatar_url := ""
var buffer_threshold = 3
var audio_buffers = []

var audio_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	if DataLoader.has_signal("asset_revision_available"):
		DataLoader.asset_revision_available.connect(_asset_updated)
	if SaveData.get("store") != null:
		SaveData.store.setting_changed.connect(_setting_changed)
		_setting_changed("interface.show_nameplates", SaveData.store.get_value("interface.show_nameplates"))
	load_player_model(SaveData.data["default_avatar"])
	
	_setup_playback()

func _setting_changed(id: String, value: Variant):
	if id == "interface.show_nameplates":
		user_name_label.visible = value != false

func _exit_tree():
	if DataLoader.has_signal("asset_revision_available") and DataLoader.asset_revision_available.is_connected(_asset_updated):
		DataLoader.asset_revision_available.disconnect(_asset_updated)
	avatar_generation += 1
	if SaveData.get("store") != null and SaveData.store.setting_changed.is_connected(_setting_changed):
		SaveData.store.setting_changed.disconnect(_setting_changed)


func load_player_model(model_url: String):
	avatar_url = model_url
	avatar_generation += 1
	var ticket = avatar_generation
	var result = await DataLoader.load_vrm_from_url(model_url)
	if result == null:
		return
	if ticket != avatar_generation or not is_inside_tree():
		result.queue_free()
		return
	if is_instance_valid(avatar):
		remove_child(avatar)
		avatar.queue_free()
	avatar = result
	avatar.name = "avatar"
	add_child(avatar)
	await get_tree().process_frame
	# username shoud be there 
	user_name_label.text = user_name
	user_name_label.position = avatar.position + Vector3(0,2.5,0)
	print("remote player model loaded")

func _asset_updated(source: String, _previous: String, _revision: String):
	if source == avatar_url:
		load_player_model(source)


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
