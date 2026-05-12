extends GutTest

const TEST_SEED: int = 42


# Status-effect interactions with monster casters:
#   - silence + monster cast → cast falls back to attack (no MP consumed)
#   - sleep / action_lock on a monster caster → action_locked path
#   - confusion on a monster caster → existing random-attack swap path
#   - status inflict by a monster cast → actor_status_inflicted signal


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	return MonsterTestFactory.make_rng(seed_value)


func _make_witch() -> MonsterCombatant:
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.FRONT, WeaponRange.MELEE, 8, 8,
		[&"fire", &"katino"], 30, 5, 2, 99
	)
	return MonsterTestFactory.make_monster_combatant(data, _make_rng())


func _make_fire_spell() -> SpellData:
	return MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)


func _make_sleep_spell() -> SpellData:
	var fx := StatusInflictSpellEffect.new()
	fx.status_id = &"sleep"
	fx.chance = 1.0
	fx.duration = 3
	return MonsterTestFactory.build_spell(&"katino", SpellData.TargetType.ENEMY_GROUP, 2, fx)


# --- 6.1 silenced monster ---

func test_silenced_monster_ai_falls_back_to_attack():
	var witch := _make_witch()
	var fighter := StubPartyCombatant.new("Fighter", 50)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([_make_fire_spell(), _make_sleep_spell()])
	engine.start_battle([fighter], [witch])
	MonsterTestFactory.wire_status_repo(engine)
	witch.statuses.apply(&"silence", 4)
	engine.resolve_turn(_make_rng())

	assert_eq(witch.current_mp, 8, "silenced witch should not have cast (MP unchanged)")


# --- 6.2 sleep / action_lock on monster ---

func test_sleeping_monster_does_not_act():
	var witch := _make_witch()
	var fighter := StubPartyCombatant.new("Fighter", 50)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([_make_fire_spell()])
	engine.start_battle([fighter], [witch])
	MonsterTestFactory.wire_status_repo(engine)
	witch.statuses.apply(&"sleep", 3)
	engine.resolve_turn(_make_rng())

	assert_eq(witch.current_mp, 8, "sleeping monster should not have cast")
	assert_eq(fighter.current_hp, 50, "sleeping monster should not have attacked")


# --- 6.3 confusion still routes to confused random-target attack ---

func test_confused_monster_uses_confusion_random_attack_swap():
	var witch := _make_witch()
	var peer_data := MonsterTestFactory.make_monster_data(
		&"imp", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 5, 2, 1
	)
	var peer := MonsterTestFactory.make_monster_combatant(peer_data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 50)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([_make_fire_spell()])
	engine.start_battle([fighter], [witch, peer])
	MonsterTestFactory.wire_status_repo(engine)
	witch.statuses.apply(&"confusion", 3)
	engine.resolve_turn(_make_rng())

	assert_eq(witch.current_mp, 8, "confused monster should not consume MP for cast")


# --- 4.9 / 6.x actor_status_inflicted fires for monster status casts ---

func test_monster_status_cast_emits_actor_status_inflicted():
	# katino targets ENEMY_GROUP, which requires ≥2 party members.
	var witch := _make_witch()
	# Force AI to pick katino only.
	witch.monster.data.known_spells = [&"katino"] as Array[StringName]
	var fighter := StubPartyCombatant.new("Fighter", 50)
	var mage := StubPartyCombatant.new("Mage", 30)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([_make_sleep_spell()])
	engine.start_battle([fighter, mage], [witch])
	MonsterTestFactory.wire_status_repo(engine)
	var inflicted: Array = []
	engine.actor_status_inflicted.connect(func(a, s): inflicted.append([a, s]))
	engine.resolve_turn(_make_rng())

	assert_gte(inflicted.size(), 1, "should have inflicted at least one sleep status")
	if inflicted.size() >= 1:
		assert_eq(inflicted[0][1], &"sleep")
