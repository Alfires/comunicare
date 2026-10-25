extends Control

var settings_data = [
	{
		"id": "master_volume",
		"name": "Master Volume",
		"type": "slider",
		"default": 80,
		"apply_function": "apply_master_volume"
	},
	{
		"id": "player_name",
		"name": "Player Name",
		"type": "text",
		"default": "Player",
		"apply_type": "config",
		"apply_target": "player/name"
	},
	{
		"id": "enable_particles",
		"name": "Enable Particles",
		"type": "toggle",
		"default": true,
		"apply_type": "config",
		"apply_target": "graphics/particles"
	}
]



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var vb = VBoxContainer.new()
	
	for i in SaveData.data:
		var setting
		if typeof(i[1]) == 3: # TYPE_REAL
			setting = SpinBox.new()
			setting.value_changed.connect(Callable(self, "update_setting").bind(i))
			setting.value = i[1]
		else: # TYPE_STRING
			setting = LineEdit.new()
			setting.text_changed.connect(Callable(self, "update_setting").bind(i))
			setting.text = i[1]
		var setting_name = Label.new()
		var hb = HBoxContainer.new()
		setting_name.text = i
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_child(setting_name)
		hb.add_child(setting)
		vb.add_child(hb)
	add_child(vb)
		
func update_setting(new_value,setting):
	SaveData.data[setting] = new_value
	SaveData.save_data()
	
