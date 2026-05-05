extends GutTest


# Integration: TurnEngine._finish_with_battle_end_cleanup must call
# modifier_stack.clear_battle_only() on every actor when a battle resolves
# (CLEARED / WIPED / ESCAPED). This locks the contract so that buffs/debuffs
# from one battle never leak into the next.

const TEST_SEED: int = 4242


class _StubFighter extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_attack: int) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack

	func _get_base_attack() -> int:
		return _attack

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


class _StubMonster extends CombatActor:
	var _hp: int
	var _max: int

	func _init(p_name: String, p_hp: int) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func _get_base_attack() -> int:
		return 0


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func test_battle_end_clears_modifier_stack_on_party_member():
	var bamatu := load("res://data/spells/bamatu.tres") as SpellData
	var fighter := _StubFighter.new("Fighter", 30, 99)
	var slime := _StubMonster.new("Slime", 1)
	bamatu.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"attack"), 2,
		"sanity: bamatu modifier is in place before the battle ends")
	var engine := TurnEngine.new()
	engine.start_battle([fighter], [slime])
	engine.submit_command(0, AttackCommand.new(slime))
	engine.resolve_turn(_make_rng())
	# A 99-attack hit will kill a 1-HP slime, ending the battle in CLEARED.
	assert_eq(engine.state, TurnEngine.State.FINISHED,
		"battle should finish once all monsters die")
	assert_true(fighter.modifier_stack.is_empty(),
		"battle-end cleanup should have called clear_battle_only on the fighter")
	assert_eq(fighter.modifier_stack.sum(&"attack"), 0)


func test_battle_end_clears_modifier_stack_on_monster():
	var morlis := load("res://data/spells/morlis.tres") as SpellData
	var fighter := _StubFighter.new("Fighter", 30, 99)
	var slime := _StubMonster.new("Slime", 1)
	morlis.effect.apply(null, [slime], null)
	assert_eq(slime.modifier_stack.sum(&"defense"), -2,
		"sanity: morlis modifier is in place before the battle ends")
	var engine := TurnEngine.new()
	engine.start_battle([fighter], [slime])
	engine.submit_command(0, AttackCommand.new(slime))
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_true(slime.modifier_stack.is_empty(),
		"battle-end cleanup should have called clear_battle_only on the monster")
