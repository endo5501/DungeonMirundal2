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
	# Snapshot the living-actor pools once per choose() call; both pools are
	# invariant across the loops below.
	var enemies: Array = _living(ctx.party)
	var allies: Array = _living(ctx.monsters)
	var candidates: Array = _filter_candidates(monster, ctx, enemies, allies)
	if not candidates.is_empty():
		var pick_idx: int = rng.randi_range(0, candidates.size() - 1)
		var spell: SpellData = candidates[pick_idx]
		return _build_cast_command(spell, enemies, allies, rng)
	return _build_attack_command(monster, ctx, enemies, rng)


static func _filter_candidates(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
	enemies: Array,
	allies: Array,
) -> Array:
	var result: Array = []
	if monster.has_silence_flag():
		return result
	if ctx.spell_repo == null:
		return result
	var known: Array[StringName] = monster.get_known_spells()
	for spell_id in known:
		var spell: SpellData = ctx.spell_repo.find(spell_id)
		if spell == null:
			continue
		if monster.current_mp < spell.mp_cost:
			continue
		if not _target_precondition_holds(spell, enemies, allies):
			continue
		result.append(spell)
	return result


static func _target_precondition_holds(
	spell: SpellData,
	enemies: Array,
	allies: Array,
) -> bool:
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE:
			return enemies.size() >= 1
		SpellData.TargetType.ENEMY_GROUP:
			return enemies.size() >= 2
		SpellData.TargetType.ALLY_ONE:
			return _ally_one_target(spell, allies) != null
		SpellData.TargetType.ALLY_ALL:
			return allies.size() >= 1
	return false


static func _build_cast_command(
	spell: SpellData,
	enemies: Array,
	allies: Array,
	rng: RandomNumberGenerator,
) -> CastCommand:
	var target: Variant = _pick_target(spell, enemies, allies, rng)
	return CastCommand.new(spell.id, -1, target)


static func _pick_target(
	spell: SpellData,
	enemies: Array,
	allies: Array,
	rng: RandomNumberGenerator,
) -> Variant:
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE, SpellData.TargetType.ENEMY_GROUP:
			# Party has no species concept; any representative is fine — the
			# engine's _resolve_cast_targets fans out to all living party
			# members when species_id is empty.
			if enemies.is_empty():
				return null
			return enemies[rng.randi_range(0, enemies.size() - 1)]
		SpellData.TargetType.ALLY_ONE:
			return _ally_one_target(spell, allies)
		SpellData.TargetType.ALLY_ALL:
			return null
	return null


# Returns the best ALLY_ONE target for the given spell, or null when no ally
# satisfies the spell's precondition. Used by both the precondition filter and
# the target picker, so a spell that passes filtering always has a valid pick.
static func _ally_one_target(spell: SpellData, allies: Array) -> CombatActor:
	if allies.is_empty():
		return null
	var effect: SpellEffect = spell.effect
	if effect is HealSpellEffect:
		return _lowest_hp_wounded(allies)
	if effect is CureStatusSpellEffect:
		var sid: StringName = (effect as CureStatusSpellEffect).status_id
		if sid == &"":
			return null
		for a in allies:
			if a.statuses.has(sid):
				return a
		return null
	return allies[0]


static func _lowest_hp_wounded(allies: Array) -> CombatActor:
	var lowest: CombatActor = null
	for a in allies:
		if a.current_hp >= a.max_hp:
			continue
		if lowest == null or a.current_hp < lowest.current_hp:
			lowest = a
	return lowest


static func _build_attack_command(
	monster: MonsterCombatant,
	ctx: MonsterAiContext,
	enemies: Array,
	rng: RandomNumberGenerator,
) -> RefCounted:
	var reachable: Array = []
	var engine: TurnEngine = ctx.turn_engine
	for p in enemies:
		if engine != null and engine.can_reach(monster, p):
			reachable.append(p)
	if reachable.is_empty():
		# null lets TurnEngine pick the wait (MELEE attacker, party alive) vs
		# skip (no party alive) branch using its existing logic.
		return null
	var pick: CombatActor = reachable[rng.randi_range(0, reachable.size() - 1)]
	return AttackCommand.new(pick)


static func _living(pool: Array) -> Array:
	var result: Array = []
	for a in pool:
		if a != null and a.is_alive():
			result.append(a)
	return result
