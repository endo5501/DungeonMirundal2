extends GutTest

# StatusInflictSpellEffect: rolls inflict against target.get_resist(resist_key).
# Uses spell_rng.roll(0, 99). Hit when r < effective * 100 (integer).


class _FakeActor extends CombatActor:
	var _hp: int
	var _max: int
	var _resist: float = 0.0

	func _init(p_max: int, p_resist: float = 0.0) -> void:
		_max = p_max
		_hp = p_max
		_resist = p_resist
		actor_name = "Fake"

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_resist(_key: StringName) -> float:
		return _resist


class _FixedRng extends SpellRng:
	var _queue: Array[int] = []

	func _init() -> void:
		super._init(null)

	func enqueue(values: Array) -> void:
		for v in values:
			_queue.append(int(v))

	func roll(_low: int, _high: int) -> int:
		if _queue.is_empty():
			return 0
		return _queue.pop_front()


func _make_status(id: StringName, scope: int = StatusData.Scope.BATTLE_ONLY, resist_key: StringName = &"") -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	s.resist_key = resist_key
	return s


func _make_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY, &"sleep"))
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT, &"poison"))
	return repo


# Effect's apply() looks up via DataLoader.new().load_status_repository().
# We can't inject a custom DataLoader, so we add a test seam on the effect.

func _make_effect(status_id: StringName, chance: float, duration: int) -> StatusInflictSpellEffect:
	var e := StatusInflictSpellEffect.new()
	e.status_id = status_id
	e.chance = chance
	e.duration = duration
	e.set_status_repo_for_testing(_make_repo())
	return e


# --- structure ---

func test_effect_extends_spell_effect():
	var e := StatusInflictSpellEffect.new()
	assert_is(e, SpellEffect)


# --- inflict success ---

func test_inflict_succeeds_when_roll_below_effective_chance():
	# chance 0.6, resist 0.2 → effective 0.4. roll 30 → 30 < 40 → hit.
	var e := _make_effect(&"sleep", 0.6, 3)
	var target := _FakeActor.new(20, 0.2)
	var rng := _FixedRng.new()
	rng.enqueue([30])
	var res := e.apply(null, [target], rng)
	assert_eq(res.size(), 1)
	var entry: Dictionary = res.entries[0]
	assert_eq(entry["hp_delta"], 0)
	var events: Array = entry["events"]
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "inflict")
	assert_eq(events[0]["status_id"], &"sleep")
	assert_true(events[0]["success"])
	assert_true(target.statuses.has(&"sleep"))


# --- inflict miss / resist event ---

func test_inflict_fails_when_roll_at_or_above_effective_chance():
	# chance 0.6, resist 0.2 → effective 0.4. roll 45 → 45 >= 40 → resist.
	var e := _make_effect(&"sleep", 0.6, 3)
	var target := _FakeActor.new(20, 0.2)
	var rng := _FixedRng.new()
	rng.enqueue([45])
	var res := e.apply(null, [target], rng)
	var entry: Dictionary = res.entries[0]
	var events: Array = entry["events"]
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "resist")
	assert_eq(events[0]["status_id"], &"sleep")
	assert_false(target.statuses.has(&"sleep"))


# --- PERSISTENT scope uses sentinel duration regardless of `duration` field ---

func test_persistent_scope_applies_with_persistent_duration():
	var e := _make_effect(&"poison", 1.0, 5)  # always succeeds
	var target := _FakeActor.new(20)
	var rng := _FixedRng.new()
	rng.enqueue([0])
	e.apply(null, [target], rng)
	assert_true(target.statuses.has(&"poison"))
	# Verify the entry survives many ticks (= PERSISTENT_DURATION).
	# Use a separate repo for tick (poison has no tick_in_battle so just decrement check).
	var verify_repo := StatusRepository.new()
	verify_repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT))
	for _i in range(10):
		target.statuses.tick_battle_turn(target, verify_repo)
	assert_true(target.statuses.has(&"poison"))


# --- full resist gives guaranteed failure ---

func test_full_resist_blocks_inflict():
	var e := _make_effect(&"sleep", 0.8, 3)
	var target := _FakeActor.new(20, 1.0)
	var rng := _FixedRng.new()
	rng.enqueue([0])  # smallest roll, would normally succeed
	var res := e.apply(null, [target], rng)
	var entry: Dictionary = res.entries[0]
	var events: Array = entry["events"]
	# effective = 0.8 - 1.0 = -0.2 → clamped to 0 → no roll succeeds.
	assert_eq(events[0]["type"], "resist")
	assert_false(target.statuses.has(&"sleep"))


# --- add-status-confusion-blind-paralysis: negative resist boosts effective inflict ---

func test_negative_resist_increases_effective_chance():
	# chance 0.5, resist -0.30 → effective clamp(0.5 - (-0.30), 0, 1) = 0.80.
	# roll 75 → 75 < 80 → hit (would have missed at base 0.5 since 75 >= 50).
	var e := _make_effect(&"sleep", 0.5, 3)
	var target := _FakeActor.new(20, -0.30)
	var rng := _FixedRng.new()
	rng.enqueue([75])
	e.apply(null, [target], rng)
	assert_true(target.statuses.has(&"sleep"), "negative resist should raise effective above the roll")


func test_negative_resist_clamped_to_one_at_inflict_site():
	# chance 0.9, resist -0.50 → 0.9 - (-0.50) = 1.4 → clamped to 1.0.
	# roll 99 → 99 < 100 → hit.
	var e := _make_effect(&"sleep", 0.9, 3)
	var target := _FakeActor.new(20, -0.50)
	var rng := _FixedRng.new()
	rng.enqueue([99])
	e.apply(null, [target], rng)
	assert_true(target.statuses.has(&"sleep"), "effective should clamp to 1.0 at the inflict site")


# --- unknown status_id is no-op ---

func test_unknown_status_id_yields_empty_resolution():
	var e := _make_effect(&"unknown_xyz_status", 0.5, 3)
	var target := _FakeActor.new(20)
	var rng := _FixedRng.new()
	var res := e.apply(null, [target], rng)
	assert_eq(res.size(), 0)
