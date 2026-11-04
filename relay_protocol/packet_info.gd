class_name PacketInfo

enum PACKET_TYPE {
	ID_ASSINGMENT = 0,
	CREATE_SESSION = 1,
	JOIN_SESSOIN = 2,
	GET_SESSION_PEERS = 3,
	GET_PUBLIC_SESSIONS = 4,
	SESSION_RESULT = 5,
	AUTH_HELLO = 11,
	AUTH_CHALLENGE = 12,
	AUTH_RESPONSE = 13,
	AUTH_RESULT = 14,
	PROFILE_PUBLISH = 15,
	PROFILES_SNAPSHOT = 16,
	INSTANCE_REQUEST = 17,
	INSTANCE_RESULT = 18,
	INSTANCE_SNAPSHOT = 19,
	INSTANCE_EVICTED = 20,
	ADMISSION_QUERY = 21,
	ADMISSION_REPLY = 22,
	MODERATION_POLICY = 23,
	SOCIAL_DATA = 24,
	INSTANCE_LOOKUP = 25,
	JOIN_REQUEST = 26,
	JOIN_DECISION = 27,
	ANIMATION_DATA = 28,
	WORLD_DATA = 29,
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
	
	
	
