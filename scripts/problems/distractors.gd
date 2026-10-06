class_name Distractors
extends RefCounted
## Plausible wrong answers for "shoot the answer" input: near misses (off by
## one, off by ten, swapped digits, sign slips, fraction slips) rather than
## random numbers, so picking the right one still takes the math.


## Returns `count` distinct wrong answers as text, in random order.
static func generate(problem: Problem, count: int, rng: RandomNumberGenerator) -> Array[String]:
	var candidates: Array = []  # [num, den] pairs, most plausible first
	var n := problem.answer_num
	var d := problem.answer_den
	if d == 1:
		for offset in [1, -1, 2, -2, 10, -10]:
			candidates.append([n + offset, 1])
		var digits := str(absi(n))
		if digits.length() >= 2:
			candidates.append([signi(n) * digits.reverse().to_int(), 1])
		if n != 0:
			candidates.append([-n, 1])
	else:
		candidates.append([n + 1, d])
		candidates.append([n - 1, d])
		candidates.append([n, d + 1])
		candidates.append([n, d - 1])
		candidates.append([d, n])
		candidates.append([n * 2, d])
	# Shuffle within the plausible pool, then fill from wider offsets if needed.
	_shuffle(candidates, rng)
	var fill := 3
	while fill < 100:
		candidates.append([n + fill * d, d] if rng.randi_range(0, 1) == 0 else [n - fill * d, d])
		fill += 1

	var result: Array[String] = []
	var seen := {problem.answer_text(): true}
	for c: Array in candidates:
		if result.size() >= count:
			break
		if c[1] == 0:
			continue
		var reduced := Problem.reduce(c[0], c[1])
		# Keep the answer's sign: a negative choice for "8 + 5" gives itself away.
		if (n >= 0) != (reduced[0] >= 0):
			continue
		var text := str(reduced[0]) if reduced[1] == 1 else "%d/%d" % reduced
		if seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	return result


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
