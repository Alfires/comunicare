extends Node

const DEFAULT_ICON = preload("res://themes/icons/profile.svg")
var generation := 0
var request_node: HTTPRequest
signal icon_ready(texture: Texture2D)
signal failed(message: String)

func request_icon(source: String):
	cancel()
	var ticket = generation
	icon_ready.emit(DEFAULT_ICON)
	if source.is_empty():
		return
	_start_request(source, ticket)

func cancel():
	generation += 1
	if request_node != null:
		request_node.cancel_request()
		request_node.queue_free()
		request_node = null

func _start_request(source: String, ticket: int):
	# Remote images are opt-in in visitor UI. Reject obvious local hosts; this
	# is not DNS-rebinding protection. Use trusted HTTPS sources only.
	if not source.begins_with("https://"):
		failed.emit("User icons require HTTPS; default icon retained.")
		return
	var host = source.substr(8).split("/")[0].to_lower()
	if host == "localhost" or host.begins_with("127.") or host.begins_with("192.168.") or host.begins_with("10.") or host.begins_with("["):
		failed.emit("Local network icon addresses are not supported.")
		return
	var http = HTTPRequest.new()
	request_node = http
	http.timeout = 10
	http.body_size_limit = 5 * 1024 * 1024
	http.max_redirects = 0
	add_child(http)
	if http.request(source) != OK:
		http.queue_free()
		request_node = null
		failed.emit("Icon request failed.")
		return
	var response = await http.request_completed
	http.queue_free()
	if ticket != generation:
		return
	request_node = null
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		failed.emit("Icon unavailable; default icon retained.")
		return
	var bytes: PackedByteArray = response[3]
	var texture = texture_from_bytes(bytes)
	if texture == null:
		failed.emit("Icon must be PNG, JPEG or WebP, at most 2048×2048.")
		return
	icon_ready.emit(texture)

func texture_from_bytes(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() > 5 * 1024 * 1024:
		return null
	var image = Image.new()
	var error = image.load_png_from_buffer(bytes)
	if error != OK:
		error = image.load_jpg_from_buffer(bytes)
	if error != OK:
		error = image.load_webp_from_buffer(bytes)
	if error != OK or image.get_width() > 2048 or image.get_height() > 2048:
		return null
	image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
