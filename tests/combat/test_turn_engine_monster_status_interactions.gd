extends GutTest

const TEST_SEED: int = 42


# Status-effect interactions with monster casters:
#   - silence + monster cast → cast_silenced (engine path remains correct
#     even though MonsterAi normally filters silenced spells away)
#   - sleep / action_lock on a monster caster → action_locked entry
#   - confusion on a monster caster → existing random-attack swap path
#   - status inflict by a monster cast → actor_status_inflicted signal

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


func _make_witch_data() -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = &"witch"
	data.monster_name = "Witch"
	data.max_hp_min = 30
	data.max_hp_max = 30
	data.max_mp_min = 8
	data.max_mp_max = 8
	data.attack = 5
	data.defense = 2
	data.agility = 99  # acts first
	data.experience = 50
	data.default_row = Row.FRONT
	data.attack_range = WeaponRange.MELEE
	data.known_spells = [&"fire", &"katino"] as Array[StringName]
	return data


func _make_witch() -> MonsterCombatant:
	return MonsterCombatant.new(Monster.new(_make_witch_data(), _make_rng()))


func _make_fire_spell() -> SpellData:
	var fx := DamageSpellEffect.new()
	fx.base_damage = 6
	fx.spread = 0
	var spell := SpellData.new()
	spell.id = &"fire"
	spell.display_name = "ファイア"
	spell.school = SpellData.SCHOOL_MAGE
	spell.level = 1
	spell.mp_cost = 2
	spell.target_type = SpellData.TargetType.ENEMY_ONE
	spell.scope = SpellData.Scope.BATTLE_ONLY
	spell.effect = fx
	return spell


func _make_sleep_spell() -> SpellData:
	# katino-style: status inflict 100%
	var fx := StatusInflictSpellEffect.new()
	fx.status_id = &"sleep"
	fx.chance = 1.0
	fx.duration = 3
	var spell := SpellData.new()
	spell.id = &"katino"
	spell.display_name = "カティノ"
	spell.school = SpellData.SCHOOL_MAGE
	spell.level = 1
	spell.mp_cost = 2
	spell.target_type = SpellData.TargetType.ENEMY_GROUP
	spell.scope = SpellData.Scope.BATTLE_ONLY
	spell.effect = fx
	return spell


func _load_status_repo() -> StatusRepository:
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


func _make_repo(spells: Array) -> SpellRepository:
	var repo := SpellRepository.new()
	for s in spells:
		repo.register(s)
	return repo


func _inject_status_repo(engine: TurnEngine, repo: StatusRepository) -> void:
	engine.status_repo = repo
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(repo)


# --- 6.1 silenced monster ---

func test_silenced_monster_ai_falls_back_to_attack():
	# When silenced, MonsterAi.choose returns AttackCommand (no cast candidate).
	# We verify this by checking that the monster's MP is not consumed.
	var witch := _make_witch()
	var fighter := _StubParty.new("Fighter", 50)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([_make_fire_spell(), _make_sleep_spell()])
	engine.start_battle([fighter], [witch])
	_inject_status_repo(engine, _load_status_repo())
	witch.statuses.apply(&"silence", 4)
	engine.resolve_turn(_make_rng())

	assert_eq(witch.current_mp, 8, "silenced witch should not have cast (MP unchanged)")


# --- 6.2 sleep / action_lock on monster ---

func test_sleeping_monster_does_not_act():
	var witch := _make_witch()
	var fighter := _StubParty.new("Fighter", 50)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([_make_fire_spell()])
	engine.start_battle([fighter], [witch])
	_inject_status_repo(engine, _load_status_repo())
	witch.statuses.apply(&"sleep", 3)
	engine.resolve_turn(_make_rng())

	# Sleep is action_lock → no MP consumed, no damage dealt
	assert_eq(witch.current_mp, 8, "sleeping monster should not have cast")
	assert_eq(fighter.current_hp, 50, "sleeping monster should not have attacked")


# --- 6.3 confusion still routes to confused random-target attack ---

func test_confused_monster_uses_confusion_random_attack_swap():
	# Confusion path is checked BEFORE MonsterAi, so monster still does
	# random-target physical attack even with castable spells available.
	var witch := _make_witch()
	# Place a peer monster so confusion has > 0 monsters to potentially target
	var peer_data := MonsterData.new()
	peer_data.monster_id = &"imp"
	peer_data.monster_name = "Imp"
	peer_data.max_hp_min = 20
	peer_data.max_hp_max = 20
	peer_data.attack = 5
	peer_data.defense = 2
	peer_data.agility = 1
	var peer := MonsterCombatant.new(Monster.new(peer_data, _make_rng()))
	var fighter := _StubParty.new("Fighter", 50)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([_make_fire_spell()])
	engine.start_battle([fighter], [witch, peer])
	_inject_status_repo(engine, _load_status_repo())
	witch.statuses.apply(&"confusion", 3)
	engine.resolve_turn(_make_rng())

	# Confusion path runs without consuming MP (no cast)
	assert_eq(witch.current_mp, 8, "confused monster should not consume MP for cast")


# --- 4.9 / 6.x actor_status_inflicted fires for monster status casts ---

func test_monster_status_cast_emits_actor_status_inflicted():
	var witch := _make_witch()
	var fighter := _StubParty.new("Fighter", 50)
	# Force AI to pick katino by giving witch only katino (sleep inflict).
	witch.monster.data.known_spells = [&"katino"] as Array[StringName]

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([_make_sleep_spell()])
	engine.start_battle([fighter], [witch])
	_inject_status_repo(engine, _load_status_repo())
	var inflicted: Array = []
	engine.actor_status_inflicted.connect(func(a, s): inflicted.append([a, s]))
	# Need 2+ enemies for ENEMY_GROUP precondition — but party only has Fighter.
	# katino with single party member → ENEMY_GROUP precondition fails →
	# AI falls back to attack. Let's add a 2nd party member.
	engine.start_battle([fighter, _StubParty.new("Mage", 30)], [witch])
	_inject_status_repo(engine, _load_status_repo())
	engine.resolve_turn(_make_rng())

	assert_gte(inflicted.size(), 1, "should have inflicted at least one sleep status")
	if inflicted.size() >= 1:
		assert_eq(inflicted[0][1], &"sleep")
