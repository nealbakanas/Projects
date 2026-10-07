extends TestCase

const FRAME := 1.0 / 60.0


func _encounter(seed_value: int = 1, setup: Callable = func(_c: Encounter.Config) -> void: pass) -> Encounter:
	var config := Encounter.Config.new()
	setup.call(config)
	return Encounter.new(config, Weapon.adder_blaster(), seed_value)


## Steps until at least `n` enemies are alive (or the encounter ends).
func _wait_for_enemies(e: Encounter, n: int) -> void:
	for i in 60 * 60:
		if e.enemies.size() >= n or e.is_over:
			return
		e.step(FRAME)


func test_correct_answer_kills_enemy_and_scores() -> void:
	var e := _encounter()
	_wait_for_enemies(e, 1)
	var enemy := e.enemies[0]
	assert_true(not enemy.is_tough(), "first enemy should have 1 HP")
	assert_true(e.submit(enemy.problem.answer_text()), "correct answer should hit")
	assert_eq(e.enemies.size(), 0, "enemy count after kill")
	assert_eq(e.streak, 1, "streak")
	assert_true(e.score >= Encounter.BASE_POINTS, "score should include base points")


func test_typed_answer_auto_targets_lowest_matching_enemy() -> void:
	var e := _encounter(2, func(c: Encounter.Config) -> void: c.tough_every = 0)
	_wait_for_enemies(e, 2)
	var high := e.enemies[1]
	var low := e.enemies[0]
	assert_true(low.progress > high.progress, "first spawned enemy should be lower")
	# Only the higher enemy's answer: it must hit that one, not the lowest.
	assert_true(e.submit(high.problem.answer_text()), "answer for the higher enemy should hit")
	assert_true(e.find_enemy(high.id) == null, "higher enemy should be destroyed")
	assert_true(e.find_enemy(low.id) != null, "lower enemy should survive")


func test_targeted_answer_only_checks_its_target() -> void:
	var e := _encounter(3, func(c: Encounter.Config) -> void: c.tough_every = 0)
	_wait_for_enemies(e, 2)
	var a := e.enemies[0]
	var b := e.enemies[1]
	assert_true(not e.submit(b.problem.answer_text(), a.id), "b's answer aimed at a should miss")
	assert_true(e.find_enemy(b.id) != null, "b should be untouched")


func test_wrong_answer_resets_streak_and_surges_enemy() -> void:
	var e := _encounter()
	_wait_for_enemies(e, 1)
	e.streak = 5
	var enemy := e.enemies[0]
	var before := enemy.progress
	assert_true(not e.submit("-999"), "wrong answer should miss")
	assert_eq(e.streak, 0, "streak after miss")
	assert_eq(e.wrong_count, 1, "wrong count")
	assert_true(is_equal_approx(enemy.progress, before + e.config.wrong_surge), "enemy should surge forward")
	assert_eq(e.player_hp, e.config.player_hp, "a miss alone costs no HP")


func test_enemy_reaching_ship_costs_hp() -> void:
	var e := _encounter()
	_wait_for_enemies(e, 1)
	var first := e.enemies[0]
	var breached := []
	e.enemy_breached.connect(func(enemy: Encounter.Enemy) -> void: breached.append(enemy.id))
	while e.find_enemy(first.id) != null:
		e.step(FRAME)
	assert_eq(breached, [first.id], "breached enemies")
	assert_eq(e.player_hp, e.config.player_hp - 1, "HP after breach")


func test_tough_enemy_takes_two_hits_with_new_problem() -> void:
	var e := _encounter(4, func(c: Encounter.Config) -> void: c.tough_every = 1)
	_wait_for_enemies(e, 1)
	var enemy := e.enemies[0]
	assert_true(enemy.is_tough(), "enemy should be tough")
	var first_problem := enemy.problem
	assert_true(e.submit(first_problem.answer_text()), "first hit")
	assert_true(e.find_enemy(enemy.id) != null, "tough enemy survives one hit")
	assert_true(enemy.problem != first_problem, "survivor gets a new problem")
	assert_eq(enemy.problem_age, 0.0, "new problem resets its timer")
	assert_true(e.submit(enemy.problem.answer_text()), "second hit")
	assert_true(e.find_enemy(enemy.id) == null, "tough enemy dies on second hit")


func test_combo_multiplier_grows_and_caps() -> void:
	var e := _encounter()
	assert_eq(e.multiplier(), 1.0, "no streak")
	e.streak = 3
	assert_eq(e.multiplier(), 1.5, "3 streak")
	e.streak = 9
	assert_eq(e.multiplier(), 2.5, "9 streak")
	e.streak = 100
	assert_eq(e.multiplier(), Encounter.MAX_MULTIPLIER, "capped")


func test_enemies_on_screen_never_share_an_answer() -> void:
	var e := _encounter(5)
	while not e.is_over:
		e.step(FRAME)
		var answers := {}
		for enemy in e.enemies:
			if not assert_true(not answers.has(enemy.problem.answer_text()), "duplicate answer %s on screen" % enemy.problem.answer_text()):
				return
			answers[enemy.problem.answer_text()] = true
		# Kill occasionally so enemies don't all breach before testing much.
		if e.enemies.size() == e.config.max_alive:
			e.submit(e.enemies[0].problem.answer_text())


func test_perfect_player_wins_within_design_length() -> void:
	# A player who answers each enemy 2.5 s after its problem appears.
	for seed_value in [1, 2, 3, 4, 5]:
		var e := _encounter(seed_value)
		var finished := []
		e.finished.connect(func(w: bool) -> void: finished.append(w))
		while not e.is_over and e.elapsed < 300.0:
			e.step(FRAME)
			for enemy in e.enemies.duplicate():
				if enemy.problem_age >= 2.5:
					e.submit(enemy.problem.answer_text())
		assert_eq(finished, [true], "seed %d outcome" % seed_value)
		assert_eq(e.breach_count, 0, "seed %d breaches" % seed_value)
		assert_eq(e.accuracy(), 1.0, "seed %d accuracy" % seed_value)
		assert_true(e.elapsed >= 45.0 and e.elapsed <= 75.0, "seed %d lasted %.1f s, outside 45-75 s" % [seed_value, e.elapsed])


func test_idle_player_loses() -> void:
	var e := _encounter()
	var finished := []
	e.finished.connect(func(w: bool) -> void: finished.append(w))
	while not e.is_over and e.elapsed < 300.0:
		e.step(FRAME)
	assert_eq(finished, [false], "outcome")
	assert_eq(e.player_hp, 0, "HP")


func test_same_seed_same_encounter() -> void:
	var a := _encounter(42)
	var b := _encounter(42)
	for i in 60 * 30:
		a.step(FRAME)
		b.step(FRAME)
	assert_eq(a.enemies.size(), b.enemies.size(), "enemy count")
	for i in a.enemies.size():
		assert_eq(b.enemies[i].problem.text, a.enemies[i].problem.text, "enemy %d problem" % i)
		assert_eq(b.enemies[i].lane, a.enemies[i].lane, "enemy %d lane" % i)


func test_no_answers_accepted_after_finish() -> void:
	var e := _encounter()
	_wait_for_enemies(e, 1)
	var answer := e.enemies[0].problem.answer_text()
	e.player_hp = 1
	while not e.is_over:
		e.step(FRAME)
	assert_true(not e.submit(answer), "submit after finish")
