class_name GetPublicSessions
extends PacketInfo

var sessions: Array

static func create(_sessions: Array) -> GetPublicSessions:
	var info: GetPublicSessions = GetPublicSessions.new()
	info.packet_type = PACKET_TYPE.GET_PUBLIC_SESSIONS
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.sessions = _sessions
	return info

static func create_from_data(data: PackedByteArray) -> GetPublicSessions:
	var info: GetPublicSessions = GetPublicSessions.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	var json_string = JSON.stringify(sessions)
	var encoded_peers = json_string.to_utf8_buffer()
	data.append_array(encoded_peers)
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var json_bytes = data.slice(1)
	var json_string = json_bytes.get_string_from_utf8()
	var values = JSON.parse_string(json_string)
	sessions = _convert_floats_to_ints(values) if values is Array else []

func _convert_floats_to_ints(value):
	if value is Dictionary:
		for key in value:
			value[key] = _convert_floats_to_ints(value[key])
	elif value is Array:
		for i in range(value.size()):
			value[i] = _convert_floats_to_ints(value[i])
	elif value is float and value == int(value):
		return int(value)
	return value
