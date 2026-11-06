extends Node
## Providers page, credentials and the custom-provider OAuth loopback flow of
## the avatar browser. Moved unchanged in behavior from avatar_browser.gd.

var browser: Control
var credential_store: Node
var oauth_listener: TCPServer
var oauth_peer: StreamPeerTCP
var oauth_buffer := ""
var oauth_id := ""
var oauth_config: Dictionary = {}
var oauth = preload("res://scripts/discovery/avatars/oauth_session.gd").new()
var oauth_exchange: HTTPRequest

func configure(owner_browser: Control):
	browser = owner_browser
	credential_store = preload("res://scripts/discovery/avatars/credential_store.gd").new()
	add_child(credential_store)

func load_preferences():
	var save = get_node_or_null("/root/SaveData")
	if save == null or save.get("profile") == null: return
	browser.account_owner = save.profile.get_local_fingerprint()
	browser.configuration_path = "user://avatars/" + browser.account_owner + ".discovery.json"
	if not FileAccess.file_exists(browser.configuration_path): return
	var file = FileAccess.open(browser.configuration_path, FileAccess.READ)
	browser.preferences_writable = false
	if file != null and file.get_length() < 65536:
		var data = JSON.parse_string(file.get_as_text())
		if data is Array:
			browser.preferences_writable = true
			for value in data:
				if not value is Dictionary or value.get("kind") != "custom" or not browser.registry.add_source(value): browser.preferences_writable = false

func _set_status(text: String):
	browser.status.text = text

func persist():
	if browser.configuration_path.is_empty(): return
	if not browser.preferences_writable:
		_set_status("Existing source preferences are unreadable; original preserved. Changes are memory-only.")
		return
	DirAccess.make_dir_recursive_absolute(browser.configuration_path.get_base_dir())
	var file = FileAccess.open(browser.configuration_path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(browser.registry.export_configuration().filter(func(item): return item.kind == "custom")))
	file.close()
	DirAccess.rename_absolute(browser.configuration_path + ".tmp", browser.configuration_path)

func _changed():
	persist()
	browser._refresh_sources()
	render()

func render():
	var registry = browser.registry
	var view = browser.results_view
	browser._cancel_pending()
	browser.generation += 1
	browser._clear()
	_set_status("Custom schema-1 API sources. Built-ins stay anonymous. Optional custom PKCE login uses your system browser; remember tokens only via the OS secret service.")
	for id in registry.sources.keys():
		var source: Dictionary = registry.sources[id]
		view.add_page_button(("Disable " if source.enabled else "Enable ") + source.name, func(): registry.sources[id].enabled = not registry.sources[id].enabled; persist(); render())
		if source.kind != "custom": continue
		if source.auth == "oauth": view.add_page_button("OAuth sign in: " + source.name, start_oauth.bind(id))
		view.add_page_button("Remember credential in OS keyring: " + source.name, remember_credential.bind(id))
		view.add_page_button("Restore from OS keyring: " + source.name, restore_credential.bind(id))
		view.add_page_button("Forget OS keyring credential: " + source.name, forget_credential.bind(id))
		var rename_field = _field(view, "Edit endpoint (clears credential)")
		rename_field.text = source.base_url
		view.add_page_button("Update endpoint: " + source.name, func():
			var updated = source.duplicate()
			updated.base_url = rename_field.text.strip_edges()
			if not registry.policy.valid_url(updated.base_url): return
			browser._cancel_pending()
			await credential_store.perform("clear", browser.account_owner, id, registry.policy.origin(source.base_url))
			registry.remove_source(id)
			registry.add_source(updated)
			_changed())
		var credential = _field(view, "New memory-only token for " + source.name)
		credential.secret = true
		view.add_page_button("Set credential / sign in: " + source.name, func(): registry.set_credentials(id, {"token": credential.text}); credential.clear())
		view.add_page_button("Test connection: " + source.name, func(): browser.source_filter.select(registry.sources.keys().find(id) + 1); browser._search(false))
		view.add_page_button("Sign out / clear credential: " + source.name, func(): forget_credential(id))
		view.add_page_button("Remove " + source.name, func():
			browser._cancel_pending()
			await credential_store.perform("clear", browser.account_owner, id, registry.policy.origin(source.base_url))
			registry.remove_source(id)
			_changed())
	var name_field = _field(view, "Custom source name")
	var endpoint = _field(view, "https://your-provider.example/catalog")
	endpoint.max_length = 4096
	var auth = OptionButton.new()
	for mode in ["none", "bearer", "api_key", "oauth"]: auth.add_item(mode)
	view.page_box.add_child(auth)
	var token = _field(view, "Optional provider token (memory only)")
	token.secret = true
	var oauth_fields: Array = []
	for placeholder in ["OAuth authorization HTTPS URL (optional)", "OAuth token HTTPS URL (optional)", "OAuth public client ID (no secret)", "OAuth scopes"]:
		oauth_fields.append(_field(view, placeholder))
	view.add_page_button("Confirm endpoint and add custom API", func():
		var id = "custom-" + str(Time.get_ticks_usec())
		if registry.add_source({"id": id, "kind": "custom", "name": name_field.text, "base_url": endpoint.text.strip_edges(), "auth": auth.get_item_text(auth.selected), "oauth": {"authorization_url": oauth_fields[0].text.strip_edges(), "token_url": oauth_fields[1].text.strip_edges(), "client_id": oauth_fields[2].text, "scope": oauth_fields[3].text}}):
			if auth.selected != 0: registry.set_credentials(id, {"token": token.text, "memory_only": true})
			_changed()
		else: _set_status("Invalid HTTPS endpoint or unsupported source configuration."))

func _field(view: Node, placeholder: String) -> LineEdit:
	var field = LineEdit.new()
	field.placeholder_text = placeholder
	field.set_meta("blocks_global_shortcuts", true)
	view.page_box.add_child(field)
	return field

func cancel():
	cancel_oauth()
	if is_instance_valid(oauth_exchange):
		oauth_exchange.cancel_request()
		oauth_exchange.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
		oauth_exchange = null

func remember_credential(id: String):
	var registry = browser.registry
	var source: Dictionary = registry.sources[id]
	if registry.get_credentials(id).get("token", "").is_empty():
		_set_status("Sign in or set a provider credential before remembering it.")
		return
	var result: Dictionary = await credential_store.perform("store", browser.account_owner, id, registry.policy.origin(source.base_url), str(registry.get_credentials(id).get("token", "")))
	_set_status("Stored in OS keyring." if result.get("ok") else "OS keyring unavailable/locked; credential remains memory-only.")

func restore_credential(id: String):
	var registry = browser.registry
	var source: Dictionary = registry.sources[id].duplicate(true)
	var result: Dictionary = await credential_store.perform("lookup", browser.account_owner, id, registry.policy.origin(source.base_url))
	if registry.sources.has(id) and registry.sources[id].base_url == source.base_url and result.get("ok"):
		registry.set_credentials(id, {"token": result.get("token", "")})
	_set_status("Keyring lookup finished; secrets are never written to source preferences.")

func forget_credential(id: String):
	var registry = browser.registry
	var source: Dictionary = registry.sources[id]
	registry.secrets.erase(id)
	browser._cancel_pending()
	browser.generation += 1
	await credential_store.perform("clear", browser.account_owner, id, registry.policy.origin(source.base_url))
	_set_status("Credential cleared from memory; keyring removal requested.")

func cancel_oauth():
	oauth.clear()
	oauth_id = ""
	if oauth_listener != null: oauth_listener.stop()
	oauth_listener = null
	if oauth_peer != null: oauth_peer.disconnect_from_host()
	oauth_peer = null
	oauth_buffer = ""

func start_oauth(id: String):
	browser._cancel_pending()
	oauth_listener = TCPServer.new()
	if oauth_listener.listen(0, "127.0.0.1") != OK:
		_set_status("Cannot open OAuth loopback callback.")
		cancel_oauth()
		return
	oauth_config = browser.registry.sources[id].oauth.duplicate()
	oauth_config.redirect_uri = "http://127.0.0.1:" + str(oauth_listener.get_local_port()) + "/callback"
	var url = oauth.begin(oauth_config)
	if url.is_empty(): cancel_oauth(); return
	oauth_id = id
	OS.shell_open(url)
	_set_status("Complete custom-provider sign in in your system browser. The callback expires in three minutes.")

func poll():
	if oauth_listener == null: return
	if Time.get_ticks_msec() > oauth.expires: cancel_oauth(); return
	if oauth_peer == null and oauth_listener.is_connection_available(): oauth_peer = oauth_listener.take_connection()
	if oauth_peer == null: return
	oauth_peer.poll()
	if oauth_peer.get_available_bytes() > 0:
		oauth_buffer += oauth_peer.get_utf8_string(mini(8192, oauth_peer.get_available_bytes()))
	if oauth_buffer.length() > 8192: cancel_oauth(); return
	if not "\r\n\r\n" in oauth_buffer: return
	var request_line = oauth_buffer.get_slice("\r\n", 0).split(" ")
	var fields := {}
	var expected_host = oauth_config.redirect_uri.trim_prefix("http://").get_slice("/", 0)
	var host := ""
	for header in oauth_buffer.split("\r\n"):
		if header.to_lower().begins_with("host:"): host = header.substr(5).strip_edges()
	if host == expected_host and request_line.size() == 3 and request_line[0] == "GET" and request_line[1].begins_with("/callback?"):
		fields = oauth.accept_callback(oauth_config.redirect_uri.get_slice("/callback", 0) + request_line[1], oauth_config)
	var body = "Return to Comunicare to check sign in."
	oauth_peer.put_data(("HTTP/1.1 200 OK\r\nContent-Length: %s\r\nConnection: close\r\n\r\n" % body.length() + body).to_utf8_buffer())
	var id = oauth_id
	cancel_oauth()
	if not fields.is_empty(): _exchange_oauth(id, fields)

func _exchange_oauth(id: String, fields: Dictionary):
	var registry = browser.registry
	if not registry.sources.has(id): return
	var ticket = browser.generation
	var request = HTTPRequest.new()
	oauth_exchange = request
	request.timeout = 20
	request.body_size_limit = 16384
	request.max_redirects = 0
	add_child(request)
	var values: Array[String] = []
	for key in fields: values.append(str(key).uri_encode() + "=" + str(fields[key]).uri_encode())
	if request.request(registry.sources[id].oauth.token_url, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, "&".join(values)) != OK:
		request.queue_free()
		return
	var response = await request.request_completed
	request.queue_free()
	oauth_exchange = null
	if ticket != browser.generation or not registry.sources.has(id): return
	var parser = JSON.new()
	if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and parser.parse(response[3].get_string_from_utf8()) == OK and parser.data is Dictionary:
		if str(parser.data.get("token_type", "Bearer")).to_lower() == "bearer" and registry.set_credentials(id, {"token": parser.data.get("access_token", "")}):
			_set_status("Signed in. Token is memory-only unless you explicitly remember it in the OS keyring.")
			return
	_set_status("OAuth exchange failed. No credential was saved.")
