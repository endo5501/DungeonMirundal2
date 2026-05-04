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
