extends "res://scripts/multiplayer/relay.gd"
var voice_received := 0
var voice_sender := -1
var voice_bytes := 0
func peer_connected(peer: ENetPacketPeer):
	super.peer_connected(peer)
	# This fixture tests instance routing, not adaptive congestion control. Tiny
	# loopback RTT fluctuations during RSA/setup can reduce throttle to zero and
	# suppress every unreliable packet for the short acceptance window.
	# Keep transport unreliable; never alter production relay configuration.
	peer.throttle_configure(5000, 2, 0)
func on_packed(sender: int, bytes: PackedByteArray):
	if not bytes.is_empty() and bytes[0] == PacketInfo.PACKET_TYPE.VOICE_DATA:
		voice_received += 1
		voice_sender = sender
		voice_bytes = bytes.size()
	super.on_packed(sender, bytes)
