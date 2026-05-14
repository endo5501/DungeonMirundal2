class_name MonsterData
extends Resource

@export var monster_id: StringName
@export var monster_name: String
@export var max_hp_min: int
@export var max_hp_max: int
@export var max_mp_min: int = 0
@export var max_mp_max: int = 0
@export var attack: int
@export var defense: int
@export var agility: int
@export var experience: int
@export var gold_min: int = 0
@export var gold_max: int = 0
@export var battle_texture: Texture2D
@export var resists: Dictionary = {}  # StringName -> float in [0, 1]
@export var known_spells: Array[StringName] = []
@export_enum("FRONT", "BACK") var default_row: int = Row.FRONT
@export_enum("MELEE", "RANGED") var attack_range: int = WeaponRange.MELEE
@export var tier: int = 1

const TIER_MIN := 1
const TIER_MAX := 5


func is_valid() -> bool:
	if monster_id == &"":
		return false
	if max_hp_min < 0:
		return false
	if max_hp_min > max_hp_max:
		return false
	if max_mp_min < 0:
		return false
	if max_mp_min > max_mp_max:
		return false
	if gold_min < 0:
		return false
	if gold_min > gold_max:
		return false
	if tier < TIER_MIN or tier > TIER_MAX:
		return false
	return true
