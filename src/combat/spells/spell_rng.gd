class_name SpellRng
extends RefCounted

# Project-defined RNG wrapper used by SpellEffect.apply(). Wraps a
# RandomNumberGenerator and exposes a small project API (`roll(low, high)`).
#
# Tests can subclass SpellRng and override `roll()` to inject deterministic
# values without overriding native RandomNumberGenerator methods (which Godot
# 4.6 escalates to parse error via the native_method_override warning).

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = rng


func roll(low: int, high: int) -> int:
	return _rng.randi_range(low, high)
