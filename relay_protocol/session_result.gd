class_name SessionResult
extends PacketInfo

var result: Dictionary = {}

static func create(values: Dictionary) -> SessionResult:
	var packet = SessionResult.new()
	packet.packet_type = PACKET_TYPE.SESSION_RESULT
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	packet.result = values
	return packet

static func create_from_data(data: PackedByteArray) -> SessionResult:
	var packet = SessionResult.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var data = super.encode()
	data.append_array(JSON.stringify(result).to_utf8_buffer())
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var values = JSON.parse_string(data.slice(1).get_string_from_utf8())
	if values is Dictionary:
		result = values
