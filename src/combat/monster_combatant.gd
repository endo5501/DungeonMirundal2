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
