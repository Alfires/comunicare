class_name CreateSession 
extends PacketInfo

var mode: PacketInfo.MODE

static func create(_mode: PacketInfo.MODE) -> CreateSession:
	var info: CreateSession = CreateSession.new()
	info.packet_type = PACKET_TYPE.CREATE_SESSION
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.mode = _mode
	return info

static func create_from_data(data: PackedByteArray) -> CreateSession:
	var info: CreateSession = CreateSession.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(2)
	data.encode_u8(1,mode)
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	mode = data.decode_u8(1)
	
