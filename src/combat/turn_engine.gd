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

# UI-facing signals consumed by PartyHud during combat.
signal actor_action_started(actor: CombatActor, action_kind: StringName)
signal actor_dealt_damage(target: CombatActor, amount: int, source: CombatActor)
signal actor_healed(target: CombatActor, amount: int, source: CombatActor)
signal actor_died(actor: CombatActor)
signal actor_status_inflicted(actor: CombatActor, status_id: StringName)
# Emitted exactly once per cast in which spend_mp(spell.mp_cost) succeeded
# AND spell.mp_cost > 0 — silence/no_target/no_mp/zero-cost paths skip it.
# Pre-emitted before report.add_cast so subscribers reading
# get_pending_action_index() see the index where the cast log entry will land.
signal actor_spent_mp(actor: CombatActor, cost: int)

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
# Snapshots used to deduplicate actor_died emissions: an actor dies at most
# once per resolve_turn, regardless of how many take_damage call sites the
# killing blow flows through.
var _alive_at_resolve_start: Dictionary = {}
var _died_emitted: Dictionary = {}
# Active TurnReport during resolve_turn so signal subscribers (PartyHud) can
# read report.actions.size() at emission time and tag queued events with the
# index of the related log entry. null outside of resolve_turn.
var _resolve_report: TurnReport = null


# Returns the index in `_resolve_report.actions` where the next log entry
# would be appended. Used by PartyHud to align deferred animations with the
# log line they belong to. Returns -1 outside of resolve_turn.
func get_pending_action_index() -> int:
	if _resolve_report == null:
		return -1
	return _resolve_report.actions.size()


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


func withdraw_command(party_index: int) -> void:
	if state != State.COMMAND_INPUT:
		return
	_pending_commands.erase(party_index)


func has_pending_command(party_index: int) -> bool:
	return _pending_commands.has(party_index)


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
	# Wrapper exists so _resolve_report is cleared on every return path
	# without sprinkling manual cleanup through the body.
	var report := _resolve_turn_inner(rng)
	_resolve_report = null
	return report


func _resolve_turn_inner(rng: RandomNumberGenerator) -> TurnReport:
	var report := TurnReport.new()
	if state != State.COMMAND_INPUT:
		return report
	state = State.RESOLVING
	_resolve_report = report

	# Snapshot which actors enter this turn alive so actor_died only fires for
	# alive→dead transitions caused by THIS turn's events.
	_alive_at_resolve_start.clear()
	_died_emitted.clear()
	for actor in _all_actors:
		if actor != null and actor.is_alive():
			_alive_at_resolve_start[actor] = true

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
			var defender: CombatActor = party[i]
			if defender != null and defender.is_alive():
				actor_action_started.emit(defender, &"defend")
			(cmd as DefendCommand).apply_to(defender)
			report.add_defend(defender)

	# Handle Escape as a party-level roll (one roll regardless of how many submitted).
	# We still iterate every submitter so each one emits an action_started signal.
	var any_escape := false
	for i in range(party.size()):
		var ec: RefCounted = _pending_commands.get(i, null) as RefCounted
		if ec is EscapeCommand:
			any_escape = true
			var escaper: CombatActor = party[i]
			if escaper != null and escaper.is_alive():
				actor_action_started.emit(escaper, &"escape")
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
					actor_action_started.emit(actor, &"attack")
					_resolve_attack(actor, random_target, rng, report, true)
				continue

			if cmd is ItemCommand:
				actor_action_started.emit(actor, &"item")
				var handled := _resolve_item(actor, cmd as ItemCommand, report)
				if handled == ItemResolution.TOWN_ESCAPE:
					early_escape_town = true
					break
				continue
			if cmd is AttackCommand:
				actor_action_started.emit(actor, &"attack")
				_resolve_attack(actor, cmd.target, rng, report)
			elif cmd is CastCommand:
				actor_action_started.emit(actor, &"cast")
				if actor.has_silence_flag():
					report.add_cast_silenced(actor, (cmd as CastCommand).spell_id)
					continue
				_resolve_cast(actor, cmd as CastCommand, rng, report)
		else:
			# Monsters: confusion still applies (random target including allies).
			if actor.has_confusion_flag():
				var random_target := _pick_random_living_excluding(actor, rng)
				if random_target != null:
					actor_action_started.emit(actor, &"attack")
					_resolve_attack(actor, random_target, rng, report, true)
				continue
			if actor is MonsterCombatant:
				var ai_ctx := MonsterAiContext.new(party, monsters, get_spell_repo(), self)
				var ai_cmd: RefCounted = MonsterAi.choose(actor as MonsterCombatant, ai_ctx, rng)
				if ai_cmd is CastCommand:
					actor_action_started.emit(actor, &"cast")
					if actor.has_silence_flag():
						report.add_cast_silenced(actor, (ai_cmd as CastCommand).spell_id)
						continue
					_resolve_cast(actor, ai_cmd as CastCommand, rng, report)
				elif ai_cmd is AttackCommand:
					var target: CombatActor = (ai_cmd as AttackCommand).target
					if target != null:
						actor_action_started.emit(actor, &"attack")
						_resolve_attack(actor, target, rng, report)
				else:
					# null → wait (MELEE attacker still alive party) or skip (no party alive)
					if _any_party_alive() and _weapon_range_of(actor) == WeaponRange.MELEE:
						actor_action_started.emit(actor, &"wait")
						report.add_wait(actor)
			else:
				# Non-MonsterCombatant combatants (test stubs, custom actors) fall
				# back to the simple reachable-target attack policy.
				var target: CombatActor = _pick_living_party_reachable(actor, rng)
				if target != null:
					actor_action_started.emit(actor, &"attack")
					_resolve_attack(actor, target, rng, report)
				elif _any_party_alive() and _weapon_range_of(actor) == WeaponRange.MELEE:
					actor_action_started.emit(actor, &"wait")
					report.add_wait(actor)
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
			var hp_loss := int(t.get("hp_loss", 0))
			# Emit BEFORE add_tick_damage so the signal's pending-action-index
			# matches the index where this tick line will land. PartyHud uses
			# that index to align deferred animations with log playback.
			if hp_loss > 0:
				actor_dealt_damage.emit(actor, hp_loss, null)
			if killed:
				_check_and_emit_death(actor)
			report.add_tick_damage(
				actor,
				t.get("status_id"),
				hp_loss,
				killed,
			)
			if killed:
				any_kill = true
		# Damage from a tick still triggers cures_on_damage (e.g. poison
		# tick on a sleeper would wake the sleeper).
		if not ticks.is_empty():
			_apply_damage_taken_cure(actor, report)
	return any_kill


func _check_and_emit_death(actor) -> void:
	if actor == null or actor.is_alive():
		return
	if not _alive_at_resolve_start.get(actor, false):
		return
	if _died_emitted.get(actor, false):
		return
	_died_emitted[actor] = true
	actor_died.emit(actor)


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
	# Snapshot the target's HP so we can emit actor_healed / actor_dealt_damage
	# after the effect resolves. Items mutate Character.current_hp directly,
	# so without this the panel would never see a heal flash for in-combat
	# potions (Character.hp_changed is suppressed while a CombatActor is bound).
	var hp_target: CombatActor = cmd.target if cmd.target is CombatActor else null
	var hp_before: int = hp_target.current_hp if hp_target != null else -1
	var result: ItemEffectResult
	if inventory != null:
		result = inventory.use_item(cmd.item_instance, targets, ctx)
	elif item.effect != null:
		result = item.effect.apply(targets, ctx)
	if result == null or not result.success:
		cmd.cancelled = true
		report.add_item_cancelled(actor, item_name)
		return ItemResolution.NORMAL
	# Emit BEFORE add_item_use so PartyHud's pending-action-index lines up
	# with the item log line during buffered playback (design.md §D10).
	if hp_target != null and hp_before >= 0:
		var delta: int = hp_target.current_hp - hp_before
		if delta > 0:
			actor_healed.emit(hp_target, delta, actor)
		elif delta < 0:
			actor_dealt_damage.emit(hp_target, -delta, actor)
		if not hp_target.is_alive():
			_check_and_emit_death(hp_target)
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
	# Defense-in-depth reach gate. UI is expected to prevent unreachable
	# attacks, but a direct API call (e.g. dev console, scripted test) could
	# bypass it. confusion_swap targets are exempt — confusion is allowed to
	# pick anyone, that's the point of it.
	if not confusion_swap and not can_reach(attacker, effective_target):
		report.add_attack_unreachable(attacker, effective_target)
		return
	var result := DamageCalculator.calculate(attacker, effective_target, rng)
	if not result.hit:
		report.add_miss(attacker, effective_target, confusion_swap)
		return
	var defended := effective_target.is_defending()
	var applied := effective_target.take_damage(result.amount)
	# Emit BEFORE add_attack so the signal's pending-action-index lines up
	# with the attack log entry.
	if applied > 0:
		actor_dealt_damage.emit(effective_target, applied, attacker)
	report.add_attack(attacker, effective_target, applied, defended, retargeted_from, confusion_swap)
	if applied > 0:
		_apply_damage_taken_cure(effective_target, report)
	if not effective_target.is_alive():
		# Emit died right before add_defeated so its pending-action-index
		# matches the defeated log entry (not the attack one).
		_check_and_emit_death(effective_target)
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
	# Pre-emit MP spend BEFORE add_cast so subscribers reading
	# get_pending_action_index() see the index where the cast log entry will land.
	# Skip when mp_cost == 0 (no MP was actually deducted) so HUD subscribers
	# don't queue zero-delta events.
	if spell.mp_cost > 0:
		actor_spent_mp.emit(caster, spell.mp_cost)
	var spell_resolution: SpellResolution = spell.effect.apply(caster, targets, SpellRng.new(rng)) if spell.effect != null else SpellResolution.new()
	# Pre-emit damage/heal/status_inflicted BEFORE add_cast so their
	# pending-action-index lines up with the cast log entry. The cast log
	# entry itself carries per-target hp_delta, so panels react together
	# when the cast line is shown.
	if spell_resolution != null:
		for e in spell_resolution.entries:
			var pre_actor: CombatActor = e.get("actor")
			var pre_hp_delta: int = int(e.get("hp_delta", 0))
			if pre_hp_delta < 0:
				actor_dealt_damage.emit(pre_actor, -pre_hp_delta, caster)
			elif pre_hp_delta > 0:
				actor_healed.emit(pre_actor, pre_hp_delta, caster)
			for evt in e.get("events", []):
				if evt.get("type") == "inflict" and bool(evt.get("success", false)):
					if bool(evt.get("was_new", true)):
						actor_status_inflicted.emit(pre_actor, evt.get("status_id", &""))
	report.add_cast(caster, spell, spell_resolution, retargeted_from)
	if spell_resolution != null:
		for e in spell_resolution.entries:
			var actor: CombatActor = e.get("actor")
			var hp_delta: int = int(e.get("hp_delta", 0))
			for evt in e.get("events", []):
				match evt.get("type"):
					"inflict":
						if bool(evt.get("success", false)):
							report.add_inflict(actor, evt.get("status_id", &""), true)
					"resist":
						report.add_resist(actor, evt.get("status_id", &""))
					"cure":
						report.add_cure(actor, evt.get("status_id", &""))
					"stat_mod":
						report.add_stat_mod(
							actor,
							evt.get("stat", &""),
							evt.get("delta", 0),
							int(evt.get("turns", 0)),
						)
			if hp_delta < 0:
				_apply_damage_taken_cure(actor, report)
	for t in targets:
		if t != null and not t.is_alive():
			# Emit died right before add_defeated so the deferred animation
			# fires with the defeated log line (not the cast line).
			_check_and_emit_death(t)
			report.add_defeated(t)


func _resolve_cast_targets(caster: CombatActor, cmd: CastCommand, spell: SpellData) -> Dictionary:
	var result: Dictionary = {"targets": [], "retargeted_from": ""}
	# ENEMY_*/ALLY_* are interpreted relative to the caster's side: enemies are
	# the opposing pool, allies are the caster's own pool. This lets a single
	# SpellData (e.g. fire.tres) be cast by either side.
	var caster_is_party := _is_party_member(caster)
	var enemy_pool: Array = monsters if caster_is_party else party
	var ally_pool: Array = party if caster_is_party else monsters
	match spell.target_type:
		SpellData.TargetType.ENEMY_ONE:
			var enemy: CombatActor = cmd.target as CombatActor
			if enemy != null and enemy.is_alive():
				result["targets"] = [enemy]
			else:
				var original_name := enemy.actor_name if enemy != null else ""
				var fallback := _pick_alive_replacement(enemy, enemy_pool)
				if fallback != null:
					result["targets"] = [fallback]
					result["retargeted_from"] = original_name
		SpellData.TargetType.ENEMY_GROUP:
			var species_id := _species_id_of(cmd.target)
			var collected: Array = []
			for m in enemy_pool:
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
				var fallback := _pick_alive_replacement(ally, ally_pool)
				if fallback != null:
					result["targets"] = [fallback]
					result["retargeted_from"] = original_name
		SpellData.TargetType.ALLY_ALL:
			var ally_targets: Array = []
			for p in ally_pool:
				if p != null and p.is_alive():
					ally_targets.append(p)
			result["targets"] = ally_targets
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


# Returns null when nothing is reachable; caller decides wait vs skip.
func _pick_living_party_reachable(attacker: CombatActor, rng: RandomNumberGenerator) -> CombatActor:
	var alive_reachable: Array = []
	for a in party:
		if a != null and a.is_alive() and can_reach(attacker, a):
			alive_reachable.append(a)
	if alive_reachable.is_empty():
		return null
	return alive_reachable[rng.randi_range(0, alive_reachable.size() - 1)]


func _any_party_alive() -> bool:
	for a in party:
		if a != null and a.is_alive():
			return true
	return false


# BACK-row actors promote to effective FRONT once their entire same-side
# FRONT is dead — this is the rule that makes MELEE BACK attackers eventually
# act and that makes BACK targets reachable to MELEE attackers in the wipe.
func effective_row(actor: CombatActor) -> int:
	if actor == null:
		return Row.FRONT
	if _original_row_of(actor) == Row.FRONT:
		return Row.FRONT
	var side: Array = party if _is_party_member(actor) else monsters
	for peer in side:
		if peer == null or peer == actor:
			continue
		if _original_row_of(peer) == Row.FRONT and peer.is_alive():
			return Row.BACK
	return Row.FRONT


# Recomputed per call to honor mid-turn FRONT-row promotion.
func can_reach(attacker: CombatActor, target: CombatActor) -> bool:
	if attacker == null or target == null:
		return false
	if _weapon_range_of(attacker) == WeaponRange.RANGED:
		return true
	return effective_row(attacker) == Row.FRONT and effective_row(target) == Row.FRONT


func _weapon_range_of(actor: CombatActor) -> int:
	if actor is PartyCombatant:
		var pc := actor as PartyCombatant
		if pc.equipment_provider != null:
			return pc.equipment_provider.get_weapon_range(pc.character)
		return WeaponRange.MELEE
	if actor is MonsterCombatant:
		var mc := actor as MonsterCombatant
		if mc.monster != null and mc.monster.data != null:
			return mc.monster.data.attack_range
		return WeaponRange.MELEE
	return WeaponRange.MELEE


func _original_row_of(actor: CombatActor) -> int:
	if actor is PartyCombatant:
		return (actor as PartyCombatant).original_row
	if actor is MonsterCombatant:
		return (actor as MonsterCombatant).original_row
	return Row.FRONT


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
