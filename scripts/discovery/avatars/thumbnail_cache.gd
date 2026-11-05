extends RefCounted
## PNG/JPEG only; compressed and header dimensions bounded BEFORE native decode.
const MAX_BYTES = 2 * 1024 * 1024
const MAX_DIMENSION = 2048
var entries: Dictionary = {}
const TTL_MSEC = 300000

func _u32be(bytes: PackedByteArray, at: int) -> int:
	return (int(bytes[at]) << 24) | (int(bytes[at + 1]) << 16) | (int(bytes[at + 2]) << 8) | int(bytes[at + 3])

func decode(bytes: PackedByteArray) -> ImageTexture:
	if bytes.size() < 24 or bytes.size() > MAX_BYTES: return null
	var width := 0
	var height := 0
	var png = bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if png:
		if bytes.slice(12, 16).get_string_from_ascii() != "IHDR": return null
		width = _u32be(bytes, 16)
		height = _u32be(bytes, 20)
	elif bytes[0] == 255 and bytes[1] == 216:
		var offset := 2
		while offset + 4 < bytes.size():
			if bytes[offset] != 255: return null
			while offset < bytes.size() and bytes[offset] == 255: offset += 1
			if offset + 2 >= bytes.size(): return null
			var marker = bytes[offset]
			offset += 1
			if marker in [0xd8, 0xd9] or marker in range(0xd0, 0xd8): continue
			var length = (int(bytes[offset]) << 8) | int(bytes[offset + 1])
			if length < 2 or offset + length > bytes.size(): return null
			if marker in [0xc0, 0xc1, 0xc2]:
				if length < 7: return null
				height = (int(bytes[offset + 3]) << 8) | int(bytes[offset + 4])
				width = (int(bytes[offset + 5]) << 8) | int(bytes[offset + 6])
				break
			offset += length
	else: return null
	if width < 1 or height < 1 or width > MAX_DIMENSION or height > MAX_DIMENSION: return null
	var image = Image.new()
	var error = image.load_png_from_buffer(bytes) if png else image.load_jpg_from_buffer(bytes)
	if error != OK: return null
	if image.get_width() > 256 or image.get_height() > 256:
		var scale = 256.0 / maxf(image.get_width(), image.get_height())
		image.resize(maxi(1, int(image.get_width() * scale)), maxi(1, int(image.get_height() * scale)))
	return ImageTexture.create_from_image(image)

func get_texture(key: String) -> ImageTexture:
	var entry: Dictionary = entries.get(key, {})
	if entry.is_empty() or Time.get_ticks_msec() - entry.at > TTL_MSEC:
		entries.erase(key)
		return null
	return entry.texture

func store(key: String, texture: ImageTexture):
	if texture == null: return
	if entries.size() >= 64: entries.erase(entries.keys()[0])
	entries[key] = {"texture": texture, "at": Time.get_ticks_msec()}
