extends GutTest

# Verifies PartyHud.bind_active_party() reads the current active party from
# GameState.guild and forwards it to its internal PartyDisplay's
# bind_party_characters(front, back), with empty slots as null entries.


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	GameState.guild = _saved_guild


func _hud() -> Node:
	return TestHelpers.get_party_hud()


func _display_panels(hud: Node) -> Array:
	var pd: PartyDisplay = hud.get_party_display()
	return [pd._front_panels, pd._back_panels]


func test_bind_active_party_full_party():
	var guild: Guild = GameState.guild
	var f0 := TestHelpers.make_test_character("F0")
	var f1 := TestHelpers.make_test_character("F1")
	var f2 := TestHelpers.make_test_character("F2")
	var b0 := TestHelpers.make_test_character("B0")
	var b1 := TestHelpers.make_test_character("B1")
	var b2 := TestHelpers.make_test_character("B2")
	guild.register(f0); guild.register(f1); guild.register(f2)
	guild.register(b0); guild.register(b1); guild.register(b2)
	guild.assign_to_party(f0, 0, 0)
	guild.assign_to_party(f1, 0, 1)
	guild.assign_to_party(f2, 0, 2)
	guild.assign_to_party(b0, 1, 0)
	guild.assign_to_party(b1, 1, 1)
	guild.assign_to_party(b2, 1, 2)

	var hud := _hud()
	hud.bind_active_party()

	var panels := _display_panels(hud)
	var front: Array = panels[0]
	var back: Array = panels[1]
	assert_eq(front[0]._character, f0)
	assert_eq(front[1]._character, f1)
	assert_eq(front[2]._character, f2)
	assert_eq(back[0]._character, b0)
	assert_eq(back[1]._character, b1)
	assert_eq(back[2]._character, b2)


func test_bind_active_party_partial_leaves_nulls():
	var guild: Guild = GameState.guild
	var f0 := TestHelpers.make_test_character("F0")
	var f1 := TestHelpers.make_test_character("F1")
	var b0 := TestHelpers.make_test_character("B0")
	guild.register(f0); guild.register(f1); guild.register(b0)
	guild.assign_to_party(f0, 0, 0)
	guild.assign_to_party(f1, 0, 1)
	guild.assign_to_party(b0, 1, 0)

	var hud := _hud()
	hud.bind_active_party()

	var panels := _display_panels(hud)
	var front: Array = panels[0]
	var back: Array = panels[1]
	assert_eq(front[0]._character, f0)
	assert_eq(front[1]._character, f1)
	assert_null(front[2]._character, "empty front slot 2 should be null")
	assert_eq(back[0]._character, b0)
	assert_null(back[1]._character)
	assert_null(back[2]._character)


func test_bind_active_party_with_null_guild_is_safe():
	GameState.guild = null
	var hud := _hud()
	# Should not throw or push errors when GameState.guild is null.
	hud.bind_active_party()
	pass_test("bind_active_party with null guild did not error")
