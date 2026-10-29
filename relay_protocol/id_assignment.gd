class_name IDAssingnment 
extends PacketInfo

var id: int 
var remoted_ids: Array[int]

static func create(id: int) -> IDAssingnment:
	var info: IDAssingnment = IDAssingnment.new()
	info.packet_type = PACKET_TYPE.ID_ASSINGMENT
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.id = id
	return info

static func create_from_data(data: PackedByteArray) -> IDAssingnment:
	var info: IDAssingnment = IDAssingnment.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(2 + remoted_ids.size())
	data.encode_u8(1,id)
	for i in remoted_ids.size():
		var id: int = remoted_ids[i]
		data.encode_u8(2+ i,id)
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	for i in range(2, data.size()):
		remoted_ids.append(data.decode_u8(i))
