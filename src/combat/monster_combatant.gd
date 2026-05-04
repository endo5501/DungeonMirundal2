class_name MonsterCombatant
extends CombatActor

var monster: Monster


func _init(p_monster: Monster) -> void:
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


func get_attack() -> int:
	if monster == null or monster.data == null:
		return 0
	return monster.data.attack


func get_defense() -> int:
	if monster == null or monster.data == null:
		return 0
	return monster.data.defense


func get_agility() -> int:
	if monster == null or monster.data == null:
		return 0
	return monster.data.agility
