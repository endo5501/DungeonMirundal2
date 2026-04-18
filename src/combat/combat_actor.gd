class_name CombatActor
extends RefCounted

var actor_name: String = ""

var _defending: bool = false

var current_hp: int:
	get:
		return _read_current_hp()
	set(value):
		_write_current_hp(value)

var max_hp: int:
	get:
		return _read_max_hp()


func _read_current_hp() -> int:
	return 0


func _write_current_hp(_value: int) -> void:
	pass


func _read_max_hp() -> int:
	return 0


func get_attack() -> int:
	return 0


func get_defense() -> int:
	return 0


func get_agility() -> int:
	return 0


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> void:
	var actual := amount
	if actual < 0:
		actual = 0
	if _defending and actual > 0:
		actual = maxi(actual / 2, 1)
	var new_hp := maxi(current_hp - actual, 0)
	_write_current_hp(new_hp)


func apply_defend() -> void:
	_defending = true


func clear_turn_flags() -> void:
	_defending = false


func is_defending() -> bool:
	return _defending
