extends GutTest

const TEST_SEED: int = 12345


class _StubPartyActor extends CombatActor:
	var _name: String
	var _attack: int
	var _defense: int
	var _agility: int
	var _hp: int
	var _max: int
	var _mp: int = 0
	var _mp_max: int = 0

	func _init(p_name: String, p_attack: int, p_defense: int, p_agility: int, p_hp: int, p_mp: int = 0) -> void:
		_name = p_name
		actor_name = p_name
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_hp = p_hp
		_max = p_hp
		_mp = p_mp
		_mp_max = p_mp

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

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility


class _StubMonsterActor extends CombatActor:
	var _name: String
	var _attack: int
	var _defense: int
	var _agility: int
	var _hp: int
	var _max: int

	func _init(p_name: String, p_attack: int, p_defense: int, p_agility: int, p_hp: int) -> void:
		_name = p_name
		actor_name = p_name
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_hp = p_hp
		_max = p_hp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _default_party() -> Array:
	return [
		_StubPartyActor.new("P1", 10, 3, 8, 30),
		_StubPartyActor.new("P2", 8, 2, 6, 25),
	]


func _default_monsters() -> Array:
	return [
		_StubMonsterActor.new("M1", 4, 1, 4, 12),
		_StubMonsterActor.new("M2", 3, 1, 3, 10),
	]


# --- state transitions ---

func test_initial_state_is_idle():
	var engine := TurnEngine.new()
	assert_eq(engine.state, TurnEngine.State.IDLE)


func test_start_battle_enters_command_input():
	var engine := TurnEngine.new()
	engine.start_battle(_default_party(), _default_monsters())
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)
	assert_eq(engine.turn_number, 1)


func test_command_input_to_resolving_to_command_input_on_continuation():
	var engine := TurnEngine.new()
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	# Submit party commands: both attack M1
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[0]))
	engine.resolve_turn(_make_rng())
	# Monsters still alive → back to COMMAND_INPUT with incremented turn
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)
	assert_eq(engine.turn_number, 2)


func test_resolving_to_finished_cleared_when_all_monsters_die():
	var engine := TurnEngine.new()
	var party := [_StubPartyActor.new("P1", 999, 0, 10, 30)]  # overkill
	var monsters := [_StubMonsterActor.new("M1", 0, 0, 1, 5)]
	engine.start_battle(party, monsters)
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)


func test_resolving_to_finished_wiped_when_party_dies():
	var engine := TurnEngine.new()
	var party := [_StubPartyActor.new("P1", 0, 0, 1, 2)]  # fragile
	var monsters := [_StubMonsterActor.new("M1", 999, 0, 10, 30)]  # lethal
	engine.start_battle(party, monsters)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.WIPED)


# --- commands queue ---

func test_are_party_commands_complete_false_until_all_submitted():
	var engine := TurnEngine.new()
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	assert_false(engine.are_party_commands_complete())
	engine.submit_command(0, DefendCommand.new())
	assert_false(engine.are_party_commands_complete())
	engine.submit_command(1, DefendCommand.new())
	assert_true(engine.are_party_commands_complete())


func test_dead_party_members_do_not_need_commands():
	var engine := TurnEngine.new()
	var party := _default_party()
	party[1].take_damage(100)  # P2 dead
	engine.start_battle(party, _default_monsters())
	engine.submit_command(0, DefendCommand.new())
	assert_true(engine.are_party_commands_complete())


# --- TurnReport ---

func test_resolve_turn_returns_turn_report_with_actions():
	var engine := TurnEngine.new()
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[1]))
	var report: TurnReport = engine.resolve_turn(_make_rng())
	assert_not_null(report)
	# At least 4 actions: 2 party attacks + 2 monster attacks (assuming nothing died)
	assert_gte(report.actions.size(), 3)


# --- defend halves damage ---

func test_defend_reduces_monster_damage():
	var engine := TurnEngine.new()
	var defender := _StubPartyActor.new("D", 0, 0, 1, 100)
	var monster := _StubMonsterActor.new("M", 10, 0, 10, 20)
	engine.start_battle([defender], [monster])
	engine.submit_command(0, DefendCommand.new())
	# HP before: 100. With defend, damage should be halved.
	engine.resolve_turn(_make_rng())
	var damage_taken := 100 - defender.current_hp
	# Without defend, damage is roughly 10-12 (formula spread). With defend, 5-6.
	assert_true(damage_taken <= 6, "damage_taken=%d should be <= 6 with defend" % damage_taken)


# --- attack re-targets if target dead ---

func test_attack_on_dead_target_is_retargeted_or_skipped():
	var engine := TurnEngine.new()
	var party := [
		_StubPartyActor.new("P1", 999, 0, 10, 30),
		_StubPartyActor.new("P2", 999, 0, 9, 30),
	]
	var monsters := [
		_StubMonsterActor.new("M1", 0, 0, 1, 5),
		_StubMonsterActor.new("M2", 0, 0, 1, 5),
	]
	engine.start_battle(party, monsters)
	# Both party target M1. After P1 attacks, M1 dies. P2 should retarget or skip (not hit dead target).
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[0]))
	engine.resolve_turn(_make_rng())
	# Either M2 is dead (retarget) or M2 is alive (skip). Never should M1 take damage after dying.
	# At minimum: battle should not continue with M1 dead but M2 untouched AND both party still trying to hit M1.
	# Check that the cleanup is correct.
	assert_eq(engine.state, TurnEngine.State.FINISHED)  # all monsters should be dead if retargeted


func test_attack_on_dead_target_records_retargeted_from():
	var engine := TurnEngine.new()
	var party := [
		_StubPartyActor.new("P1", 999, 0, 10, 30),
		_StubPartyActor.new("P2", 999, 0, 9, 30),
	]
	var monsters := [
		_StubMonsterActor.new("M1", 0, 0, 1, 5),
		_StubMonsterActor.new("M2", 0, 0, 1, 5),
	]
	engine.start_battle(party, monsters)
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[0]))
	var report := engine.resolve_turn(_make_rng())
	var retargeted_action: Dictionary = {}
	for action in report.actions:
		if action.get("type", "") == "attack" and action.get("retargeted_from", "") != "":
			retargeted_action = action
			break
	assert_eq(retargeted_action.get("target_name", ""), "M2")
	assert_eq(retargeted_action.get("retargeted_from", ""), "M1")


# --- escape success ---

func test_escape_success_ends_battle_with_escaped_outcome():
	var engine := TurnEngine.new()
	engine.escape_threshold = 1.0  # always succeed
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	engine.submit_command(0, EscapeCommand.new())
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.ESCAPED)


# --- escape failure ---

# --- add-magic-system: Cast command resolution ---

class _StubMonsterWithSpecies extends CombatActor:
	var _name: String
	var _attack: int
	var _defense: int
	var _agility: int
	var _hp: int
	var _max: int
	var _species: StringName

	func _init(
		p_name: String, p_species: StringName, p_attack: int, p_defense: int, p_agility: int, p_hp: int
	) -> void:
		_name = p_name
		actor_name = p_name
		_species = p_species
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_hp = p_hp
		_max = p_hp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility

	func get_species_id() -> StringName:
		return _species


# Lightweight repository factory built from inline SpellData/Effect resources.
func _make_repo_with_fire(base_damage: int = 6, mp_cost: int = 2) -> SpellRepository:
	var repo := SpellRepository.new()
	var fire := SpellData.new()
	fire.id = &"fire"
	fire.display_name = "ファイア"
	fire.school = SpellData.SCHOOL_MAGE
	fire.level = 1
	fire.mp_cost = mp_cost
	fire.target_type = SpellData.TargetType.ENEMY_ONE
	fire.scope = SpellData.Scope.BATTLE_ONLY
	var eff := DamageSpellEffect.new()
	eff.base_damage = base_damage
	eff.spread = 0
	fire.effect = eff
	repo.register(fire)
	return repo


func _make_repo_with_flame(base_damage: int = 5) -> SpellRepository:
	var repo := SpellRepository.new()
	var flame := SpellData.new()
	flame.id = &"flame"
	flame.display_name = "フレイム"
	flame.school = SpellData.SCHOOL_MAGE
	flame.level = 2
	flame.mp_cost = 4
	flame.target_type = SpellData.TargetType.ENEMY_GROUP
	flame.scope = SpellData.Scope.BATTLE_ONLY
	var eff := DamageSpellEffect.new()
	eff.base_damage = base_damage
	eff.spread = 0
	flame.effect = eff
	repo.register(flame)
	return repo


func _make_repo_with_allheal(base_heal: int = 6) -> SpellRepository:
	var repo := SpellRepository.new()
	var s := SpellData.new()
	s.id = &"allheal"
	s.display_name = "オールヒール"
	s.school = SpellData.SCHOOL_PRIEST
	s.level = 2
	s.mp_cost = 5
	s.target_type = SpellData.TargetType.ALLY_ALL
	s.scope = SpellData.Scope.OUTSIDE_OK
	var eff := HealSpellEffect.new()
	eff.base_heal = base_heal
	eff.spread = 0
	s.effect = eff
	repo.register(s)
	return repo


func test_cast_deducts_mp_and_applies_damage():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_fire(6, 2)
	var caster := _StubPartyActor.new("Mage", 1, 0, 5, 10, 5)  # mp=5
	var slime := _StubPartyActor.new("Slime", 0, 0, 1, 12)
	engine.start_battle([caster], [slime])
	var cmd := CastCommand.new(&"fire", 0, slime)
	engine.submit_command(0, cmd)
	var report := engine.resolve_turn(_make_rng())
	assert_eq(caster.current_mp, 3)
	assert_eq(slime.current_hp, 6)
	# Find cast entry in the report
	var cast_action: Dictionary = {}
	for a in report.actions:
		if a.get("type", "") == "cast":
			cast_action = a
			break
	assert_eq(cast_action.get("caster_name", ""), "Mage")
	assert_eq(cast_action.get("spell_id", &""), &"fire")
	assert_eq(cast_action.get("spell_display_name", ""), "ファイア")
	var entries: Array = cast_action.get("entries", [])
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].get("hp_delta", 0), -6)


func test_cast_with_insufficient_mp_emits_skip_no_mp():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_fire(6, 5)
	var caster := _StubPartyActor.new("Mage", 1, 0, 5, 10, 1)
	var slime := _StubPartyActor.new("Slime", 0, 0, 1, 12)
	engine.start_battle([caster], [slime])
	engine.submit_command(0, CastCommand.new(&"fire", 0, slime))
	var report := engine.resolve_turn(_make_rng())
	assert_eq(caster.current_mp, 1)
	assert_eq(slime.current_hp, 12)
	var skip := false
	for a in report.actions:
		if a.get("type", "") == "cast_skipped_no_mp":
			skip = true
			break
	assert_true(skip, "expected cast_skipped_no_mp entry")


func test_cast_with_no_living_target_skips_without_consuming_mp():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_fire(6, 2)
	var caster := _StubPartyActor.new("Mage", 1, 0, 5, 10, 5)
	var slime := _StubPartyActor.new("Slime", 0, 0, 1, 1)
	slime.take_damage(100)  # already dead before resolution
	engine.start_battle([caster], [slime])
	engine.submit_command(0, CastCommand.new(&"fire", 0, slime))
	var report := engine.resolve_turn(_make_rng())
	assert_eq(caster.current_mp, 5)  # MP NOT consumed
	var skip := false
	for a in report.actions:
		if a.get("type", "") == "cast_skipped_no_target":
			skip = true
			break
	assert_true(skip)


func test_cast_enemy_group_hits_all_living_of_species():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_flame(5)
	var caster := _StubPartyActor.new("Mage", 1, 0, 5, 10, 10)
	var slime_a := _StubMonsterWithSpecies.new("SlimeA", &"slime", 0, 0, 1, 12)
	var slime_b := _StubMonsterWithSpecies.new("SlimeB", &"slime", 0, 0, 1, 12)
	var goblin := _StubMonsterWithSpecies.new("Goblin", &"goblin", 0, 0, 1, 12)
	engine.start_battle([caster], [slime_a, slime_b, goblin])
	engine.submit_command(0, CastCommand.new(&"flame", 0, slime_a))
	engine.resolve_turn(_make_rng())
	# Both slimes should take 5 damage; goblin untouched.
	assert_eq(slime_a.current_hp, 7)
	assert_eq(slime_b.current_hp, 7)
	assert_eq(goblin.current_hp, 12)


func test_cast_ally_all_targets_living_party_only():
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_allheal(6)
	var caster := _StubPartyActor.new("Priest", 1, 0, 5, 10, 5)
	var ally_a := _StubPartyActor.new("AllyA", 0, 0, 1, 20)
	var ally_b := _StubPartyActor.new("AllyB", 0, 0, 1, 20)
	var ally_c := _StubPartyActor.new("AllyC", 0, 0, 1, 20)
	ally_a.take_damage(10)  # 10 hp
	ally_b.take_damage(20)  # dead
	ally_c.take_damage(8)   # 12 hp
	# Pre-killed slime so the test isolates the cast (no monster counter-attack).
	var slime := _StubMonsterWithSpecies.new("Slime", &"slime", 0, 0, 1, 1)
	slime.take_damage(100)
	engine.start_battle([caster, ally_a, ally_b, ally_c], [slime])
	engine.submit_command(0, CastCommand.new(&"allheal", 0, null))
	# Defaults for the rest so commands_complete check passes.
	engine.submit_command(1, DefendCommand.new())
	# index 2 (ally_b) is dead → no command needed
	engine.submit_command(3, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(ally_a.current_hp, 16)  # 10 + 6
	assert_eq(ally_b.current_hp, 0)   # still dead
	assert_eq(ally_c.current_hp, 18)  # 12 + 6
	# Caster also gets healed (alive party member). Caster was full → no change.
	assert_eq(caster.current_hp, 10)
	assert_eq(caster.current_mp, 0)   # 5 - 5


func test_cast_retargets_enemy_one_when_original_dies_before_resolve():
	# Caster B gets in second; Slime A dies first turn from caster A; we use a
	# simpler structure: P1 attacks slime_a (kills it), then P2 casts fire on
	# slime_a — should retarget to slime_b (same species).
	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo_with_fire(6, 2)
	var p1 := _StubPartyActor.new("P1", 999, 0, 10, 10)  # overkill
	var p2 := _StubPartyActor.new("P2", 1, 0, 1, 10, 5)  # caster
	var slime_a := _StubMonsterWithSpecies.new("SlimeA", &"slime", 0, 0, 5, 5)
	var slime_b := _StubMonsterWithSpecies.new("SlimeB", &"slime", 0, 0, 4, 12)
	engine.start_battle([p1, p2], [slime_a, slime_b])
	engine.submit_command(0, AttackCommand.new(slime_a))
	engine.submit_command(1, CastCommand.new(&"fire", 1, slime_a))
	var report := engine.resolve_turn(_make_rng())
	assert_false(slime_a.is_alive())
	assert_eq(slime_b.current_hp, 6)  # took the retargeted hit
	# Verify retargeted_from is captured in the cast action.
	var cast_action: Dictionary = {}
	for a in report.actions:
		if a.get("type", "") == "cast":
			cast_action = a
			break
	assert_eq(cast_action.get("retargeted_from", ""), "SlimeA")


func test_escape_failure_forfeits_party_attacks_but_monsters_act():
	var engine := TurnEngine.new()
	engine.escape_threshold = 0.0  # always fail
	var party := [_StubPartyActor.new("P1", 100, 0, 10, 100)]  # strong
	var monsters := [_StubMonsterActor.new("M1", 5, 0, 1, 20)]  # present
	engine.start_battle(party, monsters)
	engine.submit_command(0, EscapeCommand.new())
	var m_hp_before: int = monsters[0].current_hp
	var p_hp_before: int = party[0].current_hp
	engine.resolve_turn(_make_rng())
	# Monster should have taken no damage from party (escape forfeit)
	assert_eq(monsters[0].current_hp, m_hp_before)
	# Party should have taken damage from monster
	assert_lt(party[0].current_hp, p_hp_before)
	# State back to COMMAND_INPUT (not FINISHED)
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)


# --- add-stat-modifier-and-hit-evasion: hit/miss path ---

func test_attack_miss_records_miss_action_and_leaves_target_unharmed():
	# Force a miss using a calibrated RNG; target HP should not change and the
	# report should contain a single "miss" entry for the attacker. Two extra
	# consumes account for TurnOrder's randi_range tiebreak per actor.
	var engine := TurnEngine.new()
	var attacker := _StubPartyActor.new("P1", 10, 0, 10, 30)
	var target := _StubMonsterActor.new("M1", 0, 0, 1, 12)
	engine.start_battle([attacker], [target])
	engine.submit_command(0, AttackCommand.new(target))
	var report := engine.resolve_turn(CombatTestRng.make_certain_miss_rng(2))
	assert_eq(target.current_hp, 12)
	var miss_count := 0
	var attack_count := 0
	for a in report.actions:
		if a.get("type", "") == "miss" and a.get("attacker_name", "") == "P1":
			miss_count += 1
		if a.get("type", "") == "attack" and a.get("attacker_name", "") == "P1":
			attack_count += 1
	assert_eq(miss_count, 1)
	assert_eq(attack_count, 0)


func test_attack_hit_records_attack_action():
	# Force a hit. The attack entry should be present with a positive damage.
	var engine := TurnEngine.new()
	var attacker := _StubPartyActor.new("P1", 10, 0, 10, 30)
	var target := _StubMonsterActor.new("M1", 0, 4, 1, 50)
	engine.start_battle([attacker], [target])
	engine.submit_command(0, AttackCommand.new(target))
	var report := engine.resolve_turn(CombatTestRng.make_certain_hit_rng(2))
	assert_lt(target.current_hp, 50)
	var attack_count := 0
	for a in report.actions:
		if a.get("type", "") == "attack" and a.get("attacker_name", "") == "P1":
			attack_count += 1
			assert_gt(int(a.get("damage", 0)), 0)
	assert_eq(attack_count, 1)


func test_attack_damage_logged_matches_actual_hp_loss_when_defending():
	# Defending halves incoming damage; the attack action's damage field must
	# reflect the actual HP loss (halved), not the raw damage roll, so the
	# combat log doesn't lie to the player.
	var engine := TurnEngine.new()
	var defender := _StubPartyActor.new("P1", 0, 0, 1, 100)
	var monster := _StubMonsterActor.new("M1", 10, 0, 10, 20)
	engine.start_battle([defender], [monster])
	engine.submit_command(0, DefendCommand.new())
	var hp_before := defender.current_hp
	var report := engine.resolve_turn(CombatTestRng.make_certain_hit_rng(2))
	var hp_loss := hp_before - defender.current_hp
	assert_gt(hp_loss, 0)
	var attack_logged := -1
	for a in report.actions:
		if a.get("type", "") == "attack" and a.get("attacker_name", "") == "M1":
			attack_logged = int(a.get("damage", 0))
			assert_true(bool(a.get("defended", false)), "attack should be marked defended")
			break
	assert_eq(attack_logged, hp_loss, "logged damage %d should match actual HP loss %d" % [attack_logged, hp_loss])


# --- add-stat-modifier-and-hit-evasion: end-of-turn modifier tick ---

func test_modifier_stack_ticks_at_end_of_turn():
	# A modifier with duration 2 should still hold after one resolved turn and
	# disappear after two.
	var engine := TurnEngine.new()
	var attacker := _StubPartyActor.new("P1", 10, 0, 10, 30)
	var target := _StubMonsterActor.new("M1", 0, 0, 1, 999)
	engine.start_battle([attacker], [target])
	attacker.modifier_stack.add(&"attack", 2, 2)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(CombatTestRng.make_certain_hit_rng(2))
	assert_eq(int(attacker.modifier_stack.sum(&"attack")), 2)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(CombatTestRng.make_certain_hit_rng(2))
	assert_eq(int(attacker.modifier_stack.sum(&"attack")), 0)


func test_modifier_tick_runs_for_dead_party_and_monsters_too():
	# Even dead actors should have tick_battle_turn called so their entries decay.
	# 3 actors → 3 randi_range tiebreaks before the first hit roll, but only
	# 2 of them are alive so TurnOrder skips dead actors entirely. Use 2.
	var engine := TurnEngine.new()
	var p_alive := _StubPartyActor.new("P1", 5, 0, 5, 30)
	var p_dead := _StubPartyActor.new("P2", 5, 0, 5, 1)
	p_dead.take_damage(10)
	var monster := _StubMonsterActor.new("M1", 0, 0, 1, 999)
	engine.start_battle([p_alive, p_dead], [monster])
	p_dead.modifier_stack.add(&"defense", 3, 1)
	monster.modifier_stack.add(&"agility", 1, 1)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(CombatTestRng.make_certain_hit_rng(2))
	assert_eq(int(p_dead.modifier_stack.sum(&"defense")), 0)
	assert_eq(int(monster.modifier_stack.sum(&"agility")), 0)
