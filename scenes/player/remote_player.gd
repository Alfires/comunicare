extends CharacterBody3D

@export var player_model: String = SaveData.data["plyer_model_url"]
@export var user_name: String = "0"
@onready var user_name_label: Label3D = $user_name

func _ready() -> void:
	load_player_model()

func load_player_model():
	var vrm_model = await DataLoader.load_vrm_from_url(player_model)
	add_child(vrm_model)
	await get_tree().process_frame
	# username shoud be there 
	user_name_label.text = user_name
	user_name_label.position = vrm_model.position + Vector3(0,1,0)
	print("remote player model loaded")
