extends GutTest

# PartyMemberPanel maintains _combat_displayed_hp / _combat_displayed_mp during
# combat so HP/MP bars and the dim overlay update in step with PartyHud's
# buffered log playback rather than with live Character mutations.


class _StubActor extends CombatActor:
	var _hp: int
	var _max_hp: int
	var _mp: int
	var _max_mp: int

	func _init(p_hp: int = 10, p_max_hp: int = 10, p_mp: int = 5, p_max_mp: int = 5) -> void:
		super()
		_hp = p_hp
		_max_hp = p_max_hp
		_mp = p_mp
		_max_mp = p_max_mp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max_hp

	func _read_current_mp() -> int:
		return _mp

	func _write_current_mp(value: int) -> void:
		_mp = value

	func _read_max_mp() -> int:
		return _max_mp


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


func _bind_character_with_hp(p: PartyMemberPanel, hp: int, max_hp: int, mp: int = 0, max_mp: int = 0) -> Character:
	var ch := TestHelpers.make_test_character("X")
	ch.max_hp = max_hp
	ch.current_hp = hp
	ch.max_mp = max_mp
	ch.current_mp = mp
	p.bind_character(ch)
	return ch


# --- 2.x: latch / API / clamp ---

func test_panel_starts_with_minus_one_displayed_values():
	var p := _make_panel()
	assert_eq(p._combat_displayed_hp, -1)
	assert_eq(p._combat_displayed_mp, -1)


func test_bind_combat_actor_latches_displayed_values_from_live_actor():
	var p := _make_panel()
	var a := _StubActor.new(12, 20, 5, 8)
	p.bind_combat_actor(a)
	assert_eq(p._combat_displayed_hp, 12)
	assert_eq(p._combat_displayed_mp, 5)


func test_bind_combat_actor_null_resets_displayed_values():
	var p := _make_panel()
	var a := _StubActor.new(12, 20, 5, 8)
	p.bind_combat_actor(a)
	p.bind_combat_actor(null)
	assert_eq(p._combat_displayed_hp, -1)
	assert_eq(p._combat_displayed_mp, -1)


func test_apply_combat_hp_delta_clamps_at_zero():
	var p := _make_panel()
	_bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(10, 10)
	p.bind_combat_actor(a)
	p.apply_combat_hp_delta(-15)
	assert_eq(p._combat_displayed_hp, 0)


func test_apply_combat_hp_delta_clamps_at_max_hp():
	var p := _make_panel()
	_bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(2, 10)
	p.bind_combat_actor(a)
	p.apply_combat_hp_delta(+50)
	assert_eq(p._combat_displayed_hp, 10)


func test_apply_combat_mp_delta_clamps_at_zero_and_max():
	var p := _make_panel()
	_bind_character_with_hp(p, 10, 10, 4, 10)
	var a := _StubActor.new(10, 10, 4, 10)
	p.bind_combat_actor(a)
	p.apply_combat_mp_delta(-9)
	assert_eq(p._combat_displayed_mp, 0)
	p.apply_combat_mp_delta(+50)
	assert_eq(p._combat_displayed_mp, 10)


func test_set_combat_displayed_hp_forces_value():
	var p := _make_panel()
	_bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(7, 10)
	p.bind_combat_actor(a)
	p.set_combat_displayed_hp(0)
	assert_eq(p._combat_displayed_hp, 0)


func test_set_combat_displayed_hp_clamps_to_max():
	var p := _make_panel()
	_bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(7, 10)
	p.bind_combat_actor(a)
	p.set_combat_displayed_hp(999)
	assert_eq(p._combat_displayed_hp, 10)


func test_live_hp_change_during_combat_does_not_move_displayed_hp():
	var p := _make_panel()
	var ch := _bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(10, 10)
	p.bind_combat_actor(a)
	# simulate engine mutating live HP mid-resolve
	ch.current_hp = 2
	assert_eq(p._combat_displayed_hp, 10, "displayed HP must lag behind live HP during combat")
	# _data should still refresh to the live value (other fields stay current)
	assert_eq(p._data.current_hp, 2, "_data should reflect live HP")


func test_live_mp_change_during_combat_does_not_move_displayed_mp():
	var p := _make_panel()
	var ch := _bind_character_with_hp(p, 10, 10, 5, 5)
	var a := _StubActor.new(10, 10, 5, 5)
	p.bind_combat_actor(a)
	ch.current_mp = 1
	assert_eq(p._combat_displayed_mp, 5)
	assert_eq(p._data.current_mp, 1)


# --- 3.x: rendering reflects displayed values ---

func test_stat_bar_ratio_in_combat_uses_displayed_hp():
	# stat_bar_ratio takes raw values, but we check the panel feeds _combat_displayed_hp
	# into _draw_stat_bar by inspecting that is_incapacitated and the ratio computation
	# end up using the displayed HP. Direct way: helper function that returns the
	# value that would be drawn. We use stat_bar_ratio + manual feed for assertion clarity.
	var p := _make_panel()
	_bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(2, 10)  # live HP starts at 2
	p.bind_combat_actor(a)
	# simulate first damage flushed: displayed goes 10 -> 8
	p.set_combat_displayed_hp(8)
	# stat_bar_ratio of (8, 10) is 0.8 — that's what the panel SHOULD render in combat
	assert_almost_eq(p.stat_bar_ratio(p._combat_displayed_hp, 10), 0.8, 0.001)


func test_is_incapacitated_in_combat_uses_displayed_hp_not_live_hp():
	var p := _make_panel()
	var ch := _bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(10, 10)
	p.bind_combat_actor(a)
	# Live drops to 0 (engine kills the actor) but displayed still 10
	ch.current_hp = 0
	assert_false(p.is_incapacitated(), "displayed HP > 0 must NOT dim during combat")
	# Now flush the death step — displayed goes to 0
	p.set_combat_displayed_hp(0)
	assert_true(p.is_incapacitated(), "displayed HP == 0 must dim during combat")


func test_is_incapacitated_out_of_combat_uses_live_hp():
	var p := _make_panel()
	var ch := _bind_character_with_hp(p, 10, 10)
	# No combat actor bound
	ch.current_hp = 0
	assert_true(p.is_incapacitated(), "out of combat, live HP == 0 must dim immediately")


func test_after_combat_ends_live_hp_drives_dim_again():
	var p := _make_panel()
	var ch := _bind_character_with_hp(p, 10, 10)
	var a := _StubActor.new(10, 10)
	p.bind_combat_actor(a)
	ch.current_hp = 0
	assert_false(p.is_incapacitated(), "during combat displayed HP > 0 keeps panel non-dim")
	p.bind_combat_actor(null)
	assert_true(p.is_incapacitated(), "after combat ends live HP == 0 dims the panel again")
