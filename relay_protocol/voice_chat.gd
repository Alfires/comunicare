class_name VoiceData
extends PacketInfo

var id: int
var audio: PackedVector2Array


static func create(_id: int, _audio: PackedVector2Array) -> VoiceData:
	var info: VoiceData = VoiceData.new()
	info.packet_type = PACKET_TYPE.VOICE_DATA
	info.flag = ENetPacketPeer.FLAG_UNSEQUENCED
	info.id = _id
	info.audio = _audio
	return info

static func create_from_data(data: PackedByteArray) -> VoiceData:
	var info: VoiceData = VoiceData.new()
	info.decode(data)
	return info
	
	
func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	var audio_bytes = _encode_pcm_to_bytes(audio)
	
	data.push_back(id)
	data += audio_bytes
	
	return data


func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	audio = _decode_bytes_to_pcm(data, 2)
	



# help funcs
func _encode_pcm_to_bytes(pcm_data: PackedVector2Array) -> PackedByteArray:
	var bytes = PackedByteArray()
	var total_bytes = pcm_data.size() * 2 * 4 
	bytes.resize(total_bytes) 
	
	var offset = 0
	
	for sample in pcm_data:
		bytes.encode_float(offset, sample.x)
		offset += 4
		bytes.encode_float(offset, sample.y)
		offset += 4
	
	return bytes


func _decode_bytes_to_pcm(bytes_data: PackedByteArray, start_pos: int) -> PackedVector2Array:
	var pcm_data = PackedVector2Array()
	var pos = start_pos
	
	while pos + 7 < bytes_data.size():
		var left = bytes_data.decode_float(pos)
		pos += 4
		var right = bytes_data.decode_float(pos)
		pos += 4
		pcm_data.append(Vector2(left, right))
	
	return pcm_data
