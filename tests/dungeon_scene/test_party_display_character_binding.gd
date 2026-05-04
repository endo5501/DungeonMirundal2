extends GutTest

# Verifies PartyDisplay can be bound to live Character arrays so that
# subsequent state mutations on those Characters refresh the corresponding
# PartyMemberPanel automatically. Existing setup(party_data: PartyData)
# snapshot path is unchanged.


func _make_character(name: String, hp: int) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.level = 1
	ch.max_hp = hp
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func _make_display() -> PartyDisplay:
	var d := PartyDisplay.new()
	add_child_autofree(d)
	return d


# --- bind_party_characters happy path ---

func test_binding_characters_routes_signals_to_correct_panel():
	var alice := _make_character("Alice", 20)
	var bob := _make_character("Bob", 15)
	var carol := _make_character("Carol", 18)
	var display := _make_display()
	display.bind_party_characters([alice, bob, carol], [null, null, null])
	# Mutate Bob's HP. Only the second front-row panel should reflect this.
	bob.current_hp = 7
	assert_eq(display._front_panels[0]._data.current_hp, 20, "Alice panel unchanged")
	assert_eq(display._front_panels[1]._data.current_hp, 7, "Bob panel reflects new HP")
	assert_eq(display._front_panels[2]._data.current_hp, 18, "Carol panel unchanged")


func test_binding_characters_handles_null_slots():
	var alice := _make_character("Alice", 20)
	var display := _make_display()
	display.bind_party_characters([alice, null, null], [null, null, null])
	# Alice in slot 0 still drives that panel.
	alice.current_hp = 10
	assert_eq(display._front_panels[0]._data.current_hp, 10)
	# Empty slots have no _data (snapshot mode with null).
	assert_null(display._front_panels[1]._data)
	assert_null(display._front_panels[2]._data)


func test_back_row_characters_drive_back_panels():
	var dave := _make_character("Dave", 30)
	var display := _make_display()
	display.bind_party_characters([null, null, null], [dave, null, null])
	dave.current_hp = 15
	assert_eq(display._back_panels[0]._data.current_hp, 15)
