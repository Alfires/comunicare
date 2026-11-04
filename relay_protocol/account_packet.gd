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
	var result = DecodeResult.json_object(data.slice(1), 256 * 1024)
	return result.value if result.ok else {}

func encode() -> PackedByteArray:
	var data = super.encode()
	data.append_array(JSON.stringify(values).to_utf8_buffer())
	return data
