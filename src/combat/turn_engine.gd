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

var _pending_commands: Dictionary = {}  # int index -> Command
var _outcome: EncounterOutcome


func start_battle(p_party: Array, p_monsters: Array) -> void:
	party = p_party
	monsters = p_monsters
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
			_finish(EncounterOutcome.Result.ESCAPED)
			_end_turn_cleanup()
			return report

	var all_actors: Array = []
	all_actors.append_array(party)
	all_actors.append_array(monsters)
	var order: Array = TurnOrder.order(all_actors, rng)

	var early_escape_town := false
	for actor in order:
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
			if cmd is ItemCommand:
				var handled := _resolve_item(actor, cmd as ItemCommand, report)
				if handled == ItemResolution.TOWN_ESCAPE:
					early_escape_town = true
					break
				continue
			if not actor.is_alive():
				continue
			if cmd is AttackCommand:
				_resolve_attack(actor, cmd.target, rng, report)
			elif cmd is CastCommand:
				_resolve_cast(actor, cmd as CastCommand, rng, report)
		else:
			if not actor.is_alive():
				continue
			var target: CombatActor = _pick_living_party(rng)
			if target != null:
				_resolve_attack(actor, target, rng, report)
		# Stop processing later actors as soon as either side is wiped.
		if _all_monsters_dead() or _all_party_dead():
			break

	if early_escape_town:
		_finish(EncounterOutcome.Result.ESCAPED)
		if _outcome != null:
			_outcome.request_town_return = true
		_end_turn_cleanup()
		return report

	_end_turn_cleanup()

	var monsters_dead := _all_monsters_dead()
	var party_dead := _all_party_dead()
	if monsters_dead:
		_finish(EncounterOutcome.Result.CLEARED)
	elif party_dead:
		_finish(EncounterOutcome.Result.WIPED)
	else:
		turn_number += 1
		state = State.COMMAND_INPUT

	return report


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


func _resolve_attack(attacker: CombatActor, target: CombatActor, rng: RandomNumberGenerator, report: TurnReport) -> void:
	var effective_target: CombatActor = target
	var retargeted_from := ""
	if effective_target == null or not effective_target.is_alive():
		retargeted_from = effective_target.actor_name if effective_target != null else ""
		effective_target = _pick_living_same_side_as(target, attacker)
	if effective_target == null:
		return
	var damage := DamageCalculator.calculate(attacker, effective_target, rng)
	var defended := effective_target.is_defending()
	effective_target.take_damage(damage)
	report.add_attack(attacker, effective_target, damage, defended, retargeted_from)
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
	for m in monsters:
		if m != null:
			m.clear_turn_flags()
	_pending_commands.clear()


func _finish(result: int) -> void:
	_outcome = EncounterOutcome.new(result)
	state = State.FINISHED
