class_name StubPartyCombatant
extends CombatActor

# Minimal CombatActor stub for combat tests that need a party member without
# constructing Character + EquipmentProvider. Mirrors PartyCombatant's MP/HP
# proxy behavior using internal fields.

var _hp: int
var _max: int
var _mp: int
var _mp_max: int
var _row: int


func _init(p_name: String, p_hp: int, p_mp: int = 0, p_row: int = Row.FRONT) -> void:
	super()
	actor_name = p_name
	_hp = p_hp
	_max = p_hp
	_mp = p_mp
	_mp_max = p_mp
	_row = p_row


func _read_current_hp() -> int:
	return _hp


func _write_current_hp(value: int) -> void:
	_hp = value


func _read_max_hp() -> int:
	return _max


func _read_current_mp() -> int:
	return _mp


func _write_current_mp(value: int) -> void:
	_mp = value


func _read_max_mp() -> int:
	return _mp_max


var original_row: int:
	get:
		return _row
