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
	var parsed = DecodeResult.json_object(data.slice(1), 16 * 1024)
	var values = parsed.value if parsed.ok else {}
	if values is Dictionary:
		result = values
