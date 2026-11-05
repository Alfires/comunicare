extends Node
## Linux Secret Service via secret-tool; never a plaintext-file fallback.
var worker: Thread
const EXECUTABLE = "/usr/bin/secret-tool"

func available() -> bool:
	return OS.get_name() == "Linux" and FileAccess.file_exists(EXECUTABLE)

func _command(mode: String, account: String, source: String, origin: String, secret: String) -> Dictionary:
	var attributes = ["application", "comunicare-avatar-browser", "account", account, "source", source, "origin", origin]
	var args: Array = [mode]
	if mode == "store": args.append("--label=Comunicare custom avatar API")
	args.append_array(attributes)
	var info = OS.execute_with_pipe(EXECUTABLE, PackedStringArray(args), true)
	if info.is_empty(): return {"ok": false}
	if mode == "store":
		info.stdio.store_string(secret + "\n")
		info.stdio.flush()
	var deadline = Time.get_ticks_msec() + 15000
	while OS.is_process_running(info.pid) and Time.get_ticks_msec() < deadline: OS.delay_msec(10)
	if OS.is_process_running(info.pid): OS.kill(info.pid); return {"ok": false}
	var output: String = info.stdio.get_as_text().strip_edges()
	return {"ok": OS.get_process_exit_code(info.pid) == 0, "token": output if mode == "lookup" else ""}

func perform(mode: String, account: String, source: String, origin: String, secret: String = "") -> Dictionary:
	if not available() or worker != null or mode not in ["store", "lookup", "clear"]: return {"ok": false}
	if account.is_empty() or source.is_empty() or not origin.begins_with("https://"): return {"ok": false}
	if "\n" in secret or secret.length() > 4096: return {"ok": false}
	worker = Thread.new()
	if worker.start(_command.bind(mode, account, source, origin, secret)) != OK: worker = null; return {"ok": false}
	while worker.is_alive(): await get_tree().process_frame
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	return result

func _exit_tree():
	if worker != null:
		worker.wait_to_finish()
		worker = null
