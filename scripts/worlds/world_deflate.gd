extends RefCounted
## Bounded RFC1951 decoder. Malformed input is data failure, not engine error.
var input := PackedByteArray()
var output := PackedByteArray()
var bit_position := 0
var maximum := 0
var error := ""
var fuel := 0
const LENGTH_BASE = [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258]
const LENGTH_BITS = [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0]
const DIST_BASE = [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577]
const DIST_BITS = [0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13]

func decode(bytes: PackedByteArray, max_bytes: int) -> Dictionary:
	input = bytes
	output = PackedByteArray()
	bit_position = 0
	maximum = max_bytes
	error = ""
	fuel = mini(64000000, max_bytes * 4 + bytes.size() * 16 + 1024)
	var final = false
	while not final and error.is_empty():
		final = _bits(1) == 1
		var kind = _bits(2)
		if kind == 0:
			bit_position = ((bit_position + 7) / 8) * 8
			var count = _bits(16)
			if (count ^ _bits(16)) != 65535:
				error = "Invalid stored deflate block"
				break
			for index in count:
				_append(_bits(8))
				if not error.is_empty(): break
		elif kind in [1, 2]:
			var lengths: Array = []
			var distances: Array = []
			if kind == 1:
				for index in 288: lengths.append(8 if index < 144 else 9 if index < 256 else 7 if index < 280 else 8)
				distances.resize(32)
				distances.fill(5)
			else:
				var literal_count = _bits(5) + 257
				var distance_count = _bits(5) + 1
				var code_count = _bits(4) + 4
				var order = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]
				var code_lengths: Array = []
				code_lengths.resize(19)
				code_lengths.fill(0)
				for index in code_count: code_lengths[order[index]] = _bits(3)
				var tree = _tree(code_lengths)
				var combined: Array = []
				while combined.size() < literal_count + distance_count and error.is_empty():
					var symbol = _symbol(tree)
					if symbol < 16:
						combined.append(symbol)
					else:
						var repeat = 0
						var value = 0
						if symbol == 16:
							if combined.is_empty():
								error = "Missing repeated code length"
								break
							value = combined.back()
							repeat = _bits(2) + 3
						elif symbol == 17: repeat = _bits(3) + 3
						elif symbol == 18: repeat = _bits(7) + 11
						else:
							error = "Invalid code-length symbol"
							break
						if combined.size() + repeat > literal_count + distance_count:
							error = "Code length overflow"
							break
						for index in repeat: combined.append(value)
				lengths = combined.slice(0, literal_count)
				distances = combined.slice(literal_count)
			if not error.is_empty(): break
			if lengths.size() <= 256 or lengths[256] == 0:
				error = "Missing deflate end code"
				break
			var literal_tree = _tree(lengths)
			var distance_tree = _tree(distances)
			while error.is_empty():
				var symbol = _symbol(literal_tree)
				if not error.is_empty(): break
				if symbol == 256: break
				if symbol < 256:
					_append(symbol)
				elif symbol <= 285:
					var length = LENGTH_BASE[symbol - 257] + _bits(LENGTH_BITS[symbol - 257])
					var distance_code = _symbol(distance_tree)
					if distance_code < 0 or distance_code >= 30:
						error = "Invalid deflate distance code"
						break
					var distance = DIST_BASE[distance_code] + _bits(DIST_BITS[distance_code])
					if distance > output.size() or output.size() + length > maximum:
						error = "Deflate output/distance budget exceeded"
						break
					for index in length: _append(output[output.size() - distance])
				else:
					error = "Reserved deflate code"
		else:
			error = "Reserved deflate block"
	if error.is_empty() and (bit_position + 7) / 8 != input.size(): error = "Trailing deflate payload"
	return {"ok": error.is_empty(), "bytes": output if error.is_empty() else PackedByteArray(), "error": error}

func _bits(count: int) -> int:
	fuel -= count + 1
	if fuel < 0 or bit_position + count > input.size() * 8:
		error = "Truncated deflate stream or work budget exceeded"
		return 0
	var value = 0
	for bit in count:
		value |= ((int(input[bit_position >> 3]) >> (bit_position & 7)) & 1) << bit
		bit_position += 1
	return value

func _append(value: int):
	fuel -= 1
	if output.size() >= maximum or fuel < 0:
		error = "Deflate output/work budget exceeded"
		return
	output.append(value)

func _tree(lengths: Array) -> Dictionary:
	var counts: Array = []
	counts.resize(16)
	counts.fill(0)
	for length in lengths:
		if length < 0 or length > 15:
			error = "Invalid Huffman length"
			return {}
		if length > 0: counts[length] += 1
	var code = 0
	var next: Array = []
	next.resize(16)
	next.fill(0)
	for bits in range(1, 16):
		code = (code + counts[bits - 1]) << 1
		if code + counts[bits] > 1 << bits:
			error = "Oversubscribed Huffman tree"
			return {}
		next[bits] = code
	var result: Dictionary = {}
	for symbol in lengths.size():
		var length: int = lengths[symbol]
		if length == 0: continue
		var original: int = next[length]
		next[length] += 1
		var reversed = 0
		for bit in length: reversed = (reversed << 1) | ((original >> bit) & 1)
		result[(length << 16) | reversed] = symbol
	return result

func _symbol(tree: Dictionary) -> int:
	var code = 0
	for length in range(1, 16):
		code |= _bits(1) << (length - 1)
		if not error.is_empty(): return -1
		var key = (length << 16) | code
		if tree.has(key): return tree[key]
	error = "Unknown Huffman code"
	return -1
