class_name CreateSession 
extends PacketInfo

var session_info: Dictionary

static func create(_session_info: Dictionary) -> CreateSession:
	var info: CreateSession = CreateSession.new()
	info.packet_type = PACKET_TYPE.CREATE_SESSION
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.session_info = _session_info
	return info

static func create_from_data(data: PackedByteArray) -> CreateSession:
	var info: CreateSession = CreateSession.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	var json_string = JSON.stringify(session_info)
	var encoded_peers = json_string.to_utf8_buffer()
	data.append_array(encoded_peers)
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var json_bytes = data.slice(1)
	var json_string = json_bytes.get_string_from_utf8()
	session_info = JSON.parse_string(json_string)
	session_info = _convert_floats_to_ints(session_info)

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
