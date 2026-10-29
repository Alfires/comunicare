class_name PlayerData
extends PacketInfo

var id: int
var possition: Vector3

static func create(_id: int, position: Vector3) -> PlayerData:
	var info: PlayerData = PlayerData.new()
	info.packet_type = PACKET_TYPE.PLAYER_DATA
	info.flag = ENetPacketPeer.FLAG_UNSEQUENCED
	info.id = _id
	info.possition = position
	return info

static func create_from_data(data: PackedByteArray) -> PlayerData:
	var info: PlayerData = PlayerData.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(14)
	data.encode_u8(1,id)
	data.encode_float(2,possition.x)
	data.encode_float(6,possition.y)
	data.encode_float(10,possition.z)
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	possition = Vector3(data.decode_float(2),data.decode_float(6),data.decode_float(10))
	
