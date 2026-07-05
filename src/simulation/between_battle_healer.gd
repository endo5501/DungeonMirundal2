class_name BetweenBattleHealer
extends RefCounted

# Between-battle greedy healer for the expedition simulator (design D4).
# Applies OUTSIDE_OK healing spells through the same path as the esc-menu
# SpellUseFlow until every living member is full or no caster can afford
# any healing spell.


static func heal_party(_characters: Array, _spell_repo: SpellRepository, _rng: RandomNumberGenerator) -> Array:
	return []
