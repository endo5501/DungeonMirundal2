extends GutTest

# CombatMonsterPanel maintains _displayed_alive (MonsterCombatant -> bool) so
# species counts shown in the ENEMY list update in step with PartyHud's
# buffered death events, not at TurnEngine.resolve_turn return.


func _make_monster_data(id: StringName, display_name: String) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = display_name
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.attack = 1
	data.defense = 0
	data.agility = 1
	return data


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r


func _make_monster(data: MonsterData) -> MonsterCombatant:
	return MonsterCombatant.new(Monster.new(data, _rng()))


func _make_panel() -> CombatMonsterPanel:
	var p := CombatMonsterPanel.new()
	add_child_autofree(p)
	return p


# --- API exists ---

func test_panel_exposes_displayed_alive_api():
	var p := _make_panel()
	assert_true(p.has_method("setup_for_battle"))
	assert_true(p.has_method("apply_died"))


# --- setup_for_battle initializes all monsters as alive ---

func test_setup_for_battle_initializes_all_alive():
	var data := _make_monster_data(&"slime", "スライム")
	var monsters: Array = [_make_monster(data), _make_monster(data), _make_monster(data)]
	var p := _make_panel()
	p.setup_for_battle(monsters)
	for m in monsters:
		assert_true(p._displayed_alive.get(m, false), "every monster should start displayed-alive")
	assert_eq(p._displayed_alive.size(), 3)


# --- apply_died flips a single entry ---

func test_apply_died_marks_one_monster_as_displayed_dead():
	var data := _make_monster_data(&"slime", "スライム")
	var m1 := _make_monster(data)
	var m2 := _make_monster(data)
	var p := _make_panel()
	p.setup_for_battle([m1, m2])
	p.apply_died(m1)
	assert_false(p._displayed_alive.get(m1, true), "m1 should be displayed-dead after apply_died")
	assert_true(p._displayed_alive.get(m2, false), "m2 should still be displayed-alive")


# --- refresh aggregates from _displayed_alive, NOT live is_alive() ---

func test_refresh_uses_displayed_alive_not_live_is_alive():
	# Two slimes alive at engine level. Panel's _displayed_alive marks one dead.
	# The displayed text must show 1/2, not 2/2.
	var data := _make_monster_data(&"slime", "スライム")
	var alive_a := _make_monster(data)
	var alive_b := _make_monster(data)
	# Both monsters are still alive in engine state (current_hp > 0).
	var p := _make_panel()
	p.setup_for_battle([alive_a, alive_b])
	p.apply_died(alive_a)
	p.refresh([alive_a, alive_b], {&"slime": 2})
	assert_string_contains(p.get_display_text(), "スライム 1/2")


func test_refresh_shows_zero_when_all_displayed_dead():
	var data := _make_monster_data(&"slime", "スライム")
	var m1 := _make_monster(data)
	var m2 := _make_monster(data)
	var p := _make_panel()
	p.setup_for_battle([m1, m2])
	p.apply_died(m1)
	p.apply_died(m2)
	p.refresh([m1, m2], {&"slime": 2})
	assert_string_contains(p.get_display_text(), "スライム 0/2")


func test_refresh_ignores_live_dead_when_displayed_alive_says_alive():
	# Engine kills the monster atomically (current_hp = 0), but no apply_died
	# has flushed yet — panel must still show it alive until the death step.
	var data := _make_monster_data(&"slime", "スライム")
	var m := _make_monster(data)
	var p := _make_panel()
	p.setup_for_battle([m])
	# Simulate engine atomic kill BEFORE the death-step flush.
	m.monster.current_hp = 0
	p.refresh([m], {&"slime": 1})
	assert_string_contains(p.get_display_text(), "スライム 1/1",
		"panel must remain on the pre-death count until apply_died is flushed")
