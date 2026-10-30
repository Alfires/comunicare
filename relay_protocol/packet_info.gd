class_name PacketInfo

enum PACKET_TYPE {
	ID_ASSINGMENT = 0,
	CREATE_SESSION = 1,
	JOIN_SESSOIN = 2,
	GET_SESSION_PEERS = 3,
	GET_PUBLIC_SESSIONS = 4,
	VOICE_DATA = 9,
	PLAYER_DATA = 10
}

enum MODE {
	PUBLIC = 0,
	PRIVAT = 1,
	FRIENDS = 2,
	FRIENDSP = 3,
	REQUEST = 4,
}

var packet_type: PACKET_TYPE
var flag: int

func encode() -> PackedByteArray:
	var data: PackedByteArray
	data.resize(1)
	data.encode_u8(0, packet_type)
	return data

func decode(data: PackedByteArray) -> void:
	packet_type = data.decode_u8(0)
	
func sent(target: ENetPacketPeer):
	target.send(0,encode(), flag)
	
func broadcast(target: ENetConnection):
	target.broadcast(0,encode(), flag)
	
	
	
