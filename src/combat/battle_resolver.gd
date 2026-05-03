class_name BattleResolver
extends RefCounted


static func resolve_rewards(turn_engine: TurnEngine, rng: RandomNumberGenerator) -> BattleSummary:
	if turn_engine == null:
		return BattleSummary.empty()
	var outcome := turn_engine.outcome()
	if outcome == null or outcome.result != EncounterOutcome.Result.CLEARED:
		return BattleSummary.empty()

	var participant_characters := _collect_participant_characters(turn_engine)
	var dead_monsters := _collect_dead_monsters(turn_engine)
	var levels_before: Array[int] = []
	for ch in participant_characters:
		levels_before.append(ch.level)

	var share := ExperienceCalculator.award(participant_characters, dead_monsters)
	var gold := _compute_gold_drop(dead_monsters, rng)
	var level_ups := _detect_level_ups(participant_characters, levels_before)
	return BattleSummary.new(share, gold, level_ups)


static func _collect_participant_characters(turn_engine: TurnEngine) -> Array:
	var result: Array = []
	if turn_engine == null:
		return result
	for pc in turn_engine.party:
		if pc is PartyCombatant and pc.character != null:
			result.append(pc.character)
	return result


static func _collect_dead_monsters(turn_engine: TurnEngine) -> Array:
	var result: Array = []
	if turn_engine == null:
		return result
	for mc in turn_engine.monsters:
		if mc is MonsterCombatant and not mc.is_alive() and mc.monster != null:
			result.append(mc.monster)
	return result


static func _compute_gold_drop(dead_monsters: Array, rng: RandomNumberGenerator) -> int:
	if rng == null:
		return 0
	var total := 0
	for m in dead_monsters:
		if m is Monster and m.data != null:
			total += rng.randi_range(m.data.gold_min, m.data.gold_max)
	return total


static func _detect_level_ups(participants: Array, levels_before: Array[int]) -> Array:
	var level_ups: Array = []
	for i in range(participants.size()):
		var ch: Character = participants[i]
		if ch.level > int(levels_before[i]):
			level_ups.append({"name": ch.character_name, "new_level": ch.level})
	return level_ups
