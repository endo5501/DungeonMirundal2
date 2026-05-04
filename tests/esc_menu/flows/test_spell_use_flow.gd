extends GutTest


class _FixedRng extends RandomNumberGenerator:
	var _next: int = 0
	func _init(p_next: int = 0) -> void:
		_next = p_next
	func randi_range(_from: int, _to: int) -> int:
		return _next


func _human() -> RaceData:
	return load("res://data/races/human.tres") as RaceData


func _job(filename: String) -> JobData:
	return load("res://data/jobs/" + filename + ".tres") as JobData


# Build a Character bypassing Character.create to set known_spells / MP precisely.
func _make_char(
	p_name: String,
	job_filename: String,
	known_spells: Array[StringName] = [],
	current_mp: int = 5,
	current_hp: int = 8,
	max_hp: int = 10,
) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.race = _human()
	ch.job = _job(job_filename)
	ch.base_stats = {&"STR": 10, &"INT": 12, &"PIE": 12, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.current_hp = current_hp
	ch.max_hp = max_hp
	ch.max_mp = max(current_mp, 5)
	ch.current_mp = current_mp
	ch.known_spells = known_spells.duplicate()
	return ch


func _setup_flow(party: Array[Character], rng_value: int = 0) -> SpellUseFlow:
	var flow := SpellUseFlow.new()
	add_child_autofree(flow)
	flow.set_rng(_FixedRng.new(rng_value))
	flow.setup(party)
	return flow


# --- caster filtering ---

func test_caster_list_excludes_non_magic_jobs():
	var fighter := _make_char("F", "fighter")
	var mage := _make_char("M", "mage", [&"fire", &"frost"], 5)
	var party: Array[Character] = [fighter, mage]
	var flow := _setup_flow(party)
	# Internal `_list_casters()` is exposed only via the SELECT_CASTER refresh.
	# We verify that selecting "the only available caster" (index 0 → mage) works.
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# Mage has only one school (mage_school=true, priest_school=false), so the
	# flow proceeds straight to spell selection.
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.SELECT_SPELL)
	assert_eq(flow.get_caster(), mage)


# --- school skip for non-Bishop ---

func test_priest_skips_school_selection():
	var priest := _make_char("P", "priest", [&"heal", &"holy"], 5)
	var party: Array[Character] = [priest]
	var flow := _setup_flow(party)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.SELECT_SPELL)


func test_bishop_enters_school_selection():
	var bishop := _make_char("B", "bishop", [&"fire", &"heal"], 5)
	var party: Array[Character] = [bishop]
	var flow := _setup_flow(party)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.SELECT_SCHOOL)


# --- battle-only spells filtered out ---

func test_battle_only_spells_are_hidden_outside():
	# Mage knows fire (BATTLE_ONLY). When he opens the spell flow, the list
	# should be empty even though he knows a spell.
	var mage := _make_char("M", "mage", [&"fire"], 5)
	var party: Array[Character] = [mage]
	var flow := _setup_flow(party)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# Now in SELECT_SPELL but the list is empty.
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.SELECT_SPELL)
	# Cancel from empty spell view returns to SELECT_CASTER (Mage is non-Bishop).
	flow.handle_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.SELECT_CASTER)


# --- successful heal cast ---

func test_priest_heal_increases_target_current_hp():
	var priest := _make_char("Bob", "priest", [&"heal"], 5, 10, 10)
	var hurt := _make_char("Alice", "fighter", [], 0, 5, 12)
	var party: Array[Character] = [priest, hurt]
	# fixed RNG so heal roll is +0.
	var flow := _setup_flow(party, 0)
	# SELECT_CASTER: select priest (only magic-capable)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# SELECT_SPELL: at index 0 (heal). Accept.
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# SELECT_TARGET: list contains both Alice + Bob. Default index 0 → priest first.
	# Move down to select Alice and accept.
	flow.handle_input(TestHelpers.make_action_event(&"ui_down"))
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# Now in RESULT.
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.RESULT)
	# Heal base=8, spread=2, RNG returns 0 → +8 heal. Alice 5+8=13 clamped to max 12 → +7 delta.
	assert_eq(hurt.current_hp, 12)
	# Priest MP consumed: heal mp_cost=2 → 5-2=3
	assert_eq(priest.current_mp, 3)


# --- ALLY_ALL allheal skips target selector ---

func test_allheal_skips_target_view_and_heals_all_living():
	var priest := _make_char("Bob", "priest", [&"allheal"], 5, 12, 12)
	var ally1 := _make_char("Alice", "fighter", [], 0, 4, 12)
	var ally2 := _make_char("Carol", "fighter", [], 0, 0, 10)  # dead
	var party: Array[Character] = [priest, ally1, ally2]
	var flow := _setup_flow(party, 0)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))  # caster
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))  # spell
	# Should jump straight to RESULT (no target prompt).
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.RESULT)
	# allheal base=6 spread=2 RNG=0 → +6 each living. Bob full (no change). Alice 4+6=10. Carol dead (skipped).
	assert_eq(priest.current_hp, 12)  # already full
	assert_eq(ally1.current_hp, 10)
	assert_eq(ally2.current_hp, 0)
	# Bob MP: 5 - 5 = 0
	assert_eq(priest.current_mp, 0)


# --- MP-insufficient spell rejected ---

func test_mp_insufficient_keeps_spell_disabled():
	# Heal mp_cost=2, current_mp=1.
	var priest := _make_char("Bob", "priest", [&"heal"], 1, 10, 10)
	var ally := _make_char("Alice", "fighter", [], 0, 5, 12)
	var party: Array[Character] = [priest, ally]
	var flow := _setup_flow(party, 0)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))  # caster
	# In SELECT_SPELL. Disabled row should not advance on accept.
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# Still in SELECT_SPELL.
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.SELECT_SPELL)
	assert_eq(priest.current_mp, 1)  # unchanged
	assert_eq(ally.current_hp, 5)    # unchanged


# --- flow_completed signal returns to caller ---

func test_battle_only_spell_refused_programmatically():
	# Mage knows fire (BATTLE_ONLY). Even if we bypass the UI filter and force
	# the flow into _apply_cast_and_show_result, the cast must be refused: MP
	# unchanged, target HP unchanged.
	var mage := _make_char("M", "mage", [&"fire"], 5, 10, 10)
	var ally := _make_char("A", "fighter", [], 0, 5, 12)
	var party: Array[Character] = [mage, ally]
	var flow := _setup_flow(party, 0)
	# Manually wire the internal state to simulate a programmatic call.
	flow._caster = mage
	flow._spell = load("res://data/spells/fire.tres") as SpellData
	flow._target = ally
	flow._apply_cast_and_show_result()
	assert_eq(flow.get_sub_view(), SpellUseFlow.SubView.RESULT)
	assert_eq(mage.current_mp, 5, "MP must not be consumed")
	assert_eq(ally.current_hp, 5, "ally HP must not change")


func test_flow_completed_emits_with_message_after_result():
	var priest := _make_char("Bob", "priest", [&"heal"], 5, 10, 10)
	var hurt := _make_char("Alice", "fighter", [], 0, 4, 12)
	var party: Array[Character] = [priest, hurt]
	var flow := _setup_flow(party, 0)
	watch_signals(flow)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	flow.handle_input(TestHelpers.make_action_event(&"ui_down"))
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# Confirm RESULT.
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_signal_emitted(flow, "flow_completed")
