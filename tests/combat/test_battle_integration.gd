extends GutTest

const TEST_SEED: int = 12345


var _loader: DataLoader
var _provider: DummyEquipmentProvider


func before_each():
	_loader = DataLoader.new()
	_provider = DummyEquipmentProvider.new()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _make_monster_data(id: StringName, display_name: String, atk: int, defn: int, agi: int, hp: int, exp: int) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = display_name
	data.max_hp_min = hp
	data.max_hp_max = hp
	data.attack = atk
	data.defense = defn
	data.agility = agi
	data.experience = exp
	return data


func _make_monster_party(specs: Array) -> MonsterParty:
	# specs: Array[Dictionary{id, name, atk, def, agi, hp, exp, count}]
	var party := MonsterParty.new()
	for spec in specs:
		var data := _make_monster_data(
			spec["id"], spec["name"], spec["atk"], spec["def"],
			spec["agi"], spec["hp"], spec["exp"]
		)
		for i in range(spec["count"]):
			party.add(Monster.new(data, _make_rng()))
	return party


func _find_job(name: String) -> JobData:
	for j in _loader.load_all_jobs():
		if j.job_name == name:
			return j
	return null


func _find_human() -> RaceData:
	for r in _loader.load_all_races():
		if r.race_name == "Human":
			return r
	return null


func _make_character(name: String, job_name: String, hp: int = 30, stats: Dictionary = {}) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _find_human()
	ch.job = _find_job(job_name)
	ch.level = 1
	if stats.is_empty():
		stats = {&"STR": 14, &"INT": 10, &"PIE": 10, &"VIT": 14, &"AGI": 10, &"LUC": 10}
	ch.base_stats = stats
	ch.max_hp = hp
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	ch.accumulated_exp = 0
	return ch


func _party_combatants_from_characters(chars: Array) -> Array:
	var result: Array = []
	for ch in chars:
		result.append(PartyCombatant.new(ch, _provider))
	return result


func _monster_combatants_from_party(party: MonsterParty) -> Array:
	var result: Array = []
	for m in party.members:
		result.append(MonsterCombatant.new(m))
	return result


# --- CLEARED path ---

func test_battle_reaches_cleared_state_against_weak_monsters():
	var chars: Array = [
		_make_character("P1", "Fighter", 30),
		_make_character("P2", "Fighter", 30),
	]
	var monster_party := _make_monster_party([
		{"id": &"slime", "name": "Slime", "atk": 2, "def": 0, "agi": 4, "hp": 5, "exp": 40, "count": 1},
	])
	var engine := TurnEngine.new()
	engine.start_battle(
		_party_combatants_from_characters(chars),
		_monster_combatants_from_party(monster_party),
	)
	var rng := _make_rng()
	var turn_guard := 0
	while engine.state != TurnEngine.State.FINISHED and turn_guard < 50:
		# Both party members attack the first living monster
		for i in range(engine.party.size()):
			var target: CombatActor = null
			for m in engine.monsters:
				if m.is_alive():
					target = m
					break
			if target != null:
				engine.submit_command(i, AttackCommand.new(target))
			else:
				engine.submit_command(i, DefendCommand.new())
		engine.resolve_turn(rng)
		turn_guard += 1
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)


func test_cleared_battle_awards_experience():
	var chars: Array = [
		_make_character("P1", "Fighter", 30),
		_make_character("P2", "Fighter", 30),
	]
	var monster_party := _make_monster_party([
		{"id": &"slime", "name": "Slime", "atk": 0, "def": 0, "agi": 1, "hp": 1, "exp": 100, "count": 1},
	])
	var engine := TurnEngine.new()
	engine.start_battle(
		_party_combatants_from_characters(chars),
		_monster_combatants_from_party(monster_party),
	)
	var rng := _make_rng()
	while engine.state != TurnEngine.State.FINISHED:
		for i in range(engine.party.size()):
			engine.submit_command(i, AttackCommand.new(engine.monsters[0]))
		engine.resolve_turn(rng)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)
	var dead_monsters: Array = []
	for mc in engine.monsters:
		if not mc.is_alive():
			dead_monsters.append(mc.monster)
	var share := ExperienceCalculator.award(chars, dead_monsters)
	# 100 exp, 2 party → 50 each
	assert_eq(share, 50)
	for ch in chars:
		assert_eq(ch.accumulated_exp, 50)


# --- WIPED path ---

func test_battle_reaches_wiped_state_against_overwhelming_monsters():
	var chars: Array = [_make_character("P1", "Fighter", 2)]
	var monster_party := _make_monster_party([
		{"id": &"dragon", "name": "Dragon", "atk": 999, "def": 50, "agi": 50, "hp": 9999, "exp": 0, "count": 1},
	])
	var engine := TurnEngine.new()
	engine.start_battle(
		_party_combatants_from_characters(chars),
		_monster_combatants_from_party(monster_party),
	)
	var rng := _make_rng()
	while engine.state != TurnEngine.State.FINISHED:
		engine.submit_command(0, AttackCommand.new(engine.monsters[0]))
		engine.resolve_turn(rng)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.WIPED)


# --- ESCAPED path ---

func test_battle_reaches_escaped_state_when_threshold_guarantees_success():
	var chars: Array = [_make_character("P1", "Fighter", 30)]
	var monster_party := _make_monster_party([
		{"id": &"slime", "name": "Slime", "atk": 1, "def": 0, "agi": 2, "hp": 5, "exp": 40, "count": 1},
	])
	var engine := TurnEngine.new()
	engine.escape_threshold = 1.0
	engine.start_battle(
		_party_combatants_from_characters(chars),
		_monster_combatants_from_party(monster_party),
	)
	engine.submit_command(0, EscapeCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.outcome().result, EncounterOutcome.Result.ESCAPED)
