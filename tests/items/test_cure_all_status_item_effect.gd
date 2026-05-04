extends GutTest


class _FakeActor extends CombatActor:
	var _hp: int = 10
	var _max: int = 10

	func _init(p_name: String = "Fake") -> void:
		actor_name = p_name

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


class _FakeCharacter extends RefCounted:
	var persistent_statuses: Array[StringName] = []
	var current_hp: int = 10
	var max_hp: int = 10

	func is_dead() -> bool:
		return current_hp <= 0

	func is_alive() -> bool:
		return current_hp > 0


func _make_status(id: StringName, scope: int) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	return s


func _make_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY))
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT))
	repo.register(_make_status(&"silence", StatusData.Scope.BATTLE_ONLY))
	repo.register(_make_status(&"petrify", StatusData.Scope.PERSISTENT))
	return repo


# --- structure ---

func test_effect_extends_item_effect():
	var e := CureAllStatusItemEffect.new()
	assert_is(e, ItemEffect)


# --- ALL scope removes everything ---

func test_all_scope_removes_every_status_from_combat_actor():
	var e := CureAllStatusItemEffect.new()
	e.scope = CureAllStatusItemEffect.SCOPE_ALL
	e.set_status_repo_for_testing(_make_repo())
	var target := _FakeActor.new("Alice")
	target.statuses.apply(&"sleep", 3)
	target.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var result: ItemEffectResult = e.apply([target], null)
	assert_true(result.success)
	assert_false(target.statuses.has(&"sleep"))
	assert_false(target.statuses.has(&"poison"))


# --- PERSISTENT scope leaves BATTLE_ONLY alone ---

func test_persistent_scope_leaves_battle_only_intact():
	var e := CureAllStatusItemEffect.new()
	e.scope = StatusData.Scope.PERSISTENT
	e.set_status_repo_for_testing(_make_repo())
	var target := _FakeActor.new("Alice")
	target.statuses.apply(&"sleep", 3)  # BATTLE_ONLY
	target.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var result: ItemEffectResult = e.apply([target], null)
	assert_true(result.success)
	assert_true(target.statuses.has(&"sleep"))
	assert_false(target.statuses.has(&"poison"))


# --- BATTLE_ONLY scope leaves PERSISTENT alone ---

func test_battle_only_scope_leaves_persistent_intact():
	var e := CureAllStatusItemEffect.new()
	e.scope = StatusData.Scope.BATTLE_ONLY
	e.set_status_repo_for_testing(_make_repo())
	var target := _FakeActor.new("Alice")
	target.statuses.apply(&"sleep", 3)
	target.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var result: ItemEffectResult = e.apply([target], null)
	assert_true(result.success)
	assert_false(target.statuses.has(&"sleep"))
	assert_true(target.statuses.has(&"poison"))


# --- character (out of battle) ---

func test_persistent_scope_clears_character_persistent_statuses():
	var e := CureAllStatusItemEffect.new()
	e.scope = StatusData.Scope.PERSISTENT
	e.set_status_repo_for_testing(_make_repo())
	var ch := _FakeCharacter.new()
	ch.persistent_statuses = [&"poison", &"petrify"]
	var result: ItemEffectResult = e.apply([ch], null)
	assert_true(result.success)
	assert_eq(ch.persistent_statuses.size(), 0)


func test_battle_only_scope_no_op_on_character():
	# BATTLE_ONLY on Character is always no-op (BATTLE_ONLY ids never persist).
	var e := CureAllStatusItemEffect.new()
	e.scope = StatusData.Scope.BATTLE_ONLY
	e.set_status_repo_for_testing(_make_repo())
	var ch := _FakeCharacter.new()
	ch.persistent_statuses = [&"poison"]
	var result: ItemEffectResult = e.apply([ch], null)
	assert_false(result.success)
	assert_true(ch.persistent_statuses.has(&"poison"))


# --- clean target fails ---

func test_clean_target_fails():
	var e := CureAllStatusItemEffect.new()
	e.scope = CureAllStatusItemEffect.SCOPE_ALL
	e.set_status_repo_for_testing(_make_repo())
	var target := _FakeActor.new("Bob")
	var result: ItemEffectResult = e.apply([target], null)
	assert_false(result.success)
