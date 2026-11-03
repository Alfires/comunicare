class_name JoinSession 
extends PacketInfo

var session_id: String
var world_url: String = ""

static func create(_session_id: String, expected_world_url: String = "") -> JoinSession:
	var info: JoinSession = JoinSession.new()
	info.packet_type = PACKET_TYPE.JOIN_SESSOIN
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.session_id = _session_id
	info.world_url = expected_world_url
	return info

static func create_from_data(data: PackedByteArray) -> JoinSession:
	var info: JoinSession = JoinSession.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.append_array(JSON.stringify({"session_id": session_id, "world_url": world_url}).to_utf8_buffer())
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var text = data.slice(1).get_string_from_utf8()
	# Accept legacy ID-only requests as well as URL-checked joins.
	if not text.begins_with("{"):
		session_id = text
		return
	var values = JSON.parse_string(text)
	if values is Dictionary and values.get("session_id") is String and values.get("world_url") is String:
		session_id = values.session_id
		world_url = values.world_url
	
