extends RefCounted
## Non-executing JSON/Godot-text value reader. No str_to_var/Expression/Object calls.
var source := ""
var cursor := 0
var error := ""
var fuel := 0
var json_mode := false

func parse_json(text: String) -> Dictionary:
	_reset(text, true)
	var value = _value(0)
	_space()
	if cursor != source.length(): _fail("Trailing JSON content")
	return {"ok": error.is_empty(), "value": value, "error": error}

func parse_resource(text: String) -> Dictionary:
	_reset(text, false)
	var sections: Array = []
	while error.is_empty():
		_space()
		if cursor >= source.length(): break
		if source[cursor] != "[":
			_fail("Expected scene/resource section")
			break
		cursor += 1
		var kind = _identifier()
		var attributes: Dictionary = {}
		_space()
		while error.is_empty() and cursor < source.length() and source[cursor] != "]":
			var key = _identifier()
			if attributes.has(key): _fail("Duplicate section attribute")
			_expect("=")
			attributes[key] = _value(0)
			_space()
		_expect("]")
		var properties: Dictionary = {}
		_space()
		while error.is_empty() and cursor < source.length() and source[cursor] != "[":
			var key = _identifier(true)
			if properties.has(key): _fail("Duplicate resource property")
			_expect("=")
			properties[key] = _value(0)
			_space()
		sections.append({"kind": kind, "attributes": attributes, "properties": properties})
		if sections.size() > 10000: _fail("Too many scene sections")
	return {"ok": error.is_empty(), "value": sections, "error": error}

func _reset(text: String, json: bool):
	source = text
	cursor = 0
	error = ""
	fuel = 100000
	json_mode = json
	if text.length() > 4 * 1024 * 1024: _fail("Text document too large")

func _fail(message: String):
	if error.is_empty(): error = message + " at character " + str(cursor)

func _space():
	while cursor < source.length():
		if source[cursor] in [" ", "\t", "\n", "\r"]:
			cursor += 1
		elif not json_mode and source[cursor] == ";":
			while cursor < source.length() and source[cursor] != "\n": cursor += 1
		else:
			break

func _expect(token: String):
	_space()
	if source.substr(cursor, token.length()) != token:
		_fail("Expected " + token)
	else:
		cursor += token.length()

func _identifier(property: bool = false) -> String:
	_space()
	var start = cursor
	while cursor < source.length():
		var c = source[cursor]
		if not (c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_" or (property and c == "/")): break
		cursor += 1
	if cursor == start: _fail("Expected identifier")
	return source.substr(start, cursor - start)

func _string() -> String:
	var start = cursor
	_expect("\"")
	while error.is_empty() and cursor < source.length():
		if source[cursor] == "\\":
			cursor += 2
		elif source[cursor] == "\"":
			cursor += 1
			var parser = JSON.new()
			if parser.parse(source.substr(start, cursor - start)) != OK or not parser.data is String:
				_fail("Invalid string encoding")
				return ""
			return parser.data
		else:
			if source[cursor].unicode_at(0) < 32: _fail("Control character in string")
			cursor += 1
	_fail("Unterminated string")
	return ""

func _value(depth: int) -> Variant:
	fuel -= 1
	if fuel < 0 or depth > 32:
		_fail("Value complexity limit")
		return null
	_space()
	if not error.is_empty() or cursor >= source.length():
		_fail("Missing value")
		return null
	var c = source[cursor]
	if c == "\"": return _string()
	if c == "&" and not json_mode:
		cursor += 1
		return _string()
	if c == "[" or c == "{":
		cursor += 1
		var array: Array = []
		var dictionary: Dictionary = {}
		var end = "]" if c == "[" else "}"
		_space()
		while error.is_empty() and cursor < source.length() and source[cursor] != end:
			if array.size() + dictionary.size() > 10000:
				_fail("Collection limit")
				break
			if c == "[":
				array.append(_value(depth + 1))
			else:
				var key = _value(depth + 1)
				if not key is String or dictionary.has(key):
					_fail("Invalid or duplicate dictionary key")
					break
				_expect(":")
				dictionary[key] = _value(depth + 1)
			_space()
			if cursor < source.length() and source[cursor] == end: break
			_expect(",")
			_space()
			if json_mode and cursor < source.length() and source[cursor] == end: _fail("Trailing JSON comma")
		_expect(end)
		return array if c == "[" else dictionary
	if c in "-0123456789":
		var start = cursor
		while cursor < source.length() and source[cursor] in "-+0123456789.eE": cursor += 1
		var token = source.substr(start, cursor - start)
		if token.length() > 64 or not token.is_valid_float():
			_fail("Invalid number")
			return null
		var value = token.to_float()
		if not is_finite(value): _fail("Non-finite number")
		return token.to_int() if token.is_valid_int() else value
	var name = _identifier()
	if name == "true": return true
	if name == "false": return false
	if name == "null": return null
	if json_mode:
		_fail("Unknown JSON value")
		return null
	if not name in ["Vector2", "Vector3", "Vector4", "Color", "Quaternion", "Basis", "Transform3D", "ExtResource", "SubResource", "NodePath", "PackedFloat32Array", "PackedInt32Array", "PackedVector3Array", "PackedVector2Array", "PackedColorArray"]:
		_fail("Unsupported data constructor: " + name)
		return null
	_expect("(")
	var arguments: Array = []
	_space()
	while error.is_empty() and cursor < source.length() and source[cursor] != ")":
		arguments.append(_value(depth + 1))
		_space()
		if cursor < source.length() and source[cursor] == ")": break
		_expect(",")
	_expect(")")
	return {"type": name, "args": arguments}
