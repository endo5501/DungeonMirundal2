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

var current_mp: int:
	get:
		return _read_current_mp()
	set(value):
		_write_current_mp(value)

var max_mp: int:
	get:
		return _read_max_mp()


func _read_current_hp() -> int:
	return 0


func _write_current_hp(_value: int) -> void:
	pass


func _read_max_hp() -> int:
	return 0


func _read_current_mp() -> int:
	return 0


func _write_current_mp(_value: int) -> void:
	pass


func _read_max_mp() -> int:
	return 0


func get_attack() -> int:
	return 0


func get_defense() -> int:
	return 0


func get_agility() -> int:
	return 0


func is_alive() -> bool:
	return current_hp > 0


# Override in subclasses that represent a species-keyed actor (e.g. MonsterCombatant).
# Used by Cast resolution to group/retarget by species. Returns &"" when the actor
# has no species (party members, generic test stubs).
func get_species_id() -> StringName:
	return &""


func take_damage(amount: int) -> void:
	var actual := amount
	if actual < 0:
		actual = 0
	if _defending and actual > 0:
		actual = maxi(actual / 2, 1)
	var new_hp := maxi(current_hp - actual, 0)
	_write_current_hp(new_hp)


# Deduct `amount` MP from this actor. Returns true if the deduction succeeded
# (i.e. there was enough MP to cover the cost), false otherwise. `amount == 0`
# is a no-op that always succeeds. Subclasses that have no MP (e.g. monsters in
# v1) should reject any positive amount by returning false.
func spend_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_mp < amount:
		return false
	_write_current_mp(current_mp - amount)
	return true


func apply_defend() -> void:
	_defending = true


func clear_turn_flags() -> void:
	_defending = false


func is_defending() -> bool:
	return _defending
