class_name AccountPacket
extends PacketInfo

var values: Dictionary = {}

static func create(type: int, data: Dictionary) -> AccountPacket:
	var packet = AccountPacket.new()
	packet.packet_type = type
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	packet.values = data
	return packet

static func parse(data: PackedByteArray) -> Dictionary:
	if data.size() < 2 or data.size() > 256 * 1024:
		return {}
	var parser = JSON.new()
	if parser.parse(data.slice(1).get_string_from_utf8()) != OK:
		return {}
	var value = parser.data
	return value if value is Dictionary else {}

func encode() -> PackedByteArray:
	var data = super.encode()
	data.append_array(JSON.stringify(values).to_utf8_buffer())
	return data
