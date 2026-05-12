class_name MonsterCombatant
extends CombatActor

var monster: Monster


func _init(p_monster: Monster) -> void:
	super()
	monster = p_monster
	if monster != null and monster.data != null:
		actor_name = monster.data.monster_name


# Row is sourced from MonsterData so the data is the single source of truth.
# Tests / encounter generators that need a non-default row should set it on
# MonsterData (or use a temp data instance) before constructing the combatant.
var original_row: int:
	get:
		if monster != null and monster.data != null:
			return monster.data.default_row
		return Row.FRONT


func _read_current_hp() -> int:
	if monster == null:
		return 0
	return monster.current_hp


func _write_current_hp(value: int) -> void:
	if monster != null:
		monster.current_hp = value


func _read_max_hp() -> int:
	if monster == null:
		return 0
	return monster.max_hp


func _read_current_mp() -> int:
	if monster == null:
		return 0
	return monster.current_mp


func _write_current_mp(value: int) -> void:
	if monster != null:
		monster.current_mp = value


func _read_max_mp() -> int:
	if monster == null:
		return 0
	return monster.max_mp


func get_data() -> MonsterData:
	if monster == null:
		return null
	return monster.data


func get_known_spells() -> Array[StringName]:
	var data := get_data()
	if data == null:
		return []
	return data.known_spells


func get_species_id() -> StringName:
	if monster == null or monster.data == null:
		return &""
	return monster.data.monster_id


func _get_base_attack() -> int:
	if monster == null or monster.data == null:
		return 0
	return monster.data.attack


func _get_base_defense() -> int:
	if monster == null or monster.data == null:
		return 0
	return monster.data.defense


func _get_base_agility() -> int:
	if monster == null or monster.data == null:
		return 0
	return monster.data.agility


# Monster resistance comes straight from MonsterData.resists. Negative values
# are preserved (e.g. an undead vulnerable to holy); the [0, 1] clamp applies
# only at the inflict-chance site (StatusInflictHelper).
func get_resist(resist_key: StringName) -> float:
	if resist_key == &"" or monster == null or monster.data == null:
		return 0.0
	return float(monster.data.resists.get(resist_key, 0.0))
