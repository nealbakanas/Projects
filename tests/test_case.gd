class_name TestCase
extends RefCounted
## Base class for tests. Assertions record failures instead of stopping,
## so one run reports everything that is wrong.

const MAX_REPORTED := 10

var failures: Array[String] = []
var suppressed := 0


func fail(message: String) -> void:
	if failures.size() < MAX_REPORTED:
		failures.append(message)
	else:
		suppressed += 1


func assert_true(condition: bool, message: String) -> bool:
	if not condition:
		fail(message)
	return condition


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected:
		fail("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
		return false
	return true
