class_name VoiceData
extends PacketInfo

var id: int
var audio: PackedFloat32Array


static func create(_id: int, _audio: PackedFloat32Array) -> VoiceData:
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
	data.append(id & 0xFF)
	var count := audio.size()
	data.resize(2 + count * 2)
	for i in count:
		var s16 := int(clampf(audio[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(2 + i * 2, s16)
	return data


func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	var pcm_bytes := data.slice(2)
	audio = PackedFloat32Array()
	audio.resize(pcm_bytes.size() / 2)
	for i in audio.size():
		audio[i] = float(pcm_bytes.decode_s16(i * 2)) / 32767.0
