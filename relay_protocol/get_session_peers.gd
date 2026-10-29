class_name GetSessionPeers 
extends PacketInfo

var peers: Array

static func create(_peers: Array) -> GetSessionPeers:
	var info: GetSessionPeers = GetSessionPeers.new()
	info.packet_type = PACKET_TYPE.GET_SESSION_PEERS
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.peers = _peers
	return info

static func create_from_data(data: PackedByteArray) -> GetSessionPeers:
	var info: GetSessionPeers = GetSessionPeers.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	var json_string = JSON.stringify(peers)
	var encoded_peers = json_string.to_utf8_buffer()
	data.append_array(encoded_peers)
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var json_bytes = data.slice(1)
	var json_string = json_bytes.get_string_from_utf8()
	peers = JSON.parse_string(json_string)
	peers = _convert_floats_to_ints(peers)

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
