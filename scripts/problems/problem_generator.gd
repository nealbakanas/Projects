class_name ProblemGenerator
extends RefCounted
## Generates math problems by skill and content tier (1-6, see docs/DESIGN.md).
## Pure GDScript with no scene dependencies. All randomness comes from one
## seeded RNG, so the same seed always produces the same sequence of problems.

enum Skill {
	ADD,
	SUB,
	MUL,
	DIV,
	FRACTION,
	NEGATIVE,
	ORDER_OF_OPS,
	PERCENT,
	EQUATION,
	EXPONENT,
	ROOT,
	FACTOR,
	MOD,
}

const MIN_TIER := 1
const MAX_TIER := 6

## The tier at which each skill first appears.
const SKILL_MIN_TIER := {
	Skill.ADD: 1,
	Skill.SUB: 1,
	Skill.MUL: 2,
	Skill.DIV: 3,
	Skill.FRACTION: 3,
	Skill.NEGATIVE: 3,
	Skill.ORDER_OF_OPS: 4,
	Skill.PERCENT: 4,
	Skill.EQUATION: 4,
	Skill.EXPONENT: 5,
	Skill.ROOT: 5,
	Skill.FACTOR: 5,
	Skill.MOD: 6,
}

## Operand digit counts for multi-digit add/subtract, by tier.
const ADD_SUB_DIGITS := {2: [2, 2], 3: [3, 2], 4: [3, 3], 5: [4, 3], 6: [4, 4]}

const PERCENTS_EASY: Array[int] = [10, 20, 25, 50, 75]
const PERCENTS_MEDIUM: Array[int] = [5, 10, 15, 20, 25, 30, 40, 60, 75, 80, 90]

const TIMES := "×"
const DIVIDE := "÷"
const SQRT := "√"
const CBRT := "∛"

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Skills available at a content tier (introduced at or below it).
static func skills_for_tier(tier: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill: Skill in SKILL_MIN_TIER:
		if SKILL_MIN_TIER[skill] <= tier:
			result.append(skill)
	return result


static func min_tier(skill: Skill) -> int:
	return SKILL_MIN_TIER[skill]


## Generates a problem for one skill. A tier below the skill's first tier is
## raised to it, so the Equation Railgun at tier 1 still asks a real equation.
func generate(skill: Skill, tier: int) -> Problem:
	var t := clampi(maxi(tier, SKILL_MIN_TIER[skill]), MIN_TIER, MAX_TIER)
	match skill:
		Skill.ADD:
			return _add(t)
		Skill.SUB:
			return _sub(t)
		Skill.MUL:
			return _mul(t)
		Skill.DIV:
			return _div(t)
		Skill.FRACTION:
			return _fraction(t)
		Skill.NEGATIVE:
			return _negative(t)
		Skill.ORDER_OF_OPS:
			return _order_of_ops(t)
		Skill.PERCENT:
			return _percent(t)
		Skill.EQUATION:
			return _equation(t)
		Skill.EXPONENT:
			return _exponent(t)
		Skill.ROOT:
			return _root(t)
		Skill.FACTOR:
			return _factor(t)
		Skill.MOD:
			return _mod(t)
	push_error("Unknown skill %d" % skill)
	return null


## Generates a problem from any skill available at the tier. Skills new at
## this tier are weighted double so each tier feels like its row in the design doc.
func generate_for_tier(tier: int) -> Problem:
	var t := clampi(tier, MIN_TIER, MAX_TIER)
	var pool: Array[Skill] = []
	for skill in skills_for_tier(t):
		pool.append(skill)
		if SKILL_MIN_TIER[skill] == t:
			pool.append(skill)
	return generate(pool[_rng.randi_range(0, pool.size() - 1)], t)


# --- Skills -------------------------------------------------------------------

func _add(t: int) -> Problem:
	if t == 1:
		var a := _rng.randi_range(1, 19)
		var b := _rng.randi_range(1, 20 - a)
		return Problem.new("%d + %d" % [a, b], Skill.ADD, &"add:within_20", t, a + b)
	var digits: Array = ADD_SUB_DIGITS[t]
	var a := _rand_digits(digits[0])
	var b := _rand_digits(digits[1])
	return Problem.new("%d + %d" % [a, b], Skill.ADD, StringName("add:%dd+%dd" % digits), t, a + b)


func _sub(t: int) -> Problem:
	if t == 1:
		var a := _rng.randi_range(2, 20)
		var b := _rng.randi_range(1, a - 1)
		return Problem.new("%d - %d" % [a, b], Skill.SUB, &"sub:within_20", t, a - b)
	var digits: Array = ADD_SUB_DIGITS[t]
	var a := _rand_digits(digits[0])
	var b := _rand_digits(digits[1])
	while a == b:
		b = _rand_digits(digits[1])
	if b > a:
		var tmp := a
		a = b
		b = tmp
	return Problem.new("%d - %d" % [a, b], Skill.SUB, StringName("sub:%dd-%dd" % digits), t, a - b)


func _mul(t: int) -> Problem:
	var a: int
	var b: int
	var tag: StringName
	match t:
		2, 3:
			var top := 10 if t == 2 else 12
			a = _rng.randi_range(2, top)
			b = _rng.randi_range(2, top)
			tag = StringName("mul:by_%d" % a)
		4:
			a = _rand_factor(2)
			b = _rng.randi_range(2, 9)
			tag = &"mul:2dx1d"
		5:
			a = _rand_factor(3)
			b = _rng.randi_range(2, 9)
			tag = &"mul:3dx1d"
		_:
			a = _rand_factor(2)
			b = _rand_factor(2)
			tag = &"mul:2dx2d"
	return Problem.new("%d %s %d" % [a, TIMES, b], Skill.MUL, tag, t, a * b)


func _div(t: int) -> Problem:
	# Built from divisor and quotient so division is always exact.
	var d: int
	var q: int
	var tag: StringName
	match t:
		3, 4:
			var top := 10 if t == 3 else 12
			d = _rng.randi_range(2, top)
			q = _rng.randi_range(2, top)
			tag = StringName("div:by_%d" % d)
		5:
			d = _rng.randi_range(2, 9)
			q = _rand_digits(2)
			tag = &"div:2d_quotient"
		_:
			d = _rng.randi_range(11, 19)
			q = _rng.randi_range(11, 49)
			tag = &"div:2d_divisor"
	return Problem.new("%d %s %d" % [d * q, DIVIDE, d], Skill.DIV, tag, t, q)


func _fraction(t: int) -> Problem:
	var kind: String
	match t:
		3:
			kind = _pick(["add_like", "add_related"])
		4:
			kind = _pick(["add_unlike", "sub_unlike"])
		5:
			kind = _pick(["add_unlike", "sub_unlike", "mul"])
		_:
			kind = _pick(["sub_unlike", "mul", "div"])
	var n1: int
	var d1: int
	var n2: int
	var d2: int
	var op := "+"
	match kind:
		"add_like":
			d1 = _rng.randi_range(3, 10)
			d2 = d1
			n1 = _numerator(d1)
			n2 = _numerator(d1)
		"add_related":
			d1 = _pick([2, 3, 4, 5])
			d2 = d1 * 2
			n1 = _numerator(d1)
			n2 = _numerator(d2)
		_:
			var top := 10 if t <= 5 else 12
			d1 = _rng.randi_range(2, top)
			d2 = _rng.randi_range(2, top)
			while d2 == d1:
				d2 = _rng.randi_range(2, top)
			n1 = _numerator(d1)
			n2 = _numerator(d2)
	var num: int
	var den: int
	match kind:
		"mul":
			op = TIMES
			num = n1 * n2
			den = d1 * d2
		"div":
			op = DIVIDE
			num = n1 * d2
			den = d1 * n2
		"sub_unlike":
			op = "-"
			# Unlike denominators can still be equal fractions (1/2 and 2/4),
			# which would give 0. Re-roll, then order so the result is positive.
			while n1 * d2 == n2 * d1:
				n1 = _numerator(d1)
				n2 = _numerator(d2)
			if n1 * d2 < n2 * d1:
				var tn := n1
				var td := d1
				n1 = n2
				d1 = d2
				n2 = tn
				d2 = td
			num = n1 * d2 - n2 * d1
			den = d1 * d2
		_:
			num = n1 * d2 + n2 * d1
			den = d1 * d2
	var text := "%d/%d %s %d/%d" % [n1, d1, op, n2, d2]
	return Problem.new(text, Skill.FRACTION, StringName("frac:" + kind), t, num, den)


func _negative(t: int) -> Problem:
	var span: int = {3: 10, 4: 20, 5: 50, 6: 100}[t]
	if t >= 5 and _rng.randi_range(0, 2) == 0:
		var a := _rand_nonzero(-12, 12)
		var b := _rand_nonzero(-12, 12)
		if a > 0 and b > 0:
			a = -a
		return Problem.new("%d %s %s" % [a, TIMES, _paren(b)], Skill.NEGATIVE, &"neg:mul", t, a * b)
	var a := _rand_nonzero(-span, span)
	var b := _rand_nonzero(-span, span)
	if a > 0 and b > 0:
		if _rng.randi_range(0, 1) == 0:
			a = -a
		else:
			b = -b
	if _rng.randi_range(0, 1) == 0:
		return Problem.new("%d + %s" % [a, _paren(b)], Skill.NEGATIVE, &"neg:add", t, a + b)
	return Problem.new("%d - %s" % [a, _paren(b)], Skill.NEGATIVE, &"neg:sub", t, a - b)


func _order_of_ops(t: int) -> Problem:
	match t:
		4:
			var a := _rng.randi_range(1, 20)
			var b := _rng.randi_range(2, 9)
			var c := _rng.randi_range(2, 9)
			match _rng.randi_range(0, 3):
				0:
					return _ops("%d + %d %s %d" % [a, b, TIMES, c], &"ops:2op", t, a + b * c)
				1:
					return _ops("%d %s %d + %d" % [b, TIMES, c, a], &"ops:2op", t, b * c + a)
				2:
					var big := b * c + a
					return _ops("%d - %d %s %d" % [big, b, TIMES, c], &"ops:2op", t, big - b * c)
				_:
					var small := _rng.randi_range(1, 9)
					return _ops("(%d + %d) %s %d" % [small, b, TIMES, c], &"ops:parens", t, (small + b) * c)
		5:
			var a := _rng.randi_range(2, 9)
			var b := _rng.randi_range(2, 9)
			var c := _rng.randi_range(2, 9)
			var d := _rng.randi_range(2, 9)
			match _rng.randi_range(0, 2):
				0:
					return _ops("%d %s %d + %d %s %d" % [a, TIMES, b, c, TIMES, d], &"ops:3op", t, a * b + c * d)
				1:
					var hi := c + _rng.randi_range(1, 9)
					return _ops("(%d + %d) %s (%d - %d)" % [a, b, TIMES, hi, c], &"ops:parens", t, (a + b) * (hi - c))
				_:
					var e := _rng.randi_range(1, 20)
					return _ops("%d + %d %s %d - %d" % [e + d, a, TIMES, b, d], &"ops:3op", t, e + d + a * b - d)
		_:
			var a := _rng.randi_range(2, 15)
			var b := _rng.randi_range(2, 12)
			var c := _rng.randi_range(2, 12)
			var d := _rng.randi_range(2, 12)
			match _rng.randi_range(0, 2):
				0:
					return _ops("%d^2 + %d %s %d" % [a, b, TIMES, c], &"ops:pow", t, a * a + b * c)
				1:
					return _ops("%d %s %d - %d %s %d" % [a, TIMES, b, c, TIMES, d], &"ops:3op", t, a * b - c * d)
				_:
					var lo := _rng.randi_range(1, 9)
					return _ops("(%d - %d) %s (%d + %d)" % [a + lo + 1, lo, TIMES, c, d], &"ops:parens", t, (a + 1) * (c + d))


func _percent(t: int) -> Problem:
	var p: int
	var max_n: int
	match t:
		4:
			p = _pick(PERCENTS_EASY)
			max_n = 200
		5:
			p = _pick(PERCENTS_MEDIUM)
			max_n = 400
		_:
			p = _rng.randi_range(1, 99)
			max_n = 1000
	# n must be a multiple of 100 / gcd(p, 100) for a whole-number answer.
	@warning_ignore("integer_division")
	var step := 100 / Problem.gcd(p, 100)
	@warning_ignore("integer_division")
	var n := step * _rng.randi_range(1, maxi(1, max_n / step))
	var tag := StringName("pct:%d" % p) if t < 6 else &"pct:any"
	@warning_ignore("integer_division")
	return Problem.new("%d%% of %d" % [p, n], Skill.PERCENT, tag, t, p * n / 100)


func _equation(t: int) -> Problem:
	match t:
		4:
			var x := _rng.randi_range(1, 20)
			var a := _rng.randi_range(2, 12)
			match _rng.randi_range(0, 3):
				0:
					return _eq("x + %d = %d" % [a, x + a], &"eq:1step_add", t, x)
				1:
					return _eq("x - %d = %d" % [a, x], &"eq:1step_sub", t, x + a)
				2:
					return _eq("%dx = %d" % [a, a * x], &"eq:1step_mul", t, x)
				_:
					return _eq("x %s %d = %d" % [DIVIDE, a, x], &"eq:1step_div", t, x * a)
		5:
			var x := _rng.randi_range(1, 12)
			var a := _rng.randi_range(2, 9)
			var b := _rng.randi_range(1, 20)
			if _rng.randi_range(0, 1) == 0:
				return _eq("%dx + %d = %d" % [a, b, a * x + b], &"eq:2step", t, x)
			return _eq("%dx - %d = %d" % [a, b, a * x - b], &"eq:2step", t, x)
		_:
			var x := _rand_nonzero(-10, 10)
			var a := _rng.randi_range(2, 9)
			var c := _rng.randi_range(1, 9)
			while c == a:
				c = _rng.randi_range(1, 9)
			var b := _rand_nonzero(-20, 20)
			var d := (a - c) * x + b
			var lhs := "%dx %s" % [a, _signed(b)]
			var rhs := ("x" if c == 1 else "%dx" % c) + (" " + _signed(d) if d != 0 else "")
			return _eq("%s = %s" % [lhs, rhs], &"eq:both_sides", t, x)


func _exponent(t: int) -> Problem:
	if t == 5:
		var base := _rng.randi_range(2, 10)
		var max_exp := 8 if base == 2 else (4 if base == 3 else 3)
		var e := _rng.randi_range(2, max_exp)
		return Problem.new("%d^%d" % [base, e], Skill.EXPONENT, StringName("pow:base_%d" % base), t, _ipow(base, e))
	if _rng.randi_range(0, 1) == 0:
		var base := _rng.randi_range(11, 25)
		return Problem.new("%d^2" % base, Skill.EXPONENT, &"pow:square_2d", t, base * base)
	var e1 := _rng.randi_range(6, 10)
	var e2 := _rng.randi_range(3, 5)
	var x := _ipow(2, e1)
	var y := _ipow(3, e2)
	if _rng.randi_range(0, 1) == 0:
		return Problem.new("2^%d - 3^%d" % [e1, e2], Skill.EXPONENT, &"pow:combo", t, x - y)
	return Problem.new("2^%d + 3^%d" % [e1, e2], Skill.EXPONENT, &"pow:combo", t, x + y)


func _root(t: int) -> Problem:
	if t == 5:
		var r := _rng.randi_range(2, 15)
		return Problem.new("%s%d" % [SQRT, r * r], Skill.ROOT, &"root:square", t, r)
	if _rng.randi_range(0, 1) == 0:
		var r := _rng.randi_range(16, 30)
		return Problem.new("%s%d" % [SQRT, r * r], Skill.ROOT, &"root:square_2d", t, r)
	var c := _rng.randi_range(2, 10)
	return Problem.new("%s%d" % [CBRT, c * c * c], Skill.ROOT, &"root:cube", t, c)


func _factor(t: int) -> Problem:
	var g_top := 12 if t == 5 else 20
	var m_top := 6 if t == 5 else 9
	match _rng.randi_range(0, 2):
		0:
			var g := _rng.randi_range(2, g_top)
			var m := _coprime_pair(m_top)
			return Problem.new("GCF(%d, %d)" % [g * m[0], g * m[1]], Skill.FACTOR, &"factor:gcf", t, g)
		1:
			var g := _rng.randi_range(1, 6 if t == 5 else 10)
			var m := _coprime_pair(m_top)
			return Problem.new("LCM(%d, %d)" % [g * m[0], g * m[1]], Skill.FACTOR, &"factor:lcm", t, g * m[0] * m[1])
		_:
			var n := _rng.randi_range(2, 50 if t == 5 else 150)
			return Problem.new("next prime > %d" % n, Skill.FACTOR, &"prime:next", t, _next_prime(n))


func _mod(t: int) -> Problem:
	var b := _rng.randi_range(3, 12)
	var a := _rng.randi_range(20, 199)
	return Problem.new("%d mod %d" % [a, b], Skill.MOD, StringName("mod:%d" % b), t, a % b)


# --- Helpers ------------------------------------------------------------------

func _ops(text: String, tag: StringName, t: int, answer: int) -> Problem:
	return Problem.new(text, Skill.ORDER_OF_OPS, tag, t, answer)


func _eq(text: String, tag: StringName, t: int, x: int) -> Problem:
	return Problem.new(text, Skill.EQUATION, tag, t, x)


func _rand_digits(n: int) -> int:
	return _rng.randi_range(_ipow(10, n - 1), _ipow(10, n) - 1)


## An n-digit multiplication operand that isn't a multiple of 10 (× 10 is trivial).
func _rand_factor(n: int) -> int:
	var v := _rand_digits(n)
	while v % 10 == 0:
		v = _rand_digits(n)
	return v


## A numerator for a proper fraction over den, in lowest terms (no 2/4).
func _numerator(den: int) -> int:
	var n := _rng.randi_range(1, den - 1)
	while Problem.gcd(n, den) != 1:
		n = _rng.randi_range(1, den - 1)
	return n


func _rand_nonzero(lo: int, hi: int) -> int:
	var v := 0
	while v == 0:
		v = _rng.randi_range(lo, hi)
	return v


func _pick(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)]


## Two distinct coprime integers in 1..top.
func _coprime_pair(top: int) -> Array[int]:
	while true:
		var a := _rng.randi_range(1, top)
		var b := _rng.randi_range(1, top)
		if a != b and Problem.gcd(a, b) == 1:
			return [a, b]
	return []


static func _ipow(base: int, e: int) -> int:
	var result := 1
	for i in e:
		result *= base
	return result


static func _next_prime(n: int) -> int:
	var c := n + 1
	while not _is_prime(c):
		c += 1
	return c


static func _is_prime(n: int) -> bool:
	if n < 2:
		return false
	var i := 2
	while i * i <= n:
		if n % i == 0:
			return false
		i += 1
	return true


## Wraps negative operands in parentheses: -5 -> "(-5)".
static func _paren(v: int) -> String:
	return "(%d)" % v if v < 0 else str(v)


## A trailing term with its sign as an operator: 5 -> "+ 5", -5 -> "- 5".
static func _signed(v: int) -> String:
	return "+ %d" % v if v >= 0 else "- %d" % -v
