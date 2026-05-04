class_name CombatActor
extends RefCounted

const MOD_CAP: float = 0.40

var actor_name: String = ""

var modifier_stack: StatModifierStack = StatModifierStack.new()

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


# Base stat virtuals: subclasses override these to expose the un-modified value
# (e.g. EquipmentProvider for party, MonsterData for monsters). Public
# get_attack/defense/agility add the modifier_stack on top.
func _get_base_attack() -> int:
	return 0


func _get_base_defense() -> int:
	return 0


func _get_base_agility() -> int:
	return 0


func get_attack() -> int:
	return _get_base_attack() + int(modifier_stack.sum(&"attack"))


func get_defense() -> int:
	return _get_base_defense() + int(modifier_stack.sum(&"defense"))


func get_agility() -> int:
	return _get_base_agility() + int(modifier_stack.sum(&"agility"))


func get_hit_modifier_total() -> float:
	return clampf(float(modifier_stack.sum(&"hit")), -MOD_CAP, MOD_CAP)


func get_evasion_modifier_total() -> float:
	return clampf(float(modifier_stack.sum(&"evasion")), -MOD_CAP, MOD_CAP)


# Subclasses override when a status (e.g. Blind in a later change) sets the
# flag; default is always false in this change.
func has_blind_flag() -> bool:
	return false


func is_alive() -> bool:
	return current_hp > 0


# Override in subclasses that represent a species-keyed actor (e.g. MonsterCombatant).
# Used by Cast resolution to group/retarget by species. Returns &"" when the actor
# has no species (party members, generic test stubs).
func get_species_id() -> StringName:
	return &""


func take_damage(amount: int) -> int:
	var actual := amount
	if actual < 0:
		actual = 0
	if _defending and actual > 0:
		actual = maxi(actual / 2, 1)
	var hp_before := current_hp
	var new_hp := maxi(hp_before - actual, 0)
	_write_current_hp(new_hp)
	return hp_before - new_hp


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
