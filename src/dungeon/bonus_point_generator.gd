class_name BonusPointGenerator
extends RefCounted

var _rng: RandomNumberGenerator

func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

func generate() -> int:
	var base := _rng.randi_range(5, 9)
	return base + _roll_extra()

func _roll_extra() -> int:
	if _rng.randf() < 0.1:
		var extra := _rng.randi_range(1, 3)
		return extra + _roll_extra()
	return 0
