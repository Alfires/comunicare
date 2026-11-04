extends RefCounted
## Bounded ZIP32 profile: stored/raw-deflate only; no filesystem extraction.
const Data = preload("res://scripts/worlds/world_data.gd")

func read_archive(path: String, limits: Dictionary) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22 or file.get_length() > 64 * 1024 * 1024:
		return Data.failure("World archive missing or exceeds 64 MiB")
	var bytes = file.get_buffer(file.get_length())
	file.close()
	var end = bytes.size() - 22
	while end >= maxi(0, bytes.size() - 65557):
		if bytes.decode_u32(end) == 0x06054b50 and end + 22 + bytes.decode_u16(end + 20) == bytes.size(): break
		end -= 1
	if end < maxi(0, bytes.size() - 65557): return Data.failure("Missing ZIP directory")
	var count = bytes.decode_u16(end + 10)
	var directory = bytes.decode_u32(end + 16)
	var directory_size = bytes.decode_u32(end + 12)
	if bytes.decode_u16(end + 4) != 0 or bytes.decode_u16(end + 6) != 0 or bytes.decode_u16(end + 8) != count \
		or count == 65535 or count > int(limits.max_entries) or directory + directory_size != end:
		return Data.failure("Unsupported ZIP layout or entry count")
	var entries: Array = []
	var seen: Dictionary = {}
	var cursor = directory
	var total = 0
	var occupied: Array = []
	for index in count:
		if cursor + 46 > end or bytes.decode_u32(cursor) != 0x02014b50: return Data.failure("Invalid ZIP entry")
		var flags = bytes.decode_u16(cursor + 8)
		var method = bytes.decode_u16(cursor + 10)
		var packed = bytes.decode_u32(cursor + 20)
		var expanded = bytes.decode_u32(cursor + 24)
		var name_length = bytes.decode_u16(cursor + 28)
		var extra_length = bytes.decode_u16(cursor + 30)
		var comment_length = bytes.decode_u16(cursor + 32)
		var offset = bytes.decode_u32(cursor + 42)
		if name_length == 0 or name_length > 512 or cursor + 46 + name_length + extra_length + comment_length > end:
			return Data.failure("Invalid ZIP name")
		var name = bytes.slice(cursor + 46, cursor + 46 + name_length).get_string_from_utf8()
		var folder = name.ends_with("/")
		var canonical = name.trim_suffix("/") if folder else name
		if not Data.safe_path(canonical) or seen.has(canonical.to_lower()) or flags & ~0x808 != 0 \
			or not method in [0, 8] or bytes.decode_u16(cursor + 34) != 0 \
			or (bytes.decode_u32(cursor + 38) >> 16) & 0xf000 == 0xa000:
			return Data.failure("Unsafe, duplicate or unsupported ZIP entry")
		seen[canonical.to_lower()] = true
		total += expanded
		if total > int(limits.max_expanded_bytes) or expanded > 32 * 1024 * 1024 or packed > 64 * 1024 * 1024:
			return Data.failure("ZIP expanded data exceeds budget")
		if offset + 30 > directory or bytes.decode_u32(offset) != 0x04034b50 \
			or bytes.decode_u16(offset + 6) != flags or bytes.decode_u16(offset + 8) != method:
			return Data.failure("Invalid local ZIP header")
		var local_name = bytes.decode_u16(offset + 26)
		var local_extra = bytes.decode_u16(offset + 28)
		var start = offset + 30 + local_name + local_extra
		if start + packed > directory or local_name != name_length \
			or bytes.slice(offset + 30, offset + 30 + local_name) != bytes.slice(cursor + 46, cursor + 46 + name_length):
			return Data.failure("ZIP local path mismatch")
		for interval in occupied:
			if offset < interval[1] and start + packed > interval[0]: return Data.failure("Overlapping ZIP data")
		occupied.append([offset, start + packed])
		entries.append({"name": name, "folder": folder, "method": method, "start": start, "packed": packed, "expanded": expanded, "crc": bytes.decode_u32(cursor + 16)})
		cursor += 46 + name_length + extra_length + comment_length
	if cursor != end: return Data.failure("ZIP directory size mismatch")
	var files: Dictionary = {}
	for entry in entries:
		if entry.folder:
			if entry.expanded != 0: return Data.failure("Directory contains data")
			continue
		var content = bytes.slice(entry.start, entry.start + entry.packed)
		if entry.method == 8:
			var decoded = preload("res://scripts/worlds/world_deflate.gd").new().decode(content, entry.expanded)
			if not decoded.ok: return Data.failure(decoded.error)
			content = decoded.bytes
		if content.size() != entry.expanded or _crc(content) != entry.crc: return Data.failure("Invalid compressed ZIP data or checksum")
		files[entry.name] = content
	return {"ok": true, "files": files, "revision": FileAccess.get_sha256(path)}

func _crc(bytes: PackedByteArray) -> int:
	var crc: int = 0xffffffff
	for byte in bytes:
		crc ^= int(byte)
		for bit in 8:
			crc = (crc >> 1) ^ (0xedb88320 if crc & 1 else 0)
	return crc ^ 0xffffffff
