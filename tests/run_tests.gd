extends SceneTree
## Headless test runner: godot --headless --script res://tests/run_tests.gd [-- --filter=name]
## Runs every test_* method in res://tests/test_*.gd. A test returns "" on a pass or a message on a failure.
## Results go to the console and user://test_results.txt; the exit code is the number of failures.
## Tests run after the first frame, so a test can add nodes under `root` and their _ready runs at once.
## A test may await (frames, signals), for example to let two camps talk over the network.
## A script error (a call on null, a bad index) doesn't stop a GDScript function, so a test that hit one could still
## return "" and pass. The runner listens to the engine's log and fails any test during which a script error was
## logged (errors a test raises on purpose with push_error are not script errors).

class ScriptErrors extends Logger:
	var count := 0
	var first := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			count += 1
			if first == "":
				first = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass



func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	var lines: PackedStringArray = []
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			lines.append("FAIL %s: does not load (parse error)" % file)
			continue
		var suite: Object = script.new()
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var full := "%s.%s" % [file.get_basename(), test_name]
			if filter != "" and not full.contains(filter):
				continue
			var before := errors.count
			errors.first = ""
			var result: Variant = await suite.call(test_name)
			if errors.count > before and result is String and result == "":
				result = "script error: " + errors.first
			if result is String and result == "":
				passed += 1
				lines.append("PASS " + full)
			else:
				failed += 1
				lines.append("FAIL %s: %s" % [full, str(result)])
	lines.append("%d passed, %d failed" % [passed, failed])
	var report := "\n".join(lines)
	print(report)
	var out := FileAccess.open("user://test_results.txt", FileAccess.WRITE)
	if out:
		out.store_string(report + "\n")
	OS.remove_logger(errors)
	quit(failed if passed + failed > 0 else 1)
