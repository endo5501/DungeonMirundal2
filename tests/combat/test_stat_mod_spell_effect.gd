extends GutTest


class _FakeActor extends CombatActor:
	var _hp: int = 10
	var _max: int = 10

	func _init() -> void:
		actor_name = "Fake"

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


# --- structure ---

func test_effect_extends_spell_effect():
	var e := StatModSpellEffect.new()
	assert_is(e, SpellEffect)


func test_effect_has_required_exports():
	var e := StatModSpellEffect.new()
	e.stat = &"attack"
	e.delta = 2
	e.turns = 3
	assert_eq(e.stat, &"attack")
	assert_eq(e.delta, 2)
	assert_eq(e.turns, 3)


# --- apply adds modifier and emits event ---

func test_apply_adds_modifier_to_target_stack():
	var e := StatModSpellEffect.new()
	e.stat = &"attack"
	e.delta = 2
	e.turns = 3
	var target := _FakeActor.new()
	e.apply(null, [target], null)
	assert_eq(target.modifier_stack.sum(&"attack"), 2)


func test_apply_emits_stat_mod_event():
	var e := StatModSpellEffect.new()
	e.stat = &"defense"
	e.delta = -1
	e.turns = 2
	var target := _FakeActor.new()
	var res := e.apply(null, [target], null)
	assert_eq(res.size(), 1)
	var entry: Dictionary = res.entries[0]
	assert_eq(entry["hp_delta"], 0)
	var events: Array = entry["events"]
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "stat_mod")
	assert_eq(events[0]["stat"], &"defense")
	assert_eq(events[0]["delta"], -1)
	assert_eq(events[0]["turns"], 2)


# --- beta rule preserved (delegates to StatModifierStack.add) ---

func test_apply_respects_beta_rule_replace_when_stronger():
	var e := StatModSpellEffect.new()
	e.stat = &"attack"
	e.delta = 3
	e.turns = 2
	var target := _FakeActor.new()
	target.modifier_stack.add(&"attack", 1, 1)
	e.apply(null, [target], null)
	# stronger 3 > existing 1, so the new value replaces.
	assert_eq(target.modifier_stack.sum(&"attack"), 3)


func test_apply_respects_beta_rule_no_op_when_weaker():
	var e := StatModSpellEffect.new()
	e.stat = &"attack"
	e.delta = 1
	e.turns = 5
	var target := _FakeActor.new()
	target.modifier_stack.add(&"attack", 3, 2)
	e.apply(null, [target], null)
	# weaker stays at +3
	assert_eq(target.modifier_stack.sum(&"attack"), 3)
