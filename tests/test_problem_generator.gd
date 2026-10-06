extends TestCase

const Oracle = preload("res://tests/expression_oracle.gd")
const Skill = ProblemGenerator.Skill

const SAMPLES := 400
## Longest problem text the HUD must fit at 320x180.
const MAX_TEXT_LENGTH := 20

var _pct_re := RegEx.create_from_string("^(\\d+)% of (\\d+)$")
var _call_re := RegEx.create_from_string("^(GCF|LCM)\\((\\d+), (\\d+)\\)$")
var _prime_re := RegEx.create_from_string("^next prime > (\\d+)$")
var _mod_re := RegEx.create_from_string("^(\\d+) mod (\\d+)$")
var _int_re := RegEx.create_from_string("-?\\d+")
var _unit_coefficient_re := RegEx.create_from_string("(^|[^\\d])1x")


## Every problem of every skill at every tier, for a few seeds.
func _all_problems() -> Array[Problem]:
	var result: Array[Problem] = []
	for seed_value in [1, 2, 3]:
		var gen := ProblemGenerator.new(seed_value)
		for skill: Skill in Skill.values():
			for tier in range(ProblemGenerator.min_tier(skill), ProblemGenerator.MAX_TIER + 1):
				for i in SAMPLES / 3:
					result.append(gen.generate(skill, tier))
	return result


func _operands(p: Problem) -> Array[int]:
	var result: Array[int] = []
	for m in _int_re.search_all(p.text):
		result.append(absi(m.get_string().to_int()))
	return result


func test_answers_match_independent_evaluation() -> void:
	var oracle := Oracle.new()
	for p in _all_problems():
		var expected := _expected_answer(oracle, p)
		if expected.is_empty():
			fail("[%s] '%s': oracle could not evaluate (%s)" % [p.tag, p.text, oracle.last_error()])
		elif expected != [p.answer_num, p.answer_den]:
			fail("[%s] '%s': generator says %s, oracle says %s" % [p.tag, p.text, p.answer_text(), str(expected)])


func _expected_answer(oracle: Oracle, p: Problem) -> Array:
	var m := _pct_re.search(p.text)
	if m:
		return Oracle._make(m.get_string(1).to_int() * m.get_string(2).to_int(), 100)
	m = _call_re.search(p.text)
	if m:
		var a := m.get_string(2).to_int()
		var b := m.get_string(3).to_int()
		if m.get_string(1) == "GCF":
			for d in range(mini(a, b), 0, -1):
				if a % d == 0 and b % d == 0:
					return [d, 1]
		for multiple in range(maxi(a, b), a * b + 1):
			if multiple % a == 0 and multiple % b == 0:
				return [multiple, 1]
		return []
	m = _prime_re.search(p.text)
	if m:
		var n := m.get_string(1).to_int() + 1
		while range(2, n).any(func(d: int) -> bool: return n % d == 0):
			n += 1
		return [n, 1]
	m = _mod_re.search(p.text)
	if m:
		return [m.get_string(1).to_int() % m.get_string(2).to_int(), 1]
	if " = " in p.text:
		var sides := p.text.split(" = ")
		var x: Array = [p.answer_num, p.answer_den]
		var other: Array = [p.answer_num + 1, p.answer_den]
		var solves: bool = oracle.evaluate(sides[0], x) == oracle.evaluate(sides[1], x)
		var unique: bool = oracle.evaluate(sides[0], other) != oracle.evaluate(sides[1], other)
		return x if solves and unique and not oracle.evaluate(sides[0], x).is_empty() else []
	return oracle.evaluate(p.text)


func test_same_seed_gives_same_sequence() -> void:
	var a := ProblemGenerator.new(42)
	var b := ProblemGenerator.new(42)
	for i in 200:
		var pa := a.generate_for_tier(i % 6 + 1)
		var pb := b.generate_for_tier(i % 6 + 1)
		if not assert_eq(pb.text, pa.text, "problem %d" % i):
			return


func test_different_seeds_differ() -> void:
	var a := ProblemGenerator.new(1)
	var b := ProblemGenerator.new(2)
	var same := 0
	for i in 50:
		if a.generate(Skill.MUL, 6).text == b.generate(Skill.MUL, 6).text:
			same += 1
	assert_true(same < 5, "seeds 1 and 2 produced %d identical problems out of 50" % same)


func test_every_problem_is_well_formed() -> void:
	for p in _all_problems():
		assert_true(p.text.length() <= MAX_TEXT_LENGTH, "'%s' is longer than %d chars" % [p.text, MAX_TEXT_LENGTH])
		assert_true(p.answer_den > 0 and Problem.gcd(p.answer_num, p.answer_den) == 1, "'%s' answer not reduced" % p.text)
		assert_true(String(p.tag).contains(":"), "'%s' has malformed tag '%s'" % [p.text, p.tag])
		assert_true(p.tier >= ProblemGenerator.min_tier(p.skill), "'%s' tier below skill minimum" % p.text)
		for bad in ["+ -", "- -", "--", "+ +"]:
			assert_true(not p.text.contains(bad), "'%s' contains '%s'" % [p.text, bad])
		assert_true(_unit_coefficient_re.search(p.text) == null, "'%s' writes 1x instead of x" % p.text)
		if p.skill != Skill.FRACTION:
			assert_true(p.is_integer_answer(), "'%s' should have a whole-number answer" % p.text)


func test_tier_1_stays_within_20() -> void:
	var gen := ProblemGenerator.new(7)
	for i in SAMPLES:
		for p in [gen.generate(Skill.ADD, 1), gen.generate(Skill.SUB, 1), gen.generate_for_tier(1)]:
			assert_true(p.answer_num >= 0 and p.answer_num <= 20, "'%s' answer outside 0..20" % p.text)
			for n in _operands(p):
				assert_true(n >= 1 and n <= 20, "'%s' operand %d outside 1..20" % [p.text, n])


func test_add_and_sub_are_never_negative() -> void:
	var gen := ProblemGenerator.new(8)
	for tier in range(1, 7):
		for i in SAMPLES:
			var p := gen.generate(Skill.SUB, tier)
			assert_true(p.answer_num > 0, "'%s' should be positive" % p.text)
			assert_true(gen.generate(Skill.ADD, tier).answer_num > 0, "addition should be positive")


func test_multiplication_scales_with_tier() -> void:
	var gen := ProblemGenerator.new(9)
	for i in SAMPLES:
		var easy := gen.generate(Skill.MUL, 2)
		for n in _operands(easy):
			assert_true(n >= 2 and n <= 10, "tier 2 '%s' operand %d outside times tables" % [easy.text, n])
		var hard := gen.generate(Skill.MUL, 6)
		for n in _operands(hard):
			assert_true(n >= 11 and n <= 99 and n % 10 != 0, "tier 6 '%s' operand %d is not a non-trivial two-digit number" % [hard.text, n])


func test_fraction_answers_are_positive() -> void:
	var gen := ProblemGenerator.new(10)
	for tier in range(3, 7):
		for i in SAMPLES:
			var p := gen.generate(Skill.FRACTION, tier)
			assert_true(p.answer_num > 0, "'%s' should be positive" % p.text)


func test_fraction_operands_are_proper_and_in_lowest_terms() -> void:
	var gen := ProblemGenerator.new(14)
	var frac_re := RegEx.create_from_string("(\\d+)/(\\d+)")
	for tier in range(3, 7):
		for i in SAMPLES:
			var p := gen.generate(Skill.FRACTION, tier)
			for m in frac_re.search_all(p.text):
				var n := m.get_string(1).to_int()
				var d := m.get_string(2).to_int()
				assert_true(n < d and Problem.gcd(n, d) == 1, "'%s' operand %d/%d is not proper and reduced" % [p.text, n, d])


func test_skill_below_its_tier_is_raised() -> void:
	var gen := ProblemGenerator.new(11)
	assert_eq(gen.generate(Skill.EQUATION, 1).tier, 4, "equation at tier 1")
	assert_eq(gen.generate(Skill.MOD, 3).tier, 6, "mod at tier 3")
	assert_eq(gen.generate(Skill.ADD, 99).tier, 6, "tier above max is clamped")


func test_generate_for_tier_uses_only_unlocked_skills() -> void:
	var gen := ProblemGenerator.new(12)
	for tier in range(1, 7):
		var seen := {}
		for i in SAMPLES:
			var p := gen.generate_for_tier(tier)
			assert_true(ProblemGenerator.min_tier(p.skill) <= tier, "tier %d produced skill %d" % [tier, p.skill])
			seen[p.skill] = true
		for skill in ProblemGenerator.skills_for_tier(tier):
			assert_true(seen.has(skill), "tier %d never produced skill %s" % [tier, Skill.keys()[skill]])


func test_tier_6_mental_math_examples_are_reachable() -> void:
	# The design doc's tier 6 examples: 17 × 23, 2^10 - 3^5, 47 mod 6.
	var gen := ProblemGenerator.new(13)
	var tags := {}
	for i in SAMPLES * 3:
		tags[gen.generate_for_tier(6).tag] = true
	for tag in [&"mul:2dx2d", &"pow:combo", &"mod:6"]:
		assert_true(tags.has(tag), "tier 6 never produced %s" % tag)
