class_name MonsterCombatant
extends CombatActor

var monster: Monster


func _init(p_monster: Monster) -> void:
	super()
	monster = p_monster
	if monster != null and monster.data != null:
		actor_name = monster.data.monster_name


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


# v1 monsters do not have MP; max_mp is always 0 and writes are ignored.
func _read_current_mp() -> int:
	return 0


func _write_current_mp(_value: int) -> void:
	pass


func _read_max_mp() -> int:
	return 0


# v1 monsters cannot cast: any positive spend is rejected.
func spend_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	return false


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
