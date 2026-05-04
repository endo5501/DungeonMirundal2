class_name CastCommand
extends RefCounted

# Holds the parameters needed to resolve a Cast command in TurnEngine.
#
# - spell_id: id of the SpellData; resolved through the SpellRepository.
# - target: the originally-chosen target descriptor:
#     * ENEMY_ONE / ALLY_ONE → a single CombatActor.
#     * ENEMY_GROUP → a `MonsterData` instance (species key) OR a representative
#       MonsterCombatant whose `MonsterData` defines the group; the resolver
#       expands to all living MonsterCombatants of the same species.
#     * ALLY_ALL → null; the resolver targets all living party members.

var spell_id: StringName
var caster_index: int
var target: Variant


func _init(p_spell_id: StringName = &"", p_caster_index: int = -1, p_target: Variant = null) -> void:
	spell_id = p_spell_id
	caster_index = p_caster_index
	target = p_target
