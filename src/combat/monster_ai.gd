class_name MonsterAi
extends RefCounted

# Stateless command-selection for MonsterCombatant turns.
#
# Returns one of:
#   - AttackCommand (target = one reachable living PartyCombatant)
#   - CastCommand (spell + resolved target descriptor)
#   - null (no reachable target for MELEE attacker / all party dead → wait or skip)
#
# The AI does not mutate engine state. The engine is consulted read-only
# (can_reach) through ctx.turn_engine.


static func choose(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
	rng: RandomNumberGenerator,
) -> RefCounted:
	if monster == null or ctx == null or rng == null:
		return null

	# 1. Try to find a castable spell first.
	var candidates: Array = _filter_candidates(monster, ctx)
	if not candidates.is_empty():
		var pick_idx: int = rng.randi_range(0, candidates.size() - 1)
		var spell: SpellData = candidates[pick_idx]
		return _build_cast_command(monster, ctx, spell, rng)

	# 2. No castable spell → physical attack on a reachable target.
	return _build_attack_command(monster, ctx, rng)


# --- candidate filter ---

static func _filter_candidates(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
) -> Array:
	var result: Array = []
	if monster == null or ctx == null:
		return result
	if monster.has_silence_flag():
		return result
	if ctx.spell_repo == null:
		return result
	if monster.monster == null or monster.monster.data == null:
		return result
	var known: Array = monster.monster.data.known_spells
	for spell_id in known:
		var spell: SpellData = ctx.spell_repo.find(spell_id)
		if spell == null:
			continue
		if monster.current_mp < spell.mp_cost:
			continue
		if not _target_precondition_holds(monster, ctx, spell):
			continue
		result.append(spell)
	return result


static func _target_precondition_holds(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
	spell: SpellData,
) -> bool:
	var enemies: Array = _living(ctx.party)
	var allies: Array = _living(ctx.monsters)
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE:
			return enemies.size() >= 1
		SpellData.TargetType.ENEMY_GROUP:
			return enemies.size() >= 2
		SpellData.TargetType.ALLY_ONE:
			return _ally_one_precondition(monster, allies, spell)
		SpellData.TargetType.ALLY_ALL:
			return allies.size() >= 1
	return false


static func _ally_one_precondition(
	_monster: MonsterCombatant,
	allies: Array,
	spell: SpellData,
) -> bool:
	if allies.is_empty():
		return false
	var effect: SpellEffect = spell.effect
	# HealSpellEffect → need a wounded ally
	if effect is HealSpellEffect:
		for a in allies:
			if a.current_hp < a.max_hp:
				return true
		return false
	# CureStatusSpellEffect → need an ally holding that status
	if effect is CureStatusSpellEffect:
		var sid: StringName = (effect as CureStatusSpellEffect).status_id
		if sid == &"":
			return false
		for a in allies:
			if a.statuses.has(sid):
				return true
		return false
	# StatModSpellEffect → buff (delta > 0) needs a living ally; debuff against
	# self is a no-op so v1 just allows it as long as ally is alive.
	# Other effect types fall through and allow casting on any living ally.
	return true


# --- command construction ---

static func _build_cast_command(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
	spell: SpellData,
	rng: RandomNumberGenerator,
) -> CastCommand:
	var target: Variant = _pick_target(monster, ctx, spell, rng)
	return CastCommand.new(spell.id, -1, target)


static func _pick_target(
	_monster: MonsterCombatant,
	ctx: MonsterAiContext,
	spell: SpellData,
	rng: RandomNumberGenerator,
) -> Variant:
	var enemies: Array = _living(ctx.party)
	var allies: Array = _living(ctx.monsters)
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE:
			if enemies.is_empty():
				return null
			return enemies[rng.randi_range(0, enemies.size() - 1)]
		SpellData.TargetType.ENEMY_GROUP:
			if enemies.is_empty():
				return null
			# Party has no species concept; any representative is fine — the
			# engine's _resolve_cast_targets fans out to all living party
			# members when species_id is empty.
			return enemies[rng.randi_range(0, enemies.size() - 1)]
		SpellData.TargetType.ALLY_ONE:
			return _pick_ally_one(allies, spell)
		SpellData.TargetType.ALLY_ALL:
			return null
	return null


static func _pick_ally_one(allies: Array, spell: SpellData) -> Variant:
	if allies.is_empty():
		return null
	var effect: SpellEffect = spell.effect
	if effect is HealSpellEffect:
		# Lowest-HP wounded ally
		var lowest: CombatActor = null
		for a in allies:
			if a.current_hp >= a.max_hp:
				continue
			if lowest == null or a.current_hp < lowest.current_hp:
				lowest = a
		if lowest != null:
			return lowest
		# Precondition should have filtered this case, but be defensive
		return allies[0]
	if effect is CureStatusSpellEffect:
		var sid: StringName = (effect as CureStatusSpellEffect).status_id
		for a in allies:
			if a.statuses.has(sid):
				return a
		return allies[0]
	return allies[0]


static func _build_attack_command(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
	rng: RandomNumberGenerator,
) -> RefCounted:
	var reachable: Array = []
	var engine: TurnEngine = ctx.turn_engine
	for p in ctx.party:
		if p == null or not p.is_alive():
			continue
		if engine != null and engine.can_reach(monster, p):
			reachable.append(p)
	if reachable.is_empty():
		# null lets TurnEngine pick the wait (MELEE attacker, party alive) vs
		# skip (no party alive) branch using its existing logic.
		return null
	var pick: CombatActor = reachable[rng.randi_range(0, reachable.size() - 1)]
	return AttackCommand.new(pick)


# --- utilities ---

static func _living(pool: Array) -> Array:
	var result: Array = []
	for a in pool:
		if a != null and a.is_alive():
			result.append(a)
	return result
