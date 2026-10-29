class_name JoinSession 
extends PacketInfo

var session_id: String

static func create(_session_id: String) -> JoinSession:
	var info: JoinSession = JoinSession.new()
	info.packet_type = PACKET_TYPE.JOIN_SESSOIN
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.session_id = _session_id
	return info

static func create_from_data(data: PackedByteArray) -> JoinSession:
	var info: JoinSession = JoinSession.new()
	info.decode(data)
	return info
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.append_array(session_id.to_utf8_buffer() )
	return data
	
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	session_id = data.slice(1).get_string_from_utf8()
	
