class_name Problem
extends RefCounted
## One generated math problem: what to display, the exact answer, and which
## skill it exercises. Answers are exact rationals (num/den, reduced, den > 0)
## so fraction problems need no floating point.

var text: String
## A ProblemGenerator.Skill value. Stored as int to avoid a cyclic class reference.
var skill: int
## Fine-grained skill tag for adaptive tracking, e.g. &"mul:by_7" or &"frac:add_unlike".
var tag: StringName
var tier: int
var answer_num: int
var answer_den: int = 1

static var _number_regex := RegEx.create_from_string("^(-?)(\\d+)(?:/(\\d+)|\\.(\\d+))?$")


func _init(p_text: String, p_skill: int, p_tag: StringName, p_tier: int, num: int, den: int = 1) -> void:
	assert(den != 0, "Problem answer denominator must be non-zero")
	text = p_text
	skill = p_skill
	tag = p_tag
	tier = p_tier
	var reduced := reduce(num, den)
	answer_num = reduced[0]
	answer_den = reduced[1]


## The canonical answer as the player would write it: "12", "-8", or "3/4".
func answer_text() -> String:
	if answer_den == 1:
		return str(answer_num)
	return "%d/%d" % [answer_num, answer_den]


func answer_value() -> float:
	return float(answer_num) / float(answer_den)


func is_integer_answer() -> bool:
	return answer_den == 1


## True if the input is mathematically equal to the answer. Accepts integers,
## fractions (equivalent ones too, e.g. "6/8" for 3/4), and exact decimals ("0.75").
func is_correct(input: String) -> bool:
	var parsed := parse_number(input)
	if parsed.is_empty():
		return false
	return parsed[0] == answer_num and parsed[1] == answer_den


## Parses "12", "-8", "3/4", "-0.75" into a reduced [num, den]. Returns [] if invalid.
static func parse_number(input: String) -> Array:
	var cleaned := input.strip_edges().replace(" ", "").replace("−", "-")
	var m := _number_regex.search(cleaned)
	if m == null:
		return []
	var sign := -1 if m.get_string(1) == "-" else 1
	var whole := m.get_string(2)
	if whole.length() > 15:
		return []
	var num := sign * whole.to_int()
	var den := 1
	if m.get_string(3) != "":
		if m.get_string(3).length() > 15:
			return []
		den = m.get_string(3).to_int()
		if den == 0:
			return []
	elif m.get_string(4) != "":
		var frac_digits := m.get_string(4)
		if whole.length() + frac_digits.length() > 15:
			return []
		den = int(pow(10, frac_digits.length()))
		num = sign * (whole + frac_digits).to_int()
	return reduce(num, den)


## Returns [num, den] in lowest terms with a positive denominator.
static func reduce(num: int, den: int) -> Array:
	if den < 0:
		num = -num
		den = -den
	var g := gcd(absi(num), den)
	if g == 0:
		return [0, 1]
	@warning_ignore("integer_division")
	return [num / g, den / g]


static func gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := a % b
		a = b
		b = t
	return a
