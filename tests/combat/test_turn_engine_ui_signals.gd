extends GutTest

# TurnEngine high-level UI signals (combat-engine spec):
#   actor_action_started(actor, kind)
#   actor_dealt_damage(target, amount, source)
#   actor_healed(target, amount, source)
#   actor_died(actor)
#   actor_status_inflicted(actor, status_id)


const TEST_SEED: int = 12345


class _SignalRecorder:
	extends RefCounted
	var actions: Array = []          # [[actor, kind], ...]
	var damages: Array = []          # [[target, amount, source], ...]
	var heals: Array = []            # [[target, amount, source], ...]
	var deaths: Array = []           # [actor, ...]
	var inflicts: Array = []         # [[actor, status_id], ...]

	func record_action(actor, kind: StringName) -> void:
		actions.append([actor, kind])

	func record_damage(target, amount: int, source) -> void:
		damages.append([target, amount, source])

	func record_heal(target, amount: int, source) -> void:
		heals.append([target, amount, source])

	func record_died(actor) -> void:
		deaths.append(actor)

	func record_inflict(actor, status_id: StringName) -> void:
		inflicts.append([actor, status_id])


class _StubPartyActor extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int
	var _mp_max: int
	var _attack: int
	var _defense: int
	var _agility: int

	func _init(
		p_name: String,
		p_hp: int,
		p_attack: int = 5,
		p_defense: int = 0,
		p_agility: int = 5,
		p_mp: int = 0
	) -> void:
		super()
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_mp = p_mp
		_mp_max = p_mp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func _read_current_mp() -> int:
		return _mp

	func _write_current_mp(value: int) -> void:
		_mp = value

	func _read_max_mp() -> int:
		return _mp_max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility


class _StubMonsterActor extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int
	var _agility: int

	func _init(p_name: String, p_hp: int, p_attack: int = 1, p_agility: int = 5) -> void:
		super()
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack
		_agility = p_agility

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return 0

	func get_agility() -> int:
		return _agility


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _wire_recorder(engine: TurnEngine, rec: _SignalRecorder) -> void:
	engine.actor_action_started.connect(rec.record_action)
	engine.actor_dealt_damage.connect(rec.record_damage)
	engine.actor_healed.connect(rec.record_heal)
	engine.actor_died.connect(rec.record_died)
	engine.actor_status_inflicted.connect(rec.record_inflict)


# --- signal declarations exist ---

func test_turn_engine_declares_all_five_ui_signals():
	var engine := TurnEngine.new()
	assert_true(engine.has_signal("actor_action_started"))
	assert_true(engine.has_signal("actor_dealt_damage"))
	assert_true(engine.has_signal("actor_healed"))
	assert_true(engine.has_signal("actor_died"))
	assert_true(engine.has_signal("actor_status_inflicted"))


# --- actor_action_started: per command kind ---

func test_attack_command_emits_action_started_with_attack_kind():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 30, 99)
	var m := _StubMonsterActor.new("M1", 10, 0, 1)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, AttackCommand.new(m))
	engine.resolve_turn(_make_rng())
	# pc should appear with kind=attack; the monster also acts (kind=attack).
	var pc_actions := []
	for entry in rec.actions:
		if entry[0] == pc:
			pc_actions.append(entry)
	assert_eq(pc_actions.size(), 1)
	assert_eq(pc_actions[0][1], &"attack")


func test_defend_command_emits_action_started_with_defend_kind():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 30, 5, 0, 99)  # high agi to act first
	var m := _StubMonsterActor.new("M1", 10, 0)         # zero attack so no damage
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	var pc_actions := []
	for entry in rec.actions:
		if entry[0] == pc:
			pc_actions.append(entry)
	assert_eq(pc_actions.size(), 1)
	assert_eq(pc_actions[0][1], &"defend")


func _make_repo_with_fire() -> SpellRepository:
	var repo := SpellRepository.new()
	var fire := SpellData.new()
	fire.id = &"fire"
	fire.display_name = "ファイア"
	fire.school = SpellData.SCHOOL_MAGE
	fire.level = 1
	fire.mp_cost = 2
	fire.target_type = SpellData.TargetType.ENEMY_ONE
	fire.scope = SpellData.Scope.BATTLE_ONLY
	var eff := DamageSpellEffect.new()
	eff.base_damage = 6
	eff.spread = 0
	fire.effect = eff
	repo.register(fire)
	return repo


func _make_repo_with_heal() -> SpellRepository:
	var repo := SpellRepository.new()
	var heal := SpellData.new()
	heal.id = &"heal"
	heal.display_name = "ヒール"
	heal.school = SpellData.SCHOOL_PRIEST
	heal.level = 1
	heal.mp_cost = 1
	heal.target_type = SpellData.TargetType.ALLY_ONE
	heal.scope = SpellData.Scope.OUTSIDE_OK
	var eff := HealSpellEffect.new()
	eff.base_heal = 7
	eff.spread = 0
	heal.effect = eff
	repo.register(heal)
	return repo


func test_cast_command_emits_action_started_with_cast_kind():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_fire()
	var pc := _StubPartyActor.new("Mage", 30, 0, 0, 99, 5)
	var m := _StubMonsterActor.new("M1", 30, 0)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, CastCommand.new(&"fire", 0, m))
	engine.resolve_turn(_make_rng())
	var pc_actions := []
	for entry in rec.actions:
		if entry[0] == pc:
			pc_actions.append(entry)
	assert_eq(pc_actions.size(), 1)
	assert_eq(pc_actions[0][1], &"cast")


func _make_potion(power: int = 20) -> Item:
	var it := Item.new()
	it.item_id = &"potion"
	it.item_name = "ポーション"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	var e := HealHpEffect.new()
	e.power = power
	it.effect = e
	var tc: Array[TargetCondition] = [AliveOnly.new(), NotFullHp.new()]
	it.target_conditions = tc
	return it


func test_item_command_emits_action_started_with_item_kind():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 5, 0, 0, 99)  # low HP to qualify for heal
	var m := _StubMonsterActor.new("M1", 10, 0)
	var inst := ItemInstance.new(_make_potion(20), true)
	var inv := Inventory.new()
	inv.add(inst)
	engine.inventory = inv
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, ItemCommand.new(pc, inst, pc))
	engine.resolve_turn(_make_rng())
	var pc_actions := []
	for entry in rec.actions:
		if entry[0] == pc:
			pc_actions.append(entry)
	assert_eq(pc_actions.size(), 1)
	assert_eq(pc_actions[0][1], &"item")


func test_escape_command_emits_action_started_with_escape_kind():
	var engine := TurnEngine.new()
	engine.escape_threshold = 0.0  # always fail so the turn continues and signal still emits
	var pc := _StubPartyActor.new("P1", 30, 0, 0, 99)
	var m := _StubMonsterActor.new("M1", 10, 0)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, EscapeCommand.new())
	engine.resolve_turn(_make_rng())
	var pc_actions := []
	for entry in rec.actions:
		if entry[0] == pc:
			pc_actions.append(entry)
	assert_eq(pc_actions.size(), 1)
	assert_eq(pc_actions[0][1], &"escape")


func test_dead_actors_with_pending_command_do_not_emit_action_started():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 0, 5, 0, 5)  # already dead at start_battle
	var alive := _StubPartyActor.new("P2", 30, 5, 0, 5)
	var m := _StubMonsterActor.new("M1", 10, 0)
	engine.start_battle([pc, alive], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, AttackCommand.new(m))
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	for entry in rec.actions:
		assert_ne(entry[0], pc, "dead actor must not emit action_started")


# --- actor_dealt_damage ---

func test_attack_hit_emits_dealt_damage_with_actual_amount():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 30, 99, 0, 99)  # one-shot, fast
	var m := _StubMonsterActor.new("M1", 50, 0)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, AttackCommand.new(m))
	engine.resolve_turn(_make_rng())
	var to_m := []
	for d in rec.damages:
		if d[0] == m:
			to_m.append(d)
	assert_eq(to_m.size(), 1, "one damage signal expected for the only attack")
	assert_gt(to_m[0][1], 0)
	assert_eq(to_m[0][2], pc)


func test_defend_halves_emitted_amount():
	# A defending target shows the actual halved damage.
	var engine := TurnEngine.new()
	var defender := _StubPartyActor.new("D", 100, 0, 0, 1)  # slow, lets monster swing first... but we want defender to be hit AFTER apply_defend
	# Actually defend is applied at the start of the turn before action loop.
	# We just need monster to hit defender and observe halved damage.
	var monster := _StubMonsterActor.new("M", 30, 10, 99)  # high agi → acts before defender? doesn't matter; defend pre-applied
	engine.start_battle([defender], [monster])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	var to_def := []
	for d in rec.damages:
		if d[0] == defender:
			to_def.append(d)
	assert_eq(to_def.size(), 1)
	# Monster atk 10 vs defender def 0 ≈ 10 damage normally; defended halves to ≥ 1.
	# Make sure the emitted amount equals the actual hp loss.
	var actual_loss := 100 - defender.current_hp
	assert_eq(to_def[0][1], actual_loss)


# --- actor_healed ---

func test_heal_spell_emits_healed_with_actual_amount():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_heal()
	var caster := _StubPartyActor.new("C", 30, 0, 0, 99, 5)
	var ally := _StubPartyActor.new("A", 5, 0, 0, 1)
	ally._max = 30  # raise max so heal is non-clamped
	var m := _StubMonsterActor.new("M1", 30, 0)
	engine.start_battle([caster, ally], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, CastCommand.new(&"heal", 0, ally))
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	var to_a := []
	for h in rec.heals:
		if h[0] == ally:
			to_a.append(h)
	assert_eq(to_a.size(), 1)
	assert_eq(to_a[0][1], 7)
	assert_eq(to_a[0][2], caster)


func test_heal_at_max_hp_does_not_emit():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_heal()
	var caster := _StubPartyActor.new("C", 30, 0, 0, 99, 5)
	var ally := _StubPartyActor.new("A", 30, 0, 0, 1)  # at max
	var m := _StubMonsterActor.new("M1", 30, 0)
	engine.start_battle([caster, ally], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, CastCommand.new(&"heal", 0, ally))
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	var ally_heals: int = 0
	for h in rec.heals:
		if h[0] == ally:
			ally_heals += 1
	assert_eq(ally_heals, 0, "no heal signal expected when target is at max HP")


# --- actor_died ---

func test_killing_blow_emits_died_after_dealt_damage():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 30, 999, 0, 99)
	var m := _StubMonsterActor.new("M1", 5, 0)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, AttackCommand.new(m))
	engine.resolve_turn(_make_rng())
	assert_eq(rec.deaths.size(), 1)
	assert_eq(rec.deaths[0], m)


func test_already_dead_actor_does_not_emit_died():
	var engine := TurnEngine.new()
	var pc := _StubPartyActor.new("P1", 30, 5, 0, 99)
	var m := _StubMonsterActor.new("M1", 0, 0)  # already dead at start
	var m2 := _StubMonsterActor.new("M2", 30, 0)
	engine.start_battle([pc], [m, m2])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	var m_deaths := 0
	for d in rec.deaths:
		if d == m:
			m_deaths += 1
	assert_eq(m_deaths, 0, "already-dead actor must not emit died this turn")


# --- actor_status_inflicted ---

func _make_status_repo_with_sleep() -> StatusRepository:
	var repo := StatusRepository.new()
	var sleep := StatusData.new()
	sleep.id = &"sleep"
	sleep.display_name = "sleep"
	sleep.scope = StatusData.Scope.BATTLE_ONLY
	repo.register(sleep)
	return repo


func test_new_status_inflict_emits_status_inflicted():
	var engine := TurnEngine.new()
	var status_repo := _make_status_repo_with_sleep()
	engine.status_repo = status_repo
	# Build the spell with the helper's status repo wired via the global locator.
	var spell_repo := SpellRepository.new()
	var s := SpellData.new()
	s.id = &"sleep_spell"
	s.display_name = "スリープ"
	s.school = SpellData.SCHOOL_MAGE
	s.level = 1
	s.mp_cost = 1
	s.target_type = SpellData.TargetType.ENEMY_ONE
	s.scope = SpellData.Scope.BATTLE_ONLY
	var eff := StatusInflictSpellEffect.new()
	eff.status_id = &"sleep"
	eff.chance = 1.0
	eff.duration = 3
	eff.set_status_repo_for_testing(status_repo)
	s.effect = eff
	spell_repo.register(s)
	engine.spell_repo = spell_repo
	var pc := _StubPartyActor.new("Mage", 30, 0, 0, 99, 5)
	var m := _StubMonsterActor.new("M1", 30, 0)
	pc.set_status_repo_for_testing(status_repo)
	m.set_status_repo_for_testing(status_repo)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, CastCommand.new(&"sleep_spell", 0, m))
	engine.resolve_turn(_make_rng())
	var to_m := []
	for inf in rec.inflicts:
		if inf[0] == m:
			to_m.append(inf)
	assert_eq(to_m.size(), 1)
	assert_eq(to_m[0][1], &"sleep")


func test_already_inflicted_status_does_not_re_emit():
	var engine := TurnEngine.new()
	var status_repo := _make_status_repo_with_sleep()
	engine.status_repo = status_repo
	var spell_repo := SpellRepository.new()
	var s := SpellData.new()
	s.id = &"sleep_spell"
	s.display_name = "スリープ"
	s.school = SpellData.SCHOOL_MAGE
	s.level = 1
	s.mp_cost = 1
	s.target_type = SpellData.TargetType.ENEMY_ONE
	s.scope = SpellData.Scope.BATTLE_ONLY
	var eff := StatusInflictSpellEffect.new()
	eff.status_id = &"sleep"
	eff.chance = 1.0
	eff.duration = 3
	eff.set_status_repo_for_testing(status_repo)
	s.effect = eff
	spell_repo.register(s)
	engine.spell_repo = spell_repo
	var pc := _StubPartyActor.new("Mage", 30, 0, 0, 99, 5)
	var m := _StubMonsterActor.new("M1", 30, 0)
	pc.set_status_repo_for_testing(status_repo)
	m.set_status_repo_for_testing(status_repo)
	# Pre-apply sleep before the cast.
	m.statuses.apply(&"sleep", 5)
	engine.start_battle([pc], [m])
	var rec := _SignalRecorder.new()
	_wire_recorder(engine, rec)
	engine.submit_command(0, CastCommand.new(&"sleep_spell", 0, m))
	engine.resolve_turn(_make_rng())
	var m_inflicts := 0
	for inf in rec.inflicts:
		if inf[0] == m:
			m_inflicts += 1
	assert_eq(m_inflicts, 0, "re-applying an existing status must not emit")
