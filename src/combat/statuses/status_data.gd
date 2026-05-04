class_name StatusData
extends Resource

enum Scope {
	BATTLE_ONLY = 0,
	PERSISTENT = 1,
}

# Flag identifiers consumed by StatusTrack.any_with_flag — explicit dispatch
# avoids `Resource.get(StringName)` typos silently coercing to false.
enum Flag {
	PREVENTS_ACTION,
	RANDOMIZES_TARGET,
	BLOCKS_CAST,
}

const FLAG_PREVENTS_ACTION := Flag.PREVENTS_ACTION
const FLAG_RANDOMIZES_TARGET := Flag.RANDOMIZES_TARGET
const FLAG_BLOCKS_CAST := Flag.BLOCKS_CAST

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("BATTLE_ONLY", "PERSISTENT") var scope: int = Scope.BATTLE_ONLY

# Action / behavior modifiers
@export var prevents_action: bool = false
@export var randomizes_target: bool = false
@export var blocks_cast: bool = false
@export var hit_penalty: float = 0.0

# Duration & ticks
@export var default_duration: int = 0
@export var tick_in_battle: int = 0
@export var tick_in_dungeon: int = 0
@export var tick_in_dungeon_ratio: int = 0

# Cure conditions
@export var cures_on_damage: bool = false
@export var cures_on_battle_end: bool = false

# Resistance lookup key against {Race,Job,Monster}Data.resists
@export var resist_key: StringName = &""
