extends GutTest

# Verifies Guild.active_party_changed fires when the active party
# composition changes, and PartyHud rebinds in response so the HUD's
# panels track guild edits without explicit screen-side calls.


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	GameState.guild = _saved_guild


func _hud() -> Node:
	return get_node("/root/PartyHud")


func _make_character(p_name: String) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func test_guild_emits_active_party_changed_on_assign():
	var guild: Guild = GameState.guild
	var ch := _make_character("Alice")
	guild.register(ch)
	watch_signals(guild)
	guild.assign_to_party(ch, 0, 0)
	assert_signal_emitted(guild, "active_party_changed",
		"assign_to_party should emit active_party_changed")


func test_guild_emits_active_party_changed_on_remove():
	var guild: Guild = GameState.guild
	var ch := _make_character("Alice")
	guild.register(ch)
	guild.assign_to_party(ch, 0, 0)
	watch_signals(guild)
	guild.remove_from_party(0, 0)
	assert_signal_emitted(guild, "active_party_changed",
		"remove_from_party should emit active_party_changed")


func test_party_hud_rebinds_when_guild_emits_change():
	var guild: Guild = GameState.guild
	var hud := _hud()
	# bind_active_party once so the connection is initialised against the
	# current GameState.guild instance.
	hud.bind_active_party()

	# Add a member after binding; the HUD's connection on the live guild
	# should re-pull the party and the new character should land in slot 0.
	var alice := _make_character("Alice")
	guild.register(alice)
	guild.assign_to_party(alice, 0, 0)

	var pd: PartyDisplay = hud.get_party_display()
	assert_eq(pd._front_panels[0]._character, alice,
		"HUD front[0] should track Alice after assign emits the signal")


func test_party_hud_rebinds_after_remove():
	var guild: Guild = GameState.guild
	var alice := _make_character("Alice")
	guild.register(alice)
	guild.assign_to_party(alice, 0, 0)
	var hud := _hud()
	hud.bind_active_party()
	assert_eq(hud.get_party_display()._front_panels[0]._character, alice)

	guild.remove_from_party(0, 0)
	assert_null(hud.get_party_display()._front_panels[0]._character,
		"HUD front[0] should become null after remove emits the signal")
