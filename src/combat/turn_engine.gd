class_name TurnEngine
extends RefCounted

enum State {
	IDLE,
	COMMAND_INPUT,
	RESOLVING,
	FINISHED,
}

enum ItemResolution {
	NORMAL,
	TOWN_ESCAPE,
}

var state: State = State.IDLE
var party: Array = []  # Array[PartyCombatant or CombatActor-compatible]
var monsters: Array = []  # Array[MonsterCombatant or CombatActor-compatible]
var turn_number: int = 0
var escape_threshold: float = 0.5
var inventory: Inventory = null  # Optional; set to remove consumed ItemCommand instances
var spell_repo: SpellRepository = null  # Optional override; lazy-loaded via DataLoader if null.
var status_repo: StatusRepository = null  # Optional override; lazy-loaded via DataLoader if null.

var _pending_commands: Dictionary = {}  # int index -> Command
var _outcome: EncounterOutcome
# Cached `party + monsters` rebuilt in start_battle so per-turn allocations
# (status tick, confusion target pool, battle-end cleanup) reuse one Array.
var _all_actors: Array = []


func start_battle(p_party: Array, p_monsters: Array) -> void:
	party = p_party
	monsters = p_monsters
	_all_actors = []
	_all_actors.append_array(party)
	_all_actors.append_array(monsters)
	turn_number = 1
	_pending_commands.clear()
	_outcome = null
	state = State.COMMAND_INPUT


func submit_command(party_index: int, command) -> void:
	if state != State.COMMAND_INPUT:
		return
	_pending_commands[party_index] = command


func are_party_commands_complete() -> bool:
	for i in range(party.size()):
		var actor: CombatActor = party[i]
		if actor == null:
			continue
		if actor.is_alive() and not _pending_commands.has(i):
			return false
	return true


func outcome() -> EncounterOutcome:
	return _outcome


func resolve_turn(rng: RandomNumberGenerator) -> TurnReport:
	var report := TurnReport.new()
	if state != State.COMMAND_INPUT:
		return report
	state = State.RESOLVING

	# Tick at the head of every turn. We only terminate early on a wipe that
	# the tick itself caused — otherwise a pre-existing dead state would skip
	# the action loop and break cast/item resolution semantics.
	var tick_caused_kill := _tick_statuses_for_all(report)
	if tick_caused_kill:
		if _all_monsters_dead():
			_finish_with_battle_end_cleanup(report, EncounterOutcome.Result.CLEARED)
			return report
		if _all_party_dead():
			_finish_with_battle_end_cleanup(report, EncounterOutcome.Result.WIPED)
			return report

	# Apply Defend commands first so defender flag is set for the whole turn.
	# Commands share no class hierarchy; the closest common static type is RefCounted.
	for i in range(party.size()):
		var cmd: RefCounted = _pending_commands.get(i, null) as RefCounted
		if cmd == null:
			continue
		if cmd is DefendCommand:
			(cmd as DefendCommand).apply_to(party[i])
			report.add_defend(party[i])

	# Handle Escape as a party-level roll (one roll regardless of how many submitted).
	var any_escape := false
	for i in range(party.size()):
		if _pending_commands.get(i, null) is EscapeCommand:
			any_escape = true
			break
	var escape_succeeded := false
	if any_escape:
		escape_succeeded = rng.randf() < escape_threshold
		report.add_escape(escape_succeeded)
		if escape_succeeded:
			_finish_with_battle_end_cleanup(report, EncounterOutcome.Result.ESCAPED)
			return report

	var order: Array = TurnOrder.order(_all_actors, rng)

	var early_escape_town := false
	for actor in order:
		if not actor.is_alive():
			continue

		# action_lock blocks ALL command types (including item/cast/attack).
		if actor.has_action_lock():
			report.add_action_locked(actor)
			continue

		if _is_party_member(actor):
			if any_escape and not escape_succeeded:
				# Party offense forfeited on failed escape.
				continue
			var idx := party.find(actor)
			if idx < 0:
				continue
			var cmd: RefCounted = _pending_commands.get(idx, null) as RefCounted
			if cmd == null:
				continue

			# Confusion swaps any command with a single AttackCommand against a
			# uniformly-random living combatant (party + monsters minus self).
			if actor.has_confusion_flag():
				var random_target := _pick_random_living_excluding(actor, rng)
				if random_target != null:
					_resolve_attack(actor, random_target, rng, report, true)
				continue

			if cmd is ItemCommand:
				var handled := _resolve_item(actor, cmd as ItemCommand, report)
				if handled == ItemResolution.TOWN_ESCAPE:
					early_escape_town = true
					break
				continue
			if cmd is AttackCommand:
				_resolve_attack(actor, cmd.target, rng, report)
			elif cmd is CastCommand:
				if actor.has_silence_flag():
					report.add_cast_silenced(actor, (cmd as CastCommand).spell_id)
					continue
				_resolve_cast(actor, cmd as CastCommand, rng, report)
		else:
			# Monsters: confusion still applies (random target including allies).
			if actor.has_confusion_flag():
				var random_target := _pick_random_living_excluding(actor, rng)
				if random_target != null:
					_resolve_attack(actor, random_target, rng, report, true)
				continue
			var target: CombatActor = _pick_living_party(rng)
			if target != null:
				_resolve_attack(actor, target, rng, report)
		# Stop processing later actors as soon as either side is wiped.
		if _all_monsters_dead() or _all_party_dead():
			break

	if early_escape_town:
		_finish_with_battle_end_cleanup(report, EncounterOutcome.Result.ESCAPED)
		if _outcome != null:
			_outcome.request_town_return = true
		return report

	var monsters_dead := _all_monsters_dead()
	var party_dead := _all_party_dead()
	if monsters_dead:
		_finish_with_battle_end_cleanup(report, EncounterOutcome.Result.CLEARED)
	elif party_dead:
		_finish_with_battle_end_cleanup(report, EncounterOutcome.Result.WIPED)
	else:
		_end_turn_cleanup()
		turn_number += 1
		state = State.COMMAND_INPUT

	return report


func _tick_statuses_for_all(report: TurnReport) -> bool:
	var repo := get_status_repo()
	var any_kill := false
	for actor in _all_actors:
		if actor == null:
			continue
		var ticks: Array = actor.statuses.tick_battle_turn(actor, repo)
		for t in ticks:
			var killed := bool(t.get("killed_by_tick", false))
			report.add_tick_damage(
				actor,
				t.get("status_id"),
				int(t.get("hp_loss", 0)),
				killed,
			)
			if killed:
				any_kill = true
		# Damage from a tick still triggers cures_on_damage (e.g. poison
		# tick on a sleeper would wake the sleeper).
		if not ticks.is_empty():
			_apply_damage_taken_cure(actor, report)
	return any_kill


func _apply_damage_taken_cure(actor, report: TurnReport) -> void:
	if actor == null:
		return
	var repo := get_status_repo()
	var cured: Array[StringName] = actor.statuses.handle_damage_taken(actor, repo)
	for sid in cured:
		report.add_wake(actor, sid)


# Picks a uniformly-random alive combatant from (party + monsters) minus `self_actor`.
# Used by confusion command swap.
func _pick_random_living_excluding(self_actor, rng: RandomNumberGenerator) -> CombatActor:
	var pool: Array = []
	for a in _all_actors:
		if a == null or a == self_actor:
			continue
		if a.is_alive():
			pool.append(a)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func _resolve_item(actor: CombatActor, cmd: ItemCommand, report: TurnReport) -> ItemResolution:
	if cmd == null or cmd.item_instance == null:
		return ItemResolution.NORMAL
	var item: Item = cmd.item_instance.item
	var item_name: String = item.item_name if item != null else ""
	if not actor.is_alive():
		cmd.cancelled = true
		report.add_item_cancelled(actor, item_name)
		return ItemResolution.NORMAL
	var targets: Array = []
	if cmd.target != null:
		targets.append(_character_of(cmd.target))
	var ctx := ItemUseContext.make(true, true, [])
	# Atomic validate-and-consume via Inventory; guards against duplicate ItemCommands
	# pointing at the same instance and against target state changing mid-turn
	# (e.g. AliveOnly now failing because the target was KO'd earlier in the order).
	var result: ItemEffectResult
	if inventory != null:
		result = inventory.use_item(cmd.item_instance, targets, ctx)
	elif item.effect != null:
		result = item.effect.apply(targets, ctx)
	if result == null or not result.success:
		cmd.cancelled = true
		report.add_item_cancelled(actor, item_name)
		return ItemResolution.NORMAL
	report.add_item_use(actor, item_name, cmd.target, result.message)
	if result.request_town_return:
		return ItemResolution.TOWN_ESCAPE
	return ItemResolution.NORMAL


func _character_of(combatant: CombatActor):
	if combatant is PartyCombatant:
		return (combatant as PartyCombatant).character
	return combatant


func _resolve_attack(
	attacker: CombatActor,
	target: CombatActor,
	rng: RandomNumberGenerator,
	report: TurnReport,
	confusion_swap: bool = false
) -> void:
	var effective_target: CombatActor = target
	var retargeted_from := ""
	if effective_target == null or not effective_target.is_alive():
		retargeted_from = effective_target.actor_name if effective_target != null else ""
		effective_target = _pick_living_same_side_as(target, attacker)
	if effective_target == null:
		return
	var result := DamageCalculator.calculate(attacker, effective_target, rng)
	if not result.hit:
		report.add_miss(attacker, effective_target, confusion_swap)
		return
	var defended := effective_target.is_defending()
	var applied := effective_target.take_damage(result.amount)
	report.add_attack(attacker, effective_target, applied, defended, retargeted_from, confusion_swap)
	if applied > 0:
		_apply_damage_taken_cure(effective_target, report)
	if not effective_target.is_alive():
		report.add_defeated(effective_target)


func _resolve_cast(caster: CombatActor, cmd: CastCommand, rng: RandomNumberGenerator, report: TurnReport) -> void:
	var repo := get_spell_repo()
	if repo == null:
		push_warning("TurnEngine: no SpellRepository available; cast aborted")
		return
	var spell: SpellData = repo.find(cmd.spell_id)
	if spell == null:
		push_warning("TurnEngine: unknown spell id %s; cast aborted" % cmd.spell_id)
		return
	var resolution := _resolve_cast_targets(caster, cmd, spell)
	var targets: Array = resolution["targets"]
	var retargeted_from: String = resolution["retargeted_from"]
	# Pre-check: refuse cast (without consuming MP) if there is no valid target.
	if targets.is_empty():
		report.add_cast_skipped_no_target(caster, spell)
		return
	if not caster.spend_mp(spell.mp_cost):
		report.add_cast_skipped_no_mp(caster, spell)
		return
	var spell_resolution: SpellResolution = spell.effect.apply(caster, targets, SpellRng.new(rng)) if spell.effect != null else SpellResolution.new()
	report.add_cast(caster, spell, spell_resolution, retargeted_from)
	# Translate per-target SpellResolution events (inflict/cure/resist) into
	# top-level TurnReport actions so CombatLog can render them as their own
	# lines instead of falling through to "効果はなかった".
	if spell_resolution != null:
		for e in spell_resolution.entries:
			var actor: CombatActor = e.get("actor")
			for evt in e.get("events", []):
				match evt.get("type"):
					"inflict":
						if bool(evt.get("success", false)):
							report.add_inflict(actor, evt.get("status_id", &""), true)
					"resist":
						report.add_resist(actor, evt.get("status_id", &""))
					"cure":
						report.add_cure(actor, evt.get("status_id", &""))
	# After cast: any target that took damage from the spell may have a
	# cures_on_damage status to wake from.
	if spell_resolution != null:
		for e in spell_resolution.entries:
			if int(e.get("hp_delta", 0)) < 0:
				_apply_damage_taken_cure(e.get("actor"), report)
	for t in targets:
		if t != null and not t.is_alive():
			report.add_defeated(t)


func _resolve_cast_targets(caster: CombatActor, cmd: CastCommand, spell: SpellData) -> Dictionary:
	var result: Dictionary = {"targets": [], "retargeted_from": ""}
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE:
			var enemy: CombatActor = cmd.target as CombatActor
			if enemy != null and enemy.is_alive():
				result["targets"] = [enemy]
			else:
				var original_name := enemy.actor_name if enemy != null else ""
				var fallback := _pick_alive_replacement(enemy, monsters)
				if fallback != null:
					result["targets"] = [fallback]
					result["retargeted_from"] = original_name
		SpellData.TargetType.ENEMY_GROUP:
			var species_id := _species_id_of(cmd.target)
			var collected: Array = []
			for m in monsters:
				if m == null or not m.is_alive():
					continue
				if species_id == &"" or _species_id_of(m) == species_id:
					collected.append(m)
			result["targets"] = collected
		SpellData.TargetType.ALLY_ONE:
			var ally: CombatActor = cmd.target as CombatActor
			if ally != null and ally.is_alive():
				result["targets"] = [ally]
			else:
				var original_name := ally.actor_name if ally != null else ""
				var fallback := _pick_alive_replacement(ally, party)
				if fallback != null:
					result["targets"] = [fallback]
					result["retargeted_from"] = original_name
		SpellData.TargetType.ALLY_ALL:
			var party_targets: Array = []
			for p in party:
				if p != null and p.is_alive():
					party_targets.append(p)
			result["targets"] = party_targets
	return result


# Pick a living member of `pool`, preferring same species (when applicable) over
# the original `original` actor.
func _pick_alive_replacement(original: CombatActor, pool: Array) -> CombatActor:
	var original_species := _species_id_of(original)
	if original_species != &"":
		for c in pool:
			if c == null or not c.is_alive():
				continue
			if c == original:
				continue
			if _species_id_of(c) == original_species:
				return c
	for c in pool:
		if c == null or not c.is_alive():
			continue
		if c == original:
			continue
		return c
	return null


# Returns the species id for a CombatActor (e.g. MonsterData.monster_id for monsters).
# Party members and species-less actors return &"". MonsterData branch supports
# CastCommand targets that pass a species key directly instead of a combatant.
func _species_id_of(actor) -> StringName:
	if actor is CombatActor:
		return (actor as CombatActor).get_species_id()
	if actor is MonsterData:
		return (actor as MonsterData).monster_id
	return &""


func get_spell_repo() -> SpellRepository:
	if spell_repo == null:
		var loader := DataLoader.new()
		spell_repo = loader.load_spell_repository()
	return spell_repo


func get_status_repo() -> StatusRepository:
	if status_repo == null:
		status_repo = DataLoader.new().load_status_repository()
	return status_repo


func _pick_living_party(rng: RandomNumberGenerator) -> CombatActor:
	var alive: Array = []
	for a in party:
		if a.is_alive():
			alive.append(a)
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]


func _pick_living_same_side_as(original: CombatActor, attacker: CombatActor) -> CombatActor:
	# If the original target was a monster (attacker is party), pick another living monster.
	# If the original target was a party (attacker is monster), pick another living party.
	var attacker_is_party := _is_party_member(attacker)
	var pool: Array = monsters if attacker_is_party else party
	for a in pool:
		if a != null and a.is_alive():
			return a
	return null


func _is_party_member(actor: CombatActor) -> bool:
	return party.has(actor)


func _all_monsters_dead() -> bool:
	for m in monsters:
		if m.is_alive():
			return false
	return true


func _all_party_dead() -> bool:
	for p in party:
		if p.is_alive():
			return false
	return true


func _end_turn_cleanup() -> void:
	for a in party:
		if a != null:
			a.clear_turn_flags()
			a.modifier_stack.tick_battle_turn()
	for m in monsters:
		if m != null:
			m.clear_turn_flags()
			m.modifier_stack.tick_battle_turn()
	_pending_commands.clear()


func _finish(result: int) -> void:
	_outcome = EncounterOutcome.new(result)
	state = State.FINISHED


# Routes every "battle is ending" path through the same cleanup sequence:
# cure all BATTLE_ONLY statuses, commit PERSISTENT statuses to Character,
# clear modifier_stack BATTLE_ONLY entries, then run the existing
# `_end_turn_cleanup` (defend flag reset + modifier tick) and finally _finish.
func _finish_with_battle_end_cleanup(report: TurnReport, result: int) -> void:
	var repo := get_status_repo()
	for actor in _all_actors:
		if actor == null:
			continue
		var cured: Array[StringName] = actor.statuses.cure_all_battle_only(repo)
		for sid in cured:
			report.add_cure(actor, sid)
		actor.modifier_stack.clear_battle_only()
	for actor in party:
		if actor is PartyCombatant:
			(actor as PartyCombatant).commit_persistent_to_character(repo)
	_end_turn_cleanup()
	_finish(result)
