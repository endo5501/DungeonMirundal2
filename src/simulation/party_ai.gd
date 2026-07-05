class_name PartyAi
extends RefCounted

# Stateless command-selection for PartyCombatant turns in simulation.
#
# Priority per member (design D2):
#   1. priest_school + wounded ally at/below heal_hp_threshold + affordable
#      healing spell → CastCommand healing the lowest-HP-ratio living ally,
#      picking the spell with minimal overheal.
#   2. mage_school + affordable damage spell (DamageSpellEffect /
#      DamageWithStatusSpellEffect only) + MP-conservation knob satisfied
#      (living enemies >= attack_magic_min_enemies, or max enemy tier >=
#      attack_magic_min_tier when that knob is enabled) → attack CastCommand,
#      preferring ENEMY_GROUP when 2+ enemies are alive.
#   3. AttackCommand on the first living reachable enemy; DefendCommand when
#      nothing is reachable.
#
# The AI does not mutate engine state. The engine is consulted read-only
# (can_reach) through ctx.turn_engine.


static func choose(
	member: PartyCombatant,
	ctx: PartyAiContext,
	config: PartyAiConfig,
	rng: RandomNumberGenerator,
) -> RefCounted:
	if member == null or ctx == null or config == null or rng == null:
		return DefendCommand.new()
	var enemies: Array = _living(ctx.monsters)
	var allies: Array = _living(ctx.party)
	var heal_cmd: CastCommand = _try_heal(member, ctx, config, allies)
	if heal_cmd != null:
		return heal_cmd
	var attack_cast_cmd: CastCommand = _try_attack_magic(member, ctx, config, enemies)
	if attack_cast_cmd != null:
		return attack_cast_cmd
	return _build_physical_command(member, ctx, enemies)


# --- Priority 1: healing ---

static func _try_heal(
	member: PartyCombatant,
	ctx: PartyAiContext,
	config: PartyAiConfig,
	allies: Array,
) -> CastCommand:
	if not _job_flag(member, true):
		return null
	var target: CombatActor = _lowest_hp_ratio_at_or_below(allies, config.heal_hp_threshold)
	if target == null:
		return null
	var spell: SpellData = _pick_heal_spell(member, ctx, target)
	if spell == null:
		return null
	return CastCommand.new(spell.id, -1, target)


static func _lowest_hp_ratio_at_or_below(allies: Array, threshold: float) -> CombatActor:
	var lowest: CombatActor = null
	var lowest_ratio := 1.0
	for a in allies:
		if a.max_hp <= 0:
			continue
		var ratio := float(a.current_hp) / float(a.max_hp)
		if ratio > threshold:
			continue
		if lowest == null or ratio < lowest_ratio:
			lowest = a
			lowest_ratio = ratio
	return lowest


# Picks the affordable healing spell whose expected heal (HealSpellEffect
# base_heal; symmetric spread has zero expectation) best covers the target's
# missing HP: the smallest sufficient spell, or the largest available when
# none is sufficient.
static func _pick_heal_spell(
	member: PartyCombatant,
	ctx: PartyAiContext,
	target: CombatActor,
) -> SpellData:
	var missing: int = target.max_hp - target.current_hp
	var best_sufficient: SpellData = null
	var best_insufficient: SpellData = null
	for spell in _affordable_known_spells(member, ctx):
		if not (spell.effect is HealSpellEffect):
			continue
		if spell.target_type != SpellData.TargetType.ALLY_ONE:
			continue
		var expected: int = (spell.effect as HealSpellEffect).base_heal
		if expected >= missing:
			if best_sufficient == null or expected < (best_sufficient.effect as HealSpellEffect).base_heal:
				best_sufficient = spell
		else:
			if best_insufficient == null or expected > (best_insufficient.effect as HealSpellEffect).base_heal:
				best_insufficient = spell
	if best_sufficient != null:
		return best_sufficient
	return best_insufficient


# --- Priority 2: attack magic ---

static func _try_attack_magic(
	member: PartyCombatant,
	ctx: PartyAiContext,
	config: PartyAiConfig,
	enemies: Array,
) -> CastCommand:
	if not _job_flag(member, false):
		return null
	if enemies.is_empty():
		return null
	if not _knobs_allow_attack_magic(config, enemies):
		return null
	var group_spell: SpellData = null
	var single_spell: SpellData = null
	for spell in _affordable_known_spells(member, ctx):
		# Only damage-dealing effects qualify as attack magic; status-only
		# spells (e.g. katino/sleep) must not be burned here.
		if not _is_damage_effect(spell):
			continue
		match spell.target_type:
			SpellData.TargetType.ENEMY_GROUP:
				if group_spell == null:
					group_spell = spell
			SpellData.TargetType.ENEMY_ONE:
				if single_spell == null:
					single_spell = spell
	# Design D2: aim at the living enemy with the highest HP (group spells use
	# it as the species representative).
	var target: CombatActor = _highest_hp(enemies)
	if enemies.size() >= 2 and group_spell != null:
		return CastCommand.new(group_spell.id, -1, target)
	if single_spell != null:
		return CastCommand.new(single_spell.id, -1, target)
	return null


static func _is_damage_effect(spell: SpellData) -> bool:
	return spell.effect is DamageSpellEffect or spell.effect is DamageWithStatusSpellEffect


static func _knobs_allow_attack_magic(config: PartyAiConfig, enemies: Array) -> bool:
	if enemies.size() >= config.attack_magic_min_enemies:
		return true
	if config.attack_magic_min_tier > 0 and _max_tier(enemies) >= config.attack_magic_min_tier:
		return true
	return false


static func _highest_hp(enemies: Array) -> CombatActor:
	var best: CombatActor = null
	for e in enemies:
		if best == null or e.current_hp > best.current_hp:
			best = e
	return best


static func _max_tier(enemies: Array) -> int:
	var max_tier := 0
	for e in enemies:
		if e is MonsterCombatant:
			var data: MonsterData = (e as MonsterCombatant).get_data()
			if data != null and data.tier > max_tier:
				max_tier = data.tier
	return max_tier


# --- Priority 3: physical attack / defend ---

static func _build_physical_command(
	member: PartyCombatant,
	ctx: PartyAiContext,
	enemies: Array,
) -> RefCounted:
	var engine: TurnEngine = ctx.turn_engine
	for e in enemies:
		if engine != null and engine.can_reach(member, e):
			return AttackCommand.new(e)
	return DefendCommand.new()


# --- Shared helpers ---

static func _job_flag(member: PartyCombatant, priest: bool) -> bool:
	if member.character == null or member.character.job == null:
		return false
	if priest:
		return member.character.job.priest_school
	return member.character.job.mage_school


static func _affordable_known_spells(member: PartyCombatant, ctx: PartyAiContext) -> Array:
	var result: Array = []
	if ctx.spell_repo == null or member.character == null:
		return result
	if member.has_silence_flag():
		return result
	for sid in member.character.known_spells:
		var spell: SpellData = ctx.spell_repo.find(sid)
		if spell == null:
			continue
		if member.current_mp < spell.mp_cost:
			continue
		result.append(spell)
	return result


static func _living(pool: Array) -> Array:
	var result: Array = []
	for a in pool:
		if a != null and a.is_alive():
			result.append(a)
	return result
