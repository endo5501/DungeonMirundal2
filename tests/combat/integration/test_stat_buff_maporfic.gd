extends GutTest


# Integration: maporfic (DEF +2 / 4 turns / ALLY_ALL) raises every living party
# member's defense by +2 and emits one stat_mod entry per living target.

class _StubActor extends CombatActor:
	var _base_atk: int
	var _base_def: int
	var _base_agi: int
	var _hp: int
	var _max: int

	func _init(p_atk: int, p_def: int, p_agi: int, p_hp: int = 30) -> void:
		_base_atk = p_atk
		_base_def = p_def
		_base_agi = p_agi
		_hp = p_hp
		_max = p_hp
		actor_name = "Stub"

	func _get_base_attack() -> int:
		return _base_atk

	func _get_base_defense() -> int:
		return _base_def

	func _get_base_agility() -> int:
		return _base_agi

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func test_maporfic_loads_and_buffs_every_living_member():
	var maporfic := load("res://data/spells/maporfic.tres") as SpellData
	assert_not_null(maporfic)
	var alice := _StubActor.new(0, 4, 5)
	alice.actor_name = "Alice"
	var bob := _StubActor.new(0, 4, 5)
	bob.actor_name = "Bob"
	var carol := _StubActor.new(0, 4, 5)
	carol.actor_name = "Carol"
	# TurnEngine filters out dead members before passing to apply, so only living
	# targets reach the effect — mirror that here.
	var living_party: Array = [alice, bob, carol]
	var resolution := maporfic.effect.apply(null, living_party, null)
	assert_eq(resolution.entries.size(), 3, "maporfic should emit one entry per living target")
	for member in living_party:
		assert_eq(member.modifier_stack.sum(&"defense"), 2,
			"%s should have defense +2 after maporfic" % member.actor_name)
		assert_eq(member.get_defense(), 6)


func test_maporfic_emits_stat_mod_event_per_target():
	var maporfic := load("res://data/spells/maporfic.tres") as SpellData
	var alice := _StubActor.new(0, 4, 5)
	var bob := _StubActor.new(0, 4, 5)
	var resolution := maporfic.effect.apply(null, [alice, bob], null)
	for entry in resolution.entries:
		var events: Array = entry["events"]
		assert_eq(events.size(), 1)
		assert_eq(events[0]["type"], "stat_mod")
		assert_eq(events[0]["stat"], &"defense")
		assert_eq(events[0]["delta"], 2)
		assert_eq(events[0]["turns"], 4)


# Pins the engine→report wiring for stat_mod events. Without this, only the
# cast-announcement line ("X は マポーフィック を唱えた！") would surface to
# CombatLog and the per-target effect lines would silently disappear.
func test_engine_cast_emits_stat_mod_actions_for_each_living_party_member():
	var maporfic := load("res://data/spells/maporfic.tres") as SpellData
	var caster := _StubActor.new(0, 0, 5)
	caster.actor_name = "Priest"
	# StubActor has no MP backing; bypass the cost so the cast doesn't bail.
	var fake_spell := SpellData.new()
	fake_spell.id = maporfic.id
	fake_spell.display_name = maporfic.display_name
	fake_spell.school = maporfic.school
	fake_spell.level = maporfic.level
	fake_spell.mp_cost = 0
	fake_spell.target_type = maporfic.target_type
	fake_spell.scope = maporfic.scope
	fake_spell.effect = maporfic.effect
	var alice := _StubActor.new(0, 4, 5)
	alice.actor_name = "Alice"
	var bob := _StubActor.new(0, 4, 5)
	bob.actor_name = "Bob"
	var slime := _StubActor.new(0, 0, 1, 30)
	slime.actor_name = "Slime"
	var engine := TurnEngine.new()
	engine.start_battle([caster, alice, bob], [slime])
	var stub_repo := SpellRepository.new()
	stub_repo.register(fake_spell)
	engine.spell_repo = stub_repo
	engine.submit_command(0, CastCommand.new(maporfic.id, 0, alice))
	engine.submit_command(1, DefendCommand.new())
	engine.submit_command(2, DefendCommand.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var report := engine.resolve_turn(rng)
	var stat_mods := []
	for a in report.actions:
		if a.get("type") == "stat_mod":
			stat_mods.append(a)
	assert_eq(stat_mods.size(), 3,
		"engine should emit one stat_mod action per living party member (3)")
	var names: Array = []
	for s in stat_mods:
		names.append(s["target_name"])
		assert_eq(s["stat"], &"defense")
		assert_eq(s["delta"], 2)
		assert_eq(s["turns"], 4)
	names.sort()
	assert_eq(names, ["Alice", "Bob", "Priest"])
