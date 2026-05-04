extends GutTest


# Integration: silence status flow against the shipped TurnEngine.
#
# Asserts:
#   - When a PartyCombatant submits a CastCommand while silenced, TurnEngine
#     emits cast_silenced and does NOT consume MP.
#   - silence is BATTLE_ONLY: it is cleared when the battle ends (CLEARED).

const TEST_SEED: int = 42


class _StubCaster extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int
	var _mp_max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_mp: int, p_attack: int = 0) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_mp = p_mp
		_mp_max = p_mp
		_attack = p_attack

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


class _StubMonster extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_attack: int = 0) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack


func _load_repo() -> StatusRepository:
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _inject_repo(engine: TurnEngine, repo: StatusRepository) -> void:
	engine.status_repo = repo
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(repo)


func test_silenced_cast_is_swallowed_without_consuming_mp():
	var engine := TurnEngine.new()
	var caster := _StubCaster.new("Mage", 30, 5, 0)
	var slime := _StubMonster.new("Slime", 10)
	engine.start_battle([caster], [slime])
	_inject_repo(engine, _load_repo())
	caster.statuses.apply(&"silence", 4)
	engine.submit_command(0, CastCommand.new(&"fire", 0, slime))
	var report := engine.resolve_turn(_make_rng())
	var silenced := []
	for a in report.actions:
		if a.get("type") == "cast_silenced":
			silenced.append(a)
	assert_eq(silenced.size(), 1)
	assert_eq(silenced[0]["caster_name"], "Mage")
	assert_eq(caster.current_mp, 5, "silenced cast must not consume MP")


func test_silence_is_cleared_at_battle_end():
	var engine := TurnEngine.new()
	var fighter := _StubCaster.new("F", 30, 0, 999)  # one-shot the slime
	var slime := _StubMonster.new("Slime", 5)
	engine.start_battle([fighter], [slime])
	_inject_repo(engine, _load_repo())
	fighter.statuses.apply(&"silence", 4)
	engine.submit_command(0, AttackCommand.new(slime))
	engine.resolve_turn(_make_rng())
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)
	assert_false(fighter.statuses.has(&"silence"),
		"BATTLE_ONLY silence must clear at battle end")
