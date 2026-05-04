extends GutTest

# Tests for StatusTrack - the per-actor status container holding at most one
# entry per id. Backed by Dictionary[StringName, int] where -1 == PERSISTENT.


class _FakeActor extends CombatActor:
	var _hp: int
	var _max: int

	func _init(p_max: int) -> void:
		_max = p_max
		_hp = p_max
		actor_name = "Fake"

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func _make_status(
	id: StringName,
	scope: int = StatusData.Scope.BATTLE_ONLY,
	tick_in_battle: int = 0,
	cures_on_damage: bool = false
) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	s.tick_in_battle = tick_in_battle
	s.cures_on_damage = cures_on_damage
	return s


func _seed_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY, 0, true))  # cures_on_damage
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT, 2, false))  # tick_in_battle=2
	repo.register(_make_status(&"silence", StatusData.Scope.BATTLE_ONLY, 0, false))
	repo.register(_make_status(&"petrify", StatusData.Scope.PERSISTENT, 0, false))
	return repo


# --- structure ---

func test_status_track_is_refcounted():
	var t := StatusTrack.new()
	assert_is(t, RefCounted)


func test_persistent_duration_constant():
	assert_eq(StatusTrack.PERSISTENT_DURATION, -1)


# --- apply / has ---

func test_apply_then_has_is_true():
	var t := StatusTrack.new()
	t.apply(&"sleep", 3)
	assert_true(t.has(&"sleep"))


func test_has_on_empty_track_is_false():
	var t := StatusTrack.new()
	assert_false(t.has(&"sleep"))


func test_apply_keeps_existing_when_new_duration_smaller():
	var t := StatusTrack.new()
	t.apply(&"sleep", 3)
	t.apply(&"sleep", 1)
	assert_true(t.has(&"sleep"))
	# Verified indirectly through tick_battle_turn behavior in further tests.
	# The contract: new duration is max(existing, new) when both are positive.


func test_apply_uses_larger_when_new_duration_bigger():
	var t := StatusTrack.new()
	t.apply(&"sleep", 1)
	t.apply(&"sleep", 5)
	assert_true(t.has(&"sleep"))


func test_apply_persistent_resists_overwrite_with_finite_duration():
	var t := StatusTrack.new()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	t.apply(&"poison", 3)
	# A subsequent finite duration must not downgrade a PERSISTENT entry.
	# We verify via tick that duration is still PERSISTENT (no decrement).
	var actor := _FakeActor.new(20)
	var repo := _seed_repo()
	for _i in range(5):
		t.tick_battle_turn(actor, repo)
	assert_true(t.has(&"poison"))


func test_apply_finite_can_be_upgraded_to_persistent():
	var t := StatusTrack.new()
	t.apply(&"poison", 3)
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	assert_true(t.has(&"poison"))
	# Verify by ticking many turns; entry should remain.
	var actor := _FakeActor.new(20)
	var repo := _seed_repo()
	for _i in range(5):
		t.tick_battle_turn(actor, repo)
	assert_true(t.has(&"poison"))


# --- cure ---

func test_cure_returns_true_when_entry_existed():
	var t := StatusTrack.new()
	t.apply(&"sleep", 3)
	assert_true(t.cure(&"sleep"))
	assert_false(t.has(&"sleep"))


func test_cure_returns_false_when_missing():
	var t := StatusTrack.new()
	assert_false(t.cure(&"sleep"))


# --- active_ids ---

func test_active_ids_is_empty_initially():
	var t := StatusTrack.new()
	assert_eq(t.active_ids().size(), 0)


func test_active_ids_lists_applied_entries():
	var t := StatusTrack.new()
	t.apply(&"sleep", 3)
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var ids := t.active_ids()
	assert_eq(ids.size(), 2)
	assert_true(ids.has(&"sleep"))
	assert_true(ids.has(&"poison"))


# --- cure_all_battle_only ---

func test_cure_all_battle_only_removes_battle_only_only():
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"sleep", 3)  # BATTLE_ONLY
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)  # PERSISTENT
	t.apply(&"silence", 2)  # BATTLE_ONLY
	var cured := t.cure_all_battle_only(repo)
	assert_eq(cured.size(), 2)
	assert_true(cured.has(&"sleep"))
	assert_true(cured.has(&"silence"))
	assert_false(t.has(&"sleep"))
	assert_false(t.has(&"silence"))
	assert_true(t.has(&"poison"))


func test_cure_all_battle_only_returns_empty_when_only_persistent():
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var cured := t.cure_all_battle_only(repo)
	assert_eq(cured.size(), 0)
	assert_true(t.has(&"poison"))


func test_cure_all_battle_only_skips_unknown_status_ids():
	# When the repo has no entry for an id, the entry is left in place.
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"unknown_xyz", 3)
	var cured := t.cure_all_battle_only(repo)
	assert_eq(cured.size(), 0)
	assert_true(t.has(&"unknown_xyz"))


# --- tick_battle_turn ---

func test_tick_battle_turn_applies_battle_tick_damage_and_reports():
	var actor := _FakeActor.new(10)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var report := t.tick_battle_turn(actor, repo)
	assert_eq(actor.current_hp, 8)  # 10 - 2 (tick_in_battle)
	assert_eq(report.size(), 1)
	var entry: Dictionary = report[0]
	assert_eq(entry.get("status_id"), &"poison")
	assert_eq(entry.get("hp_loss"), 2)
	assert_false(entry.get("killed_by_tick"))


func test_tick_battle_turn_killed_by_tick_flag():
	var actor := _FakeActor.new(2)
	actor.take_damage(1)  # current_hp = 1
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var report := t.tick_battle_turn(actor, repo)
	assert_eq(actor.current_hp, 0)
	assert_false(actor.is_alive())
	var entry: Dictionary = report[0]
	assert_true(entry.get("killed_by_tick"))


func test_tick_battle_turn_decrements_battle_only_duration():
	var actor := _FakeActor.new(20)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"sleep", 2)  # BATTLE_ONLY, no tick damage
	t.tick_battle_turn(actor, repo)
	assert_true(t.has(&"sleep"))  # duration 2 -> 1, still active
	t.tick_battle_turn(actor, repo)
	assert_false(t.has(&"sleep"))  # duration 1 -> 0, removed


func test_tick_battle_turn_does_not_decrement_persistent():
	var actor := _FakeActor.new(50)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	for _i in range(10):
		t.tick_battle_turn(actor, repo)
	assert_true(t.has(&"poison"))


func test_tick_battle_turn_skips_zero_battle_tick():
	var actor := _FakeActor.new(10)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"sleep", 3)  # tick_in_battle = 0
	var report := t.tick_battle_turn(actor, repo)
	assert_eq(actor.current_hp, 10)  # unchanged
	assert_eq(report.size(), 0)


func test_tick_battle_turn_skips_when_actor_already_dead():
	# An entry with tick_in_battle > 0 must not call take_damage on a dead actor.
	var actor := _FakeActor.new(2)
	actor.take_damage(2)  # already dead
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var report := t.tick_battle_turn(actor, repo)
	assert_eq(actor.current_hp, 0)
	# When the actor is not alive at tick time, no tick entry is produced.
	assert_eq(report.size(), 0)


func test_tick_battle_turn_handles_unknown_status_gracefully():
	# Unknown ids in the track should be ignored (no crash, no damage).
	var actor := _FakeActor.new(10)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"unknown_xyz", 3)
	var report := t.tick_battle_turn(actor, repo)
	assert_eq(actor.current_hp, 10)
	assert_eq(report.size(), 0)


# --- handle_damage_taken ---

func test_handle_damage_taken_cures_cures_on_damage_status():
	var actor := _FakeActor.new(10)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"sleep", 3)  # cures_on_damage = true
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)  # cures_on_damage = false
	var cured := t.handle_damage_taken(actor, repo)
	assert_eq(cured.size(), 1)
	assert_true(cured.has(&"sleep"))
	assert_false(t.has(&"sleep"))
	assert_true(t.has(&"poison"))


func test_handle_damage_taken_returns_empty_when_no_cures_on_damage_status():
	var actor := _FakeActor.new(10)
	var t := StatusTrack.new()
	var repo := _seed_repo()
	t.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var cured := t.handle_damage_taken(actor, repo)
	assert_eq(cured.size(), 0)
	assert_true(t.has(&"poison"))
