class_name BetweenBattleHealer
extends RefCounted

# Between-battle greedy healer for the expedition simulator (design D4).
#
# Repeatedly picks the living party member with the lowest HP ratio and casts
# the affordable OUTSIDE_OK healing spell whose expected heal minimizes
# overheal for that member's missing HP (smallest sufficient expected heal;
# if none is sufficient, the largest available). Stops when every living
# member is at full HP or no caster can afford any healing spell.
#
# Spell application reuses the exact path of the esc-menu SpellUseFlow
# (_apply_cast_and_show_result): deduct mp_cost from Character.current_mp,
# wrap caster and target in PartyCombatant (DummyEquipmentProvider) so
# SpellEffect.apply reads/writes current_hp / max_hp uniformly, then call
# spell.effect.apply(caster, targets, SpellRng) which caps HP at max_hp.

# Safety guard against pathological spell data (e.g. a zero-cost heal that
# somehow never closes the HP gap). Normal termination comes from MP strictly
# decreasing (mp_cost >= 1) or target HP strictly increasing (heal >= 1).
const MAX_CASTS: int = 10000


static func heal_party(characters: Array, spell_repo: SpellRepository, rng: RandomNumberGenerator) -> Array:
	var casts_log: Array = []
	if spell_repo == null:
		return casts_log
	var spell_rng := SpellRng.new(rng)
	var provider := DummyEquipmentProvider.new()
	while casts_log.size() < MAX_CASTS:
		var target: Character = _most_injured_living(characters)
		if target == null:
			break
		var choice: Dictionary = _best_cast_for(characters, spell_repo, target)
		if choice.is_empty():
			break
		var caster: Character = choice["caster"]
		var spell: SpellData = choice["spell"]
		var healed := _apply_cast(caster, spell, target, provider, spell_rng)
		casts_log.append({
			"caster": caster,
			"spell_id": spell.id,
			"target": target,
			"healed": healed,
		})
	return casts_log


# Returns the living member with the lowest HP ratio, or null when every
# living member is already at full HP (or nobody is alive).
static func _most_injured_living(characters: Array) -> Character:
	var best: Character = null
	var best_ratio := 1.0
	for ch: Character in characters:
		if ch == null or ch.is_dead() or ch.max_hp <= 0:
			continue
		if ch.current_hp >= ch.max_hp:
			continue
		var ratio := float(ch.current_hp) / float(ch.max_hp)
		if best == null or ratio < best_ratio:
			best = ch
			best_ratio = ratio
	return best


# Enumerates every living member's known spells that are OUTSIDE_OK healing
# effects affordable with that caster's current MP, and picks the (caster,
# spell) pair minimizing overheal against `target`'s missing HP.
# Returns {"caster": Character, "spell": SpellData} or {} when nothing is
# castable.
static func _best_cast_for(characters: Array, spell_repo: SpellRepository, target: Character) -> Dictionary:
	var missing := target.max_hp - target.current_hp
	var best_sufficient: Dictionary = {}
	var best_sufficient_heal := 0
	var best_insufficient: Dictionary = {}
	var best_insufficient_heal := 0
	for ch: Character in characters:
		if ch == null or ch.is_dead():
			continue
		if ch.job == null or not ch.job.is_magic_capable():
			continue
		for sid in ch.known_spells:
			var spell: SpellData = spell_repo.find(sid)
			if spell == null:
				continue
			if spell.scope != SpellData.Scope.OUTSIDE_OK:
				continue
			if not (spell.effect is HealSpellEffect):
				continue
			if ch.current_mp < spell.mp_cost:
				continue
			var expected := _expected_heal(spell.effect as HealSpellEffect)
			if expected >= missing:
				if best_sufficient.is_empty() or expected < best_sufficient_heal:
					best_sufficient = {"caster": ch, "spell": spell}
					best_sufficient_heal = expected
			else:
				if best_insufficient.is_empty() or expected > best_insufficient_heal:
					best_insufficient = {"caster": ch, "spell": spell}
					best_insufficient_heal = expected
	if not best_sufficient.is_empty():
		return best_sufficient
	return best_insufficient


# The spread roll is symmetric around zero, so the expected heal is base_heal
# (floored at 1 to mirror HealSpellEffect's minimum).
static func _expected_heal(effect: HealSpellEffect) -> int:
	return maxi(effect.base_heal, 1)


# Mirrors SpellUseFlow._apply_cast_and_show_result: deduct MP from the
# Character, then apply the effect through PartyCombatant wrappers so HP is
# capped at max_hp exactly as in real out-of-combat play.
static func _apply_cast(
	caster: Character,
	spell: SpellData,
	target: Character,
	provider: EquipmentProvider,
	spell_rng: SpellRng
) -> int:
	caster.current_mp = maxi(caster.current_mp - spell.mp_cost, 0)
	var caster_pc := PartyCombatant.new(caster, provider)
	var targets: Array = [PartyCombatant.new(target, provider)]
	var before := target.current_hp
	if spell.effect != null:
		spell.effect.apply(caster_pc, targets, spell_rng)
	return target.current_hp - before
