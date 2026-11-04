class_name JoinSession 
extends PacketInfo

var session_id: String
var world_url: String = ""
var world_revision := ""

static func create(_session_id: String, expected_world_url: String = "", expected_revision: String = "") -> JoinSession:
	var info: JoinSession = JoinSession.new()
	info.packet_type = PACKET_TYPE.JOIN_SESSOIN
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.session_id = _session_id
	info.world_url = expected_world_url
	info.world_revision = expected_revision
	return info

static func create_from_data(data: PackedByteArray) -> JoinSession:
	var info: JoinSession = JoinSession.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.append_array(JSON.stringify({"session_id": session_id, "world_url": world_url, "world_revision": world_revision}).to_utf8_buffer())
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	if data.size() > 8192: return
	var text = data.slice(1).get_string_from_utf8()
	# Accept legacy ID-only requests as well as URL-checked joins.
	if not text.begins_with("{"):
		session_id = text
		return
	var parsed = DecodeResult.json_object(data.slice(1), 8192)
	var values = parsed.value if parsed.ok else {}
	if values is Dictionary and values.get("session_id") is String and values.get("world_url") is String:
		session_id = values.session_id
		world_url = values.world_url
		world_revision = values.get("world_revision", "") if values.get("world_revision", "") is String else "invalid"
	
