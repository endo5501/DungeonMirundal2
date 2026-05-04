extends GutTest

# Verifies that PartyMemberPanel binds to a live Character and refreshes its
# rendered data when the Character emits hp_changed / mp_changed /
# statuses_changed. Also covers unbind and rebind to confirm signals from a
# previously bound Character no longer drive the panel.


func _make_character(name: String, hp: int, mp: int) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.level = 1
	ch.max_hp = hp
	ch.current_hp = hp
	ch.max_mp = mp
	ch.current_mp = mp
	return ch


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


func _displayed_current_hp(panel: PartyMemberPanel) -> int:
	# Tests reach into the panel's _data snapshot to read the value the panel
	# would render. The _data field is what _draw() renders from.
	return panel._data.current_hp


func _displayed_current_mp(panel: PartyMemberPanel) -> int:
	return panel._data.current_mp


# --- HP refresh ---

func test_panel_refreshes_displayed_hp_when_bound_character_changes():
	var ch := _make_character("Hero", 20, 0)
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_eq(_displayed_current_hp(panel), 20)
	ch.current_hp = 15
	assert_eq(_displayed_current_hp(panel), 15)


func test_panel_refreshes_when_max_hp_changes():
	var ch := _make_character("Hero", 20, 0)
	var panel := _make_panel()
	panel.bind_character(ch)
	ch.max_hp = 30
	assert_eq(panel._data.max_hp, 30)


# --- MP refresh ---

func test_panel_refreshes_displayed_mp_when_bound_character_changes():
	var ch := _make_character("Mage", 10, 8)
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_eq(_displayed_current_mp(panel), 8)
	ch.current_mp = 5
	assert_eq(_displayed_current_mp(panel), 5)


# --- A → B switch disconnects A ---

func test_rebinding_to_new_character_ignores_old_character_changes():
	var a := _make_character("Alice", 20, 0)
	var b := _make_character("Bob", 25, 0)
	var panel := _make_panel()
	panel.bind_character(a)
	panel.bind_character(b)
	assert_eq(_displayed_current_hp(panel), 25)
	# Mutating A must not change the panel.
	a.current_hp = 5
	assert_eq(_displayed_current_hp(panel), 25)
	# Mutating B must still drive the panel.
	b.current_hp = 12
	assert_eq(_displayed_current_hp(panel), 12)


# --- Unbind ---

func test_unbinding_disconnects_signals():
	var ch := _make_character("Hero", 20, 0)
	var panel := _make_panel()
	panel.bind_character(ch)
	panel.bind_character(null)
	# After unbind, mutations on the previously-bound Character must not update
	# the panel. _data may have been cleared, but the absence of any panel
	# refresh is what we care about — assert the connection is gone.
	assert_false(ch.hp_changed.is_connected(panel._on_character_hp_changed))
	assert_false(ch.mp_changed.is_connected(panel._on_character_mp_changed))
	assert_false(ch.statuses_changed.is_connected(panel._on_character_statuses_changed))


# --- Backward compat: set_member(PartyMemberData) still works ---

func test_set_member_with_party_member_data_still_works():
	var data := PartyMemberData.new("Static", 3, 7, 10, 0, 0)
	var panel := _make_panel()
	panel.set_member(data)
	assert_eq(_displayed_current_hp(panel), 7)


func test_set_member_after_bind_character_disconnects_old_character():
	var ch := _make_character("Hero", 20, 0)
	var panel := _make_panel()
	panel.bind_character(ch)
	# Switch to a snapshot-based PartyMemberData; this should disconnect the
	# Character signal handlers.
	var data := PartyMemberData.new("Static", 1, 5, 10, 0, 0)
	panel.set_member(data)
	assert_false(ch.hp_changed.is_connected(panel._on_character_hp_changed))
	# Mutating the previously-bound Character must not change the panel display.
	ch.current_hp = 1
	assert_eq(_displayed_current_hp(panel), 5)
