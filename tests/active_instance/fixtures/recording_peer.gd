extends RelayPeer

# Observe actual wire packets without replacing authentication, dispatch or
# management behavior. Missing packet types are checked before any new requests.
var received: Dictionary = {}
var service_admissions := true
var raw_voice_packets := 0

func on_packet(bytes: PackedByteArray):
	if not service_admissions and not bytes.is_empty() and bytes[0] == PacketInfo.PACKET_TYPE.ADMISSION_QUERY:
		return # Simulate an old/unavailable moderator, not an approval.
	if not bytes.is_empty():
		var type = bytes.decode_u8(0)
		if type == PacketInfo.PACKET_TYPE.VOICE_DATA: raw_voice_packets += 1
		for name in ["INSTANCE_SNAPSHOT", "INSTANCE_RESULT", "INSTANCE_EVICTED"]:
			if PacketInfo.PACKET_TYPE.get(name, -1) == type:
				if not received.has(name):
					received[name] = []
				received[name].append(AccountPacket.parse(bytes))
	super.on_packet(bytes)

func latest(name: String) -> Dictionary:
	var values: Array = received.get(name, [])
	return values.back() if not values.is_empty() else {}
