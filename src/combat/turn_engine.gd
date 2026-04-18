class_name TurnEngine
extends RefCounted

enum State {
	IDLE,
	COMMAND_INPUT,
	RESOLVING,
	FINISHED,
}

var state: State = State.IDLE
var party: Array = []  # Array[PartyCombatant or CombatActor-compatible]
var monsters: Array = []  # Array[MonsterCombatant or CombatActor-compatible]
var turn_number: int = 0
var escape_threshold: float = 0.5

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
	for i in range(party.size()):
		var cmd = _pending_commands.get(i, null)
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

	for actor in order:
		if not actor.is_alive():
			continue
		if _is_party_member(actor):
			if any_escape and not escape_succeeded:
				# Party offense forfeited on failed escape.
				continue
			var idx := party.find(actor)
			if idx < 0:
				continue
			var cmd = _pending_commands.get(idx, null)
			if cmd is AttackCommand:
				_resolve_attack(actor, cmd.target, rng, report)
		else:
			var target: CombatActor = _pick_living_party(rng)
			if target != null:
				_resolve_attack(actor, target, rng, report)
		# Stop processing later actors as soon as either side is wiped.
		if _all_monsters_dead() or _all_party_dead():
			break

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


func _resolve_attack(attacker: CombatActor, target: CombatActor, rng: RandomNumberGenerator, report: TurnReport) -> void:
	var effective_target: CombatActor = target
	if effective_target == null or not effective_target.is_alive():
		effective_target = _pick_living_same_side_as(target, attacker)
	if effective_target == null:
		return
	var damage := DamageCalculator.calculate(attacker, effective_target, rng)
	var defended := effective_target.is_defending()
	effective_target.take_damage(damage)
	report.add_attack(attacker, effective_target, damage, defended)
	if not effective_target.is_alive():
		report.add_defeated(effective_target)


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
