class_name GetPublicSessions
extends PacketInfo

var worlds: Array

static func create(_worlds: Array) -> GetPublicSessions:
	var info: GetPublicSessions = GetPublicSessions.new()
	info.packet_type = PACKET_TYPE.GET_PUBLIC_SESSIONS
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.worlds = _worlds
	return info

static func create_from_data(data: PackedByteArray) -> GetPublicSessions:
	var info: GetPublicSessions = GetPublicSessions.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	var json_string = JSON.stringify(worlds)
	var encoded_peers = json_string.to_utf8_buffer()
	data.append_array(encoded_peers)
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var json_bytes = data.slice(1)
	var json_string = json_bytes.get_string_from_utf8()
	worlds = JSON.parse_string(json_string)
	worlds = _convert_floats_to_ints(worlds)

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
