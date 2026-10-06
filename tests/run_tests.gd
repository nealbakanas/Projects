extends SceneTree
## Headless test runner. Runs every `test_*` method in `res://tests/test_*.gd`.
##   godot --headless --script res://tests/run_tests.gd
## Exits with code 1 if any test fails.


func _initialize() -> void:
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()

	var passed := 0
	var failed := 0
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.call(name)
			if test.failures.is_empty():
				passed += 1
				print("  PASS  %s::%s" % [file, name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file, name])
				for failure in test.failures:
					print("          " + failure)
				if test.suppressed > 0:
					print("          ... and %d more" % test.suppressed)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
