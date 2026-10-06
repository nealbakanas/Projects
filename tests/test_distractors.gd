extends TestCase

const Skill = ProblemGenerator.Skill


func test_distractors_are_distinct_wrong_and_same_sign() -> void:
	var gen := ProblemGenerator.new(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for skill: Skill in Skill.values():
		for tier in range(ProblemGenerator.min_tier(skill), 7):
			for i in 60:
				var p := gen.generate(skill, tier)
				var choices := Distractors.generate(p, 3, rng)
				if not assert_eq(choices.size(), 3, "'%s' choice count" % p.text):
					continue
				var values := {}
				for c in choices:
					var parsed := Problem.parse_number(c)
					assert_true(not parsed.is_empty(), "'%s' distractor '%s' does not parse" % [p.text, c])
					assert_true(not p.is_correct(c), "'%s' distractor '%s' is correct" % [p.text, c])
					assert_true(not values.has(parsed), "'%s' distractor '%s' duplicated" % [p.text, c])
					values[parsed] = true
					if p.answer_num >= 0:
						assert_true(parsed[0] >= 0, "'%s' distractor '%s' gives itself away by sign" % [p.text, c])


func test_distractors_are_near_misses() -> void:
	# Each distractor is a slip a player could make: within 10, or digits reversed.
	var p := Problem.new("8 + 5", Skill.ADD, &"add:within_20", 1, 13)
	var rng := RandomNumberGenerator.new()
	for i in 100:
		for c in Distractors.generate(p, 3, rng):
			assert_true(absi(c.to_int() - 13) <= 10 or c == "31", "'%s' is not a near miss for 13" % c)


func test_distractors_are_deterministic() -> void:
	var p := Problem.new("3/4", Skill.FRACTION, &"frac:add_like", 3, 3, 4)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 9
	b.seed = 9
	assert_eq(Distractors.generate(p, 3, b), Distractors.generate(p, 3, a), "same seed")
