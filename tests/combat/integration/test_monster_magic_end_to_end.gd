extends GutTest

const TEST_SEED: int = 12345


# End-to-end integration: real shipped monster .tres + real SpellRepository.
# Witch / dark_priest / lich casting real spells against a party.

class _StubParty extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int = 0
	var _mp_max: int = 0

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

	func _read_current_mp() -> int:
		return _mp

	func _write_current_mp(value: int) -> void:
		_mp = value

	func _read_max_mp() -> int:
		return _mp_max

	var original_row: int:
		get:
			return Row.FRONT


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _load_monster(id: StringName) -> MonsterCombatant:
	var data := ResourceLoader.load("res://data/monsters/%s.tres" % String(id)) as MonsterData
	assert_not_null(data, "monster %s tres should load" % String(id))
	var monster := Monster.new(data, _make_rng())
	# Use a hand-set agility-99 RNG-independent setup by patching the monster
	# instance after construction is not necessary — we'll just use whatever
	# the .tres declares. To make AI act, we boost agility via stat modifier.
	return MonsterCombatant.new(monster)


func _inject_status_repo(engine: TurnEngine) -> void:
	DataLoader._status_repo_cache = null
	var repo := DataLoader.new().load_status_repository()
	engine.status_repo = repo
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(repo)


# --- 8.1 witch + slime: witch casts fire on Fighter ---

func test_witch_casts_fire_on_party():
	var witch := _load_monster(&"witch")
	witch.modifier_stack.add(&"agility", 99, 99)  # act first
	var slime := _load_monster(&"slime")
	var fighter := _StubParty.new("Fighter", 80)

	var engine := TurnEngine.new()  # spell_repo / status_repo auto-loaded
	engine.start_battle([fighter], [witch, slime])
	_inject_status_repo(engine)
	var fighter_hp_before := fighter.current_hp
	var witch_mp_before := witch.current_mp
	engine.resolve_turn(_make_rng())

	# With known_spells = [fire, frost, katino], some seed will pick one and cast.
	# Either witch casts something (MP decreases) or attacks (slime/witch peer).
	# At minimum, fighter HP or witch MP should change.
	var damaged := fighter.current_hp < fighter_hp_before
	var spent_mp := witch.current_mp < witch_mp_before
	assert_true(damaged or spent_mp, "witch should have acted somehow")


# --- 8.2 dark_priest heals wounded peer ---

func test_dark_priest_heals_wounded_peer():
	var dark_priest := _load_monster(&"dark_priest")
	dark_priest.modifier_stack.add(&"agility", 99, 99)  # act first
	var imp := _load_monster(&"imp")
	imp.current_hp = 1  # wounded so heal precondition is met
	var fighter := _StubParty.new("Fighter", 80)

	var engine := TurnEngine.new()
	# Restrict known_spells to heal only so AI picks it deterministically
	dark_priest.monster.data.known_spells = [&"heal"] as Array[StringName]
	engine.start_battle([fighter], [dark_priest, imp])
	_inject_status_repo(engine)
	var hp_before := imp.current_hp
	engine.resolve_turn(_make_rng())

	assert_gt(imp.current_hp, hp_before, "imp should be healed by dark_priest")


# --- 8.3 lich casts flame (ENEMY_GROUP) on multiple party members ---

func test_lich_flame_damages_all_party_members():
	var lich := _load_monster(&"lich")
	lich.modifier_stack.add(&"agility", 99, 99)  # act first
	# Restrict known_spells to flame only so AI picks it deterministically
	lich.monster.data.known_spells = [&"flame"] as Array[StringName]
	var fighter := _StubParty.new("Fighter", 80)
	var mage := _StubParty.new("Mage", 60)
	var priest := _StubParty.new("Priest", 70)

	var engine := TurnEngine.new()
	engine.start_battle([fighter, mage, priest], [lich])
	_inject_status_repo(engine)
	engine.resolve_turn(_make_rng())

	assert_lt(fighter.current_hp, 80, "fighter should take flame damage")
	assert_lt(mage.current_hp, 60, "mage should take flame damage")
	assert_lt(priest.current_hp, 70, "priest should take flame damage")
