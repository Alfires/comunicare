class_name PlayerData
extends PacketInfo

var id: int
var position: Vector3
var rotation: Vector3 

static func create(_id: int, _position: Vector3, _rotation: Vector3) -> PlayerData:
	var info: PlayerData = PlayerData.new()
	info.packet_type = PACKET_TYPE.PLAYER_DATA
	info.flag = ENetPacketPeer.FLAG_UNSEQUENCED
	info.id = _id
	info.position = _position
	info.rotation = _rotation
	return info

static func create_from_data(data: PackedByteArray) -> PlayerData:
	var info: PlayerData = PlayerData.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(26)
	data.encode_u8(1,id)
	data.encode_float(2,position.x)
	data.encode_float(6,position.y)
	data.encode_float(10,position.z)
	
	data.encode_float(14,rotation.x)
	data.encode_float(18,rotation.y)
	data.encode_float(22,rotation.z)
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	position = Vector3(data.decode_float(2),data.decode_float(6),data.decode_float(10))
	rotation = Vector3(data.decode_float(14),data.decode_float(18),data.decode_float(22))
