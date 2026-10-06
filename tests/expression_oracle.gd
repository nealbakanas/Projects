extends RefCounted
## Independent evaluator for generated problem text, used as a test oracle.
## Exact rational arithmetic over + - × ÷ ^ √ ∛, parentheses, unary minus,
## fraction literals written without spaces ("3/4"), and an optional x
## with implicit multiplication ("3x"). Returns [num, den] or [] on error.

var _tokens: Array = []
var _pos := 0
var _x: Array = []
var _error := ""


func evaluate(text: String, x: Array = []) -> Array:
	_x = x
	_error = ""
	_pos = 0
	_tokens = _tokenize(text)
	if _error != "":
		return []
	var result := _expr()
	if _pos != _tokens.size():
		_error = "trailing tokens"
	return [] if _error != "" else result


func last_error() -> String:
	return _error


func _tokenize(text: String) -> Array:
	var tokens: Array = []
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == " ":
			i += 1
		elif ch.is_valid_int():
			var start := i
			while i < text.length() and text[i].is_valid_int():
				i += 1
			var value: Array = [text.substr(start, i - start).to_int(), 1]
			if i + 1 < text.length() and text[i] == "/" and text[i + 1].is_valid_int():
				var dstart := i + 1
				i += 1
				while i < text.length() and text[i].is_valid_int():
					i += 1
				var den := text.substr(dstart, i - dstart).to_int()
				if den == 0:
					_error = "zero denominator"
					return []
				value = _make(value[0], den)
			tokens.append(value)
			if i < text.length() and text[i] == "x":
				tokens.append("*")
		elif ch == "x":
			tokens.append("x")
			i += 1
		elif ch in ["+", "-", "(", ")", "^", "√", "∛"]:
			tokens.append(ch)
			i += 1
		elif ch == "*" or ch == "×":
			tokens.append("*")
			i += 1
		elif ch == "/" or ch == "÷":
			tokens.append("/")
			i += 1
		else:
			_error = "unexpected character '%s'" % ch
			return []
	return tokens


func _peek() -> Variant:
	return _tokens[_pos] if _pos < _tokens.size() else null


func _take() -> Variant:
	var t: Variant = _peek()
	_pos += 1
	return t


func _expr() -> Array:
	var left := _term()
	while _error == "" and (_peek() is String) and (_peek() == "+" or _peek() == "-"):
		var op: String = _take()
		var right := _term()
		if _error != "":
			return []
		left = _add(left, right) if op == "+" else _add(left, _neg(right))
	return left


func _term() -> Array:
	var left := _unary()
	while _error == "" and (_peek() is String) and (_peek() == "*" or _peek() == "/"):
		var op: String = _take()
		var right := _unary()
		if _error != "":
			return []
		if op == "*":
			left = _make(left[0] * right[0], left[1] * right[1])
		else:
			if right[0] == 0:
				_error = "division by zero"
				return []
			left = _make(left[0] * right[1], left[1] * right[0])
	return left


func _unary() -> Array:
	if (_peek() is String) and _peek() == "-":
		_take()
		var v := _unary()
		return [] if _error != "" else _neg(v)
	return _power()


func _power() -> Array:
	var base := _prefix()
	if _error == "" and (_peek() is String) and _peek() == "^":
		_take()
		var e := _unary()
		if _error != "":
			return []
		if e[1] != 1 or e[0] < 0:
			_error = "non-integer exponent"
			return []
		var result: Array = [1, 1]
		for i in e[0]:
			result = _make(result[0] * base[0], result[1] * base[1])
		return result
	return base


func _prefix() -> Array:
	var t: Variant = _peek()
	if t is String and (t == "√" or t == "∛"):
		_take()
		var degree := 2 if t == "√" else 3
		var v := _prefix()
		if _error != "":
			return []
		var n := _exact_root(v[0], degree)
		var d := _exact_root(v[1], degree)
		if n < 0 or d < 0:
			_error = "inexact root"
			return []
		return _make(n, d)
	return _primary()


func _primary() -> Array:
	var t: Variant = _take()
	if t is Array:
		return t
	if t is String and t == "x":
		if _x.is_empty():
			_error = "x without a value"
			return []
		return _x
	if t is String and t == "(":
		var v := _expr()
		if _error == "" and not ((_peek() is String) and _take() == ")"):
			_error = "missing )"
		return v
	_error = "unexpected token %s" % str(t)
	return []


func _exact_root(n: int, degree: int) -> int:
	if n < 0:
		return -1
	var r := 0
	while true:
		var p := 1
		for i in degree:
			p *= r
		if p == n:
			return r
		if p > n:
			return -1
		r += 1
	return -1


static func _add(a: Array, b: Array) -> Array:
	return _make(a[0] * b[1] + b[0] * a[1], a[1] * b[1])


static func _neg(a: Array) -> Array:
	return [-a[0], a[1]]


static func _make(num: int, den: int) -> Array:
	if den < 0:
		num = -num
		den = -den
	var a := absi(num)
	var b := den
	while b != 0:
		var t := a % b
		a = b
		b = t
	if a == 0:
		return [0, 1]
	@warning_ignore("integer_division")
	return [num / a, den / a]
