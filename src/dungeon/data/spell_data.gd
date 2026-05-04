class_name SpellData
extends Resource

enum TargetType {
	ENEMY_ONE = 0,
	ENEMY_GROUP = 1,
	ALLY_ONE = 2,
	ALLY_ALL = 3,
}

enum Scope {
	BATTLE_ONLY = 0,
	OUTSIDE_OK = 1,
}

const SCHOOL_MAGE: StringName = &"mage"
const SCHOOL_PRIEST: StringName = &"priest"

@export var id: StringName
@export var display_name: String
@export var school: StringName
@export var level: int
@export var mp_cost: int
@export_enum("ENEMY_ONE", "ENEMY_GROUP", "ALLY_ONE", "ALLY_ALL") var target_type: int
@export_enum("BATTLE_ONLY", "OUTSIDE_OK") var scope: int
@export var effect: SpellEffect


func is_battle_only() -> bool:
	return scope == Scope.BATTLE_ONLY


func is_outside_ok() -> bool:
	return scope == Scope.OUTSIDE_OK


func is_mage_school() -> bool:
	return school == SCHOOL_MAGE


func is_priest_school() -> bool:
	return school == SCHOOL_PRIEST
