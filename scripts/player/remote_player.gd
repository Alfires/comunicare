extends CharacterBody3D

@export var user_name: String = "0"
@onready var user_name_label: Label3D = $user_name
@onready var player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var audio_stream = AudioStreamGenerator.new()
var avatar: Node = null
var avatar_generation := 0
var avatar_url := ""
var avatar_hidden := false
var avatar_loading := true
var avatar_failed := false
var placeholder: Node3D
var avatar_status: Label3D

func _ensure_placeholder():
	if is_instance_valid(placeholder): return
	placeholder = preload("res://scripts/assets/avatar_placeholder.gd").new()
	placeholder.name = "AvatarPlaceholder"
	add_child(placeholder)
	avatar_status = Label3D.new()
	avatar_status.name = "AvatarStatus"
	avatar_status.position = Vector3(0, 2.75, 0)
	avatar_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	avatar_status.font_size = 32
	add_child(avatar_status)

func _update_avatar_display():
	_ensure_placeholder()
	var stand_in = avatar_hidden or avatar_loading or avatar_failed or not is_instance_valid(avatar)
	placeholder.visible = stand_in
	placeholder.set_state(avatar_hidden, avatar_failed)
	if is_instance_valid(avatar): avatar.visible = not stand_in
	avatar_status.text = "Model blocked" if avatar_hidden else ("Model unavailable" if avatar_failed else "Downloading model")
	avatar_status.visible = stand_in and (not is_instance_valid(user_name_label) or user_name_label.visible)

func begin_avatar_loading():
	avatar_loading = true
	avatar_failed = false
	_update_avatar_display()

func avatar_load_failed():
	avatar_loading = false
	avatar_failed = true
	_update_avatar_display()

func set_avatar_hidden(value: bool):
	avatar_hidden = value
	_update_avatar_display()

func attach_avatar(model: Node3D):
	# Apply before tree attachment: async model changes cannot flash visible.
	model.visible = not avatar_hidden
	if is_instance_valid(avatar):
		remove_child(avatar)
		avatar.queue_free()
	avatar = model
	avatar.name = "avatar"
	add_child(avatar)
	avatar_loading = false
	avatar_failed = false
	_update_avatar_display()
var buffer_threshold = 3
var audio_buffers = []

var audio_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	user_name_label.text = user_name
	user_name_label.position = Vector3(0, 2.5, 0)
	user_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_update_avatar_display()
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
		_update_avatar_display()

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
	begin_avatar_loading()
	var result = await DataLoader.load_vrm_from_url(model_url)
	if result == null:
		if ticket == avatar_generation and is_inside_tree(): avatar_load_failed()
		return
	if ticket != avatar_generation or not is_inside_tree():
		result.queue_free()
		return
	attach_avatar(result)
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
