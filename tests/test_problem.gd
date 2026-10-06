extends TestCase

const Skill = ProblemGenerator.Skill


func _problem(num: int, den: int = 1) -> Problem:
	return Problem.new("test", Skill.ADD, &"test", 1, num, den)


func test_answer_is_reduced_with_positive_denominator() -> void:
	var p := _problem(6, -8)
	assert_eq([p.answer_num, p.answer_den], [-3, 4], "6/-8")
	assert_eq(p.answer_text(), "-3/4", "answer_text")
	assert_eq(_problem(10, 5).answer_text(), "2", "whole-number fraction")
	assert_eq(_problem(0, 7).answer_text(), "0", "zero")


func test_is_correct_accepts_equivalent_forms() -> void:
	var p := _problem(3, 4)
	for input in ["3/4", "6/8", "0.75", " 3/4 "]:
		assert_true(p.is_correct(input), "3/4 should accept '%s'" % input)
	var n := _problem(-8)
	for input in ["-8", "-8.0", "-16/2", "−8"]:
		assert_true(n.is_correct(input), "-8 should accept '%s'" % input)


func test_is_correct_rejects_wrong_or_malformed_input() -> void:
	var p := _problem(3, 4)
	for input in ["", "3", "0.7", "4/3", "-3/4", "3/0", "abc", "3/4/5", "--3", "1e2", "3 / 4x"]:
		assert_true(not p.is_correct(input), "3/4 should reject '%s'" % input)


func test_parse_number_rejects_overflowing_input() -> void:
	assert_eq(Problem.parse_number("9999999999999999999999"), [], "huge integer")
	assert_eq(Problem.parse_number("1/9999999999999999999999"), [], "huge denominator")


func test_answer_value() -> void:
	assert_eq(_problem(1, 4).answer_value(), 0.25, "1/4")
	assert_true(_problem(1, 4).is_integer_answer() == false, "1/4 is not an integer")
