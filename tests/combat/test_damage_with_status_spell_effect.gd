extends GutTest


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


func _make_status(id: StringName, scope: int = StatusData.Scope.PERSISTENT, resist_key: StringName = &"poison") -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	s.resist_key = resist_key
	return s


func _make_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"poison"))
	return repo


func _make_effect(base_damage: int, spread: int, status_id: StringName, inflict_chance: float, status_duration: int) -> DamageWithStatusSpellEffect:
	var e := DamageWithStatusSpellEffect.new()
	e.base_damage = base_damage
	e.spread = spread
	e.status_id = status_id
	e.inflict_chance = inflict_chance
	e.status_duration = status_duration
	e.set_status_repo_for_testing(_make_repo())
	return e


# --- structure ---

func test_effect_extends_spell_effect():
	var e := DamageWithStatusSpellEffect.new()
	assert_is(e, SpellEffect)


# --- damage + inflict on success ---

func test_damage_plus_inflict_events():
	var e := _make_effect(4, 0, &"poison", 1.0, 3)
	var target := _FakeActor.new(20)
	var rng := _FixedRng.new()
	rng.enqueue([0])  # spread=0 means no roll for damage; this 0 is for inflict
	var res := e.apply(null, [target], rng)
	assert_eq(target.current_hp, 16)  # 20 - 4
	var entry: Dictionary = res.entries[0]
	assert_eq(entry["hp_delta"], -4)
	var events: Array = entry["events"]
	assert_eq(events.size(), 2)
	assert_eq(events[0]["type"], "damage")
	assert_eq(events[0]["amount"], 4)
	assert_eq(events[1]["type"], "inflict")
	assert_eq(events[1]["status_id"], &"poison")
	assert_true(events[1]["success"])
	assert_true(target.statuses.has(&"poison"))


# --- killed by damage skips inflict ---

func test_killed_by_damage_skips_inflict():
	var e := _make_effect(20, 0, &"poison", 1.0, 3)
	var target := _FakeActor.new(5)
	var rng := _FixedRng.new()
	var res := e.apply(null, [target], rng)
	assert_eq(target.current_hp, 0)
	assert_false(target.is_alive())
	var entry: Dictionary = res.entries[0]
	var events: Array = entry["events"]
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "damage")
	assert_false(target.statuses.has(&"poison"))


# --- inflict can fail (resist event) ---

func test_inflict_resist_event_appended_when_chance_too_low():
	var e := _make_effect(2, 0, &"poison", 0.3, 3)  # 30% inflict
	var target := _FakeActor.new(20, 0.0)
	var rng := _FixedRng.new()
	rng.enqueue([50])  # roll 50 >= 30
	var res := e.apply(null, [target], rng)
	var entry: Dictionary = res.entries[0]
	var events: Array = entry["events"]
	assert_eq(events.size(), 2)
	assert_eq(events[0]["type"], "damage")
	assert_eq(events[1]["type"], "resist")
	assert_false(target.statuses.has(&"poison"))


# --- damage with spread uses spell_rng.roll for damage too ---

func test_damage_with_spread_uses_rng_for_damage():
	var e := _make_effect(5, 2, &"poison", 0.0, 3)  # never inflicts
	var target := _FakeActor.new(20)
	var rng := _FixedRng.new()
	rng.enqueue([1, 0])  # damage roll +1, then inflict roll (irrelevant since chance=0)
	e.apply(null, [target], rng)
	# 5 + 1 = 6 damage
	assert_eq(target.current_hp, 14)
