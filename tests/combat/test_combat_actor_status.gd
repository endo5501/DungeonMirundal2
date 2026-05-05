extends GutTest

# Tests inject a StatusRepository via `set_status_repo_for_testing` because
# this change ships no data/statuses/*.tres files for the helpers to look up.


class _BaseStub extends CombatActor:
	pass


func _make_status(
	id: StringName,
	prevents_action: bool = false,
	randomizes_target: bool = false,
	blocks_cast: bool = false
) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = StatusData.Scope.BATTLE_ONLY
	s.prevents_action = prevents_action
	s.randomizes_target = randomizes_target
	s.blocks_cast = blocks_cast
	return s


func _seed_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"sleep", true, false, false))     # prevents_action
	repo.register(_make_status(&"paralysis", true, false, false))  # prevents_action
	repo.register(_make_status(&"silence", false, false, true))    # blocks_cast
	repo.register(_make_status(&"confusion", false, true, false))  # randomizes_target
	repo.register(_make_status(&"blind"))                          # nothing special
	return repo


# --- structure ---

func test_combat_actor_has_statuses_property():
	var a := _BaseStub.new()
	assert_not_null(a.statuses)
	assert_is(a.statuses, StatusTrack)


func test_combat_actor_statuses_starts_empty():
	var a := _BaseStub.new()
	assert_eq(a.statuses.active_ids().size(), 0)


# --- has_silence_flag ---

func test_has_silence_flag_default_false():
	var a := _BaseStub.new()
	assert_false(a.has_silence_flag())


func test_has_silence_flag_when_blocks_cast_status_active():
	var a := _BaseStub.new()
	a.set_status_repo_for_testing(_seed_repo())
	a.statuses.apply(&"silence", 3)
	assert_true(a.has_silence_flag())
	a.statuses.cure(&"silence")
	assert_false(a.has_silence_flag())


func test_has_silence_flag_false_when_other_status_active():
	var a := _BaseStub.new()
	a.set_status_repo_for_testing(_seed_repo())
	a.statuses.apply(&"sleep", 3)
	assert_false(a.has_silence_flag())


# --- has_confusion_flag ---

func test_has_confusion_flag_default_false():
	var a := _BaseStub.new()
	assert_false(a.has_confusion_flag())


func test_has_confusion_flag_when_randomizes_target_status_active():
	var a := _BaseStub.new()
	a.set_status_repo_for_testing(_seed_repo())
	a.statuses.apply(&"confusion", 3)
	assert_true(a.has_confusion_flag())


# --- has_action_lock ---

func test_has_action_lock_default_false():
	var a := _BaseStub.new()
	assert_false(a.has_action_lock())


func test_has_action_lock_true_for_prevents_action():
	var a := _BaseStub.new()
	a.set_status_repo_for_testing(_seed_repo())
	a.statuses.apply(&"sleep", 3)
	assert_true(a.has_action_lock())


func test_has_action_lock_true_for_paralysis():
	var a := _BaseStub.new()
	a.set_status_repo_for_testing(_seed_repo())
	a.statuses.apply(&"paralysis", 3)
	assert_true(a.has_action_lock())


# --- has_blind_flag now consults StatusTrack ---

func test_has_blind_flag_true_when_blind_status_active():
	var a := _BaseStub.new()
	a.statuses.apply(&"blind", 3)
	assert_true(a.has_blind_flag())


func test_has_blind_flag_false_when_blind_not_active():
	var a := _BaseStub.new()
	assert_false(a.has_blind_flag())


# --- get_resist default ---

func test_get_resist_default_is_zero():
	var a := _BaseStub.new()
	assert_almost_eq(a.get_resist(&"poison"), 0.0, 0.0001)


func test_get_resist_default_for_empty_key_is_zero():
	var a := _BaseStub.new()
	assert_almost_eq(a.get_resist(&""), 0.0, 0.0001)


# --- add-status-confusion-blind-paralysis: clamp removal ---
# PartyCombatant.get_resist returns the raw sum of race+job resists, including
# negative values; clamp is moved to the inflict-chance site only.

func _build_character(race_resists: Dictionary, job_resists: Dictionary) -> Character:
	var race := RaceData.new()
	race.race_name = "TestRace"
	race.base_str = 8
	race.base_int = 8
	race.base_pie = 8
	race.base_vit = 8
	race.base_agi = 8
	race.base_luc = 8
	race.resists = race_resists
	var job := JobData.new()
	job.job_name = "TestJob"
	job.base_hp = 8
	job.resists = job_resists
	var ch := Character.new()
	ch.character_name = "Tester"
	ch.race = race
	ch.job = job
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func test_party_combatant_get_resist_returns_negative_sum_unclamped():
	var ch := _build_character({&"silence": -0.10}, {&"silence": -0.20})
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_almost_eq(pc.get_resist(&"silence"), -0.30, 0.0001)


func test_party_combatant_get_resist_returns_positive_sum_unclamped():
	var ch := _build_character({&"poison": 0.20}, {&"poison": 0.10})
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_almost_eq(pc.get_resist(&"poison"), 0.30, 0.0001)


func test_party_combatant_get_resist_unknown_key_is_zero():
	var ch := _build_character({}, {})
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_almost_eq(pc.get_resist(&"poison"), 0.0, 0.0001)


func _fixed_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return rng


func test_monster_combatant_get_resist_preserves_negative_values():
	var data := MonsterData.new()
	data.monster_id = &"hypothetical_holy_undead"
	data.monster_name = "HypoUndead"
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.resists = {&"holy": -0.20}
	var m := Monster.new(data, _fixed_rng())
	var mc := MonsterCombatant.new(m)
	assert_almost_eq(mc.get_resist(&"holy"), -0.20, 0.0001)


func test_monster_combatant_get_resist_above_one_preserved():
	var data := MonsterData.new()
	data.monster_id = &"super_immune"
	data.monster_name = "SuperImmune"
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.resists = {&"sleep": 1.0}
	var m := Monster.new(data, _fixed_rng())
	var mc := MonsterCombatant.new(m)
	assert_almost_eq(mc.get_resist(&"sleep"), 1.0, 0.0001)
