class_name Encounter
extends RefCounted
## Rules for one real-time combat encounter, with no scene dependencies.
## Call step(delta) every frame and submit(answer) when the player answers.
## The view listens to the signals; tests drive it directly.

signal enemy_spawned(enemy: Enemy)
## A correct answer. `killed` is false when a tough enemy survives and gets a new problem.
signal enemy_hit(enemy: Enemy, killed: bool, points: int)
## A wrong answer. `enemy` is the one that surged forward, or null if none was on screen.
signal answer_missed(enemy: Enemy)
## An enemy reached the ship.
signal enemy_breached(enemy: Enemy)
signal answer_resolved(problem: Problem, correct: bool, seconds: float)
signal finished(won: bool)


## The pressure dial. Defaults aim at a 45-75 second encounter.
class Config:
	var tier := 1
	var enemy_count := 14
	var tough_every := 4  ## Every Nth enemy has 2 HP.
	var spawn_interval := 3.2
	var first_spawn_delay := 1.0
	var descent_time := 14.0  ## Seconds for an enemy to reach the ship.
	var max_alive := 4
	var lanes := 3
	var player_hp := 5
	var wrong_surge := 0.15  ## How far a wrong answer pushes the target forward.


class Enemy:
	var id: int
	var problem: Problem
	var hp: int
	var max_hp: int
	var lane: int
	var progress := 0.0  ## 0 at the top, 1 at the ship.
	var speed: float  ## Progress per second.
	var problem_age := 0.0  ## Seconds since the current problem appeared.

	func is_tough() -> bool:
		return max_hp > 1


const BASE_POINTS := 100
const SPEED_BONUS_POINTS := 50
const SPEED_BONUS_WINDOW := 5.0
const STREAK_PER_STEP := 3
const MULTIPLIER_STEP := 0.5
const MAX_MULTIPLIER := 4.0
## A lane is free once its newest enemy is this far down.
const LANE_CLEARANCE := 0.4

var config: Config
var seed_value: int
var weapon: Weapon
var enemies: Array[Enemy] = []

var player_hp: int
var score := 0
var streak := 0
var best_streak := 0
var correct_count := 0
var wrong_count := 0
var breach_count := 0
var total_answer_time := 0.0
var elapsed := 0.0
var spawned := 0
var is_over := false
var won := false

var _generator: ProblemGenerator
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _spawn_timer: float


func _init(p_config: Config, p_weapon: Weapon, p_seed: int) -> void:
	config = p_config
	weapon = p_weapon
	player_hp = config.player_hp
	seed_value = p_seed
	_rng.seed = p_seed
	_generator = ProblemGenerator.new(p_seed)
	_spawn_timer = config.first_spawn_delay


func step(delta: float) -> void:
	if is_over:
		return
	elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and spawned < config.enemy_count and enemies.size() < config.max_alive:
		var lane := _free_lane()
		if lane >= 0:
			_spawn(lane)
			_spawn_timer = config.spawn_interval
	for enemy in enemies.duplicate():
		enemy.problem_age += delta
		enemy.progress += enemy.speed * delta
		if enemy.progress >= 1.0:
			_breach(enemy)
			if is_over:
				return
	_check_finished()


## Submits an answer. With target_id -1 the answer auto-targets the lowest enemy
## it solves (typed input); otherwise it is checked against that enemy only
## (shoot-the-answer input). Returns true if it hit.
func submit(answer: String, target_id: int = -1) -> bool:
	if is_over or answer.strip_edges() == "":
		return false
	var target: Enemy = null
	if target_id >= 0:
		var candidate := find_enemy(target_id)
		if candidate and candidate.problem.is_correct(answer):
			target = candidate
	else:
		for enemy in _by_threat():
			if enemy.problem.is_correct(answer):
				target = enemy
				break
	if target:
		_hit(target)
		return true
	var victim := find_enemy(target_id) if target_id >= 0 else lowest_enemy()
	_miss(victim)
	return false


func find_enemy(id: int) -> Enemy:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return null


## The enemy closest to the ship, or null.
func lowest_enemy() -> Enemy:
	var threats := _by_threat()
	return threats[0] if not threats.is_empty() else null


func multiplier() -> float:
	@warning_ignore("integer_division")
	return minf(1.0 + (streak / STREAK_PER_STEP) * MULTIPLIER_STEP, MAX_MULTIPLIER)


func accuracy() -> float:
	var total := correct_count + wrong_count
	return float(correct_count) / total if total > 0 else 0.0


func average_answer_time() -> float:
	return total_answer_time / correct_count if correct_count > 0 else 0.0


# --- Internals ----------------------------------------------------------------

func _spawn(lane: int) -> void:
	var enemy := Enemy.new()
	enemy.id = _next_id
	_next_id += 1
	spawned += 1
	enemy.max_hp = 2 if config.tough_every > 0 and spawned % config.tough_every == 0 else 1
	enemy.hp = enemy.max_hp
	enemy.lane = lane
	# Tough enemies descend more slowly so both problems are answerable.
	enemy.speed = 1.0 / (config.descent_time * (1.4 if enemy.is_tough() else 1.0))
	enemy.problem = _new_problem(null)
	enemies.append(enemy)
	enemy_spawned.emit(enemy)


## A problem from the weapon's skills whose answer no other enemy on screen shares,
## so typed answers are never ambiguous.
func _new_problem(for_enemy: Enemy) -> Problem:
	var problem: Problem
	for attempt in 20:
		var skill: ProblemGenerator.Skill = weapon.skills[_rng.randi_range(0, weapon.skills.size() - 1)]
		problem = _generator.generate(skill, config.tier)
		var clash := false
		for other in enemies:
			if other != for_enemy and other.problem.answer_text() == problem.answer_text():
				clash = true
				break
		if not clash:
			break
	return problem


func _hit(enemy: Enemy) -> void:
	correct_count += 1
	total_answer_time += enemy.problem_age
	answer_resolved.emit(enemy.problem, true, enemy.problem_age)
	streak += 1
	best_streak = maxi(best_streak, streak)
	var speed_bonus := SPEED_BONUS_POINTS * maxf(0.0, 1.0 - enemy.problem_age / SPEED_BONUS_WINDOW)
	var points := int(round((BASE_POINTS + speed_bonus) * multiplier()))
	score += points
	enemy.hp -= weapon.damage
	var killed := enemy.hp <= 0
	if killed:
		enemies.erase(enemy)
	else:
		enemy.problem = _new_problem(enemy)
		enemy.problem_age = 0.0
	enemy_hit.emit(enemy, killed, points)
	_check_finished()


func _miss(enemy: Enemy) -> void:
	wrong_count += 1
	streak = 0
	if enemy:
		answer_resolved.emit(enemy.problem, false, enemy.problem_age)
		enemy.progress = minf(enemy.progress + config.wrong_surge, 1.0)
	answer_missed.emit(enemy)
	if enemy and enemy.progress >= 1.0:
		_breach(enemy)
	_check_finished()


func _breach(enemy: Enemy) -> void:
	enemies.erase(enemy)
	breach_count += 1
	streak = 0
	player_hp -= 1
	enemy_breached.emit(enemy)
	if player_hp <= 0:
		_finish(false)


func _check_finished() -> void:
	if not is_over and spawned >= config.enemy_count and enemies.is_empty():
		_finish(true)


func _finish(p_won: bool) -> void:
	is_over = true
	won = p_won
	finished.emit(won)


## Alive enemies, most dangerous (closest to the ship) first.
func _by_threat() -> Array[Enemy]:
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.progress > b.progress)
	return sorted


## A random lane whose newest enemy has moved far enough down, or -1.
func _free_lane() -> int:
	var free: Array[int] = []
	for lane in config.lanes:
		var clear := true
		for enemy in enemies:
			if enemy.lane == lane and enemy.progress < LANE_CLEARANCE:
				clear = false
				break
		if clear:
			free.append(lane)
	return free[_rng.randi_range(0, free.size() - 1)] if not free.is_empty() else -1
