extends GutTest

# Verifies PartyMemberPanel paints a semi-transparent dim overlay over the
# whole panel when the bound Character is incapacitated:
#   current_hp <= 0 OR persistent_statuses contains sleep/paralysis/petrify.
# poison, confusion, blind, and silence by themselves are NOT incapacitating.


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


# --- Incapacitating conditions ---

func test_hp_zero_dims_panel():
	var ch := TestHelpers.make_test_character("Dead", 0, [])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_true(panel.is_incapacitated(),
		"current_hp = 0 should mark panel as incapacitated")


func test_sleep_dims_panel():
	var ch := TestHelpers.make_test_character("Sleepy", 5, [&"sleep"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_true(panel.is_incapacitated(), "sleep is incapacitating")


func test_paralysis_dims_panel():
	var ch := TestHelpers.make_test_character("Paralyzed", 5, [&"paralysis"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_true(panel.is_incapacitated(), "paralysis is incapacitating")


func test_petrify_dims_panel():
	var ch := TestHelpers.make_test_character("Stoned", 5, [&"petrify"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_true(panel.is_incapacitated(), "petrify is incapacitating")


# --- Non-incapacitating conditions ---

func test_poison_alone_does_not_dim():
	var ch := TestHelpers.make_test_character("Poisoned", 5, [&"poison"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_false(panel.is_incapacitated(), "poison alone should not incapacitate")


func test_confusion_alone_does_not_dim():
	var ch := TestHelpers.make_test_character("Confused", 5, [&"confusion"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_false(panel.is_incapacitated(), "confusion alone should not incapacitate")


func test_blind_alone_does_not_dim():
	var ch := TestHelpers.make_test_character("Blind", 5, [&"blind"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_false(panel.is_incapacitated(), "blind alone should not incapacitate")


func test_silence_alone_does_not_dim():
	var ch := TestHelpers.make_test_character("Silent", 5, [&"silence"])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_false(panel.is_incapacitated(), "silence alone should not incapacitate")


# --- Recovery clears the dim ---

func test_hp_recovery_clears_dim():
	var ch := TestHelpers.make_test_character("Reviver", 0, [])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_true(panel.is_incapacitated())
	ch.current_hp = 5
	assert_false(panel.is_incapacitated(),
		"raising HP above zero should clear the dim")


# --- Snapshot mode is not dimmed ---

func test_snapshot_mode_is_not_dimmed():
	# PartyMemberData snapshot path lacks live HP/status, so dim must be
	# off (it can't be evaluated reliably without a Character).
	var data := PartyMemberData.new("Snap", 1, 0, 10, 0, 0)
	var panel := _make_panel()
	panel.set_member(data)
	assert_false(panel.is_incapacitated(),
		"snapshot mode should not paint the dim overlay")
