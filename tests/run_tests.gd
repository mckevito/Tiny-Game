extends SceneTree
## Headless test runner: godot --headless --script res://tests/run_tests.gd [-- --filter=name]
## Runs every test_* method in res://tests/test_*.gd. A test returns "" on a pass or a message on a failure.
## Results go to the console and user://test_results.txt; the exit code is the number of failures.


func _init() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var lines: PackedStringArray = []
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var suite: Object = load("res://tests/" + file).new()
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var full := "%s.%s" % [file.get_basename(), test_name]
			if filter != "" and not full.contains(filter):
				continue
			var result: Variant = suite.call(test_name)
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
	quit(failed if passed + failed > 0 else 1)
