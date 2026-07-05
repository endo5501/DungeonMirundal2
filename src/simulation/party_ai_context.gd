class_name PartyAiContext
extends RefCounted

# Snapshot of battle state passed to PartyAi.choose. The AI SHALL NOT mutate
# any field; references (party / monsters / engine) are read-only inputs.

var party: Array          # Array[PartyCombatant]
var monsters: Array       # Array[MonsterCombatant]
var spell_repo: SpellRepository
var turn_engine: TurnEngine


func _init(
	p_party: Array,
	p_monsters: Array,
	p_spell_repo: SpellRepository,
	p_turn_engine: TurnEngine,
) -> void:
	party = p_party
	monsters = p_monsters
	spell_repo = p_spell_repo
	turn_engine = p_turn_engine
