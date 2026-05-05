extends GutTest

# End-to-end: casting heal from the ESC menu while a Character is bound
# through PartyHud must update the corresponding PartyMemberPanel inside
# PartyHud's PartyDisplay without any explicit caller-side refresh.
# Mirrors test_esc_menu_heal_refreshes_status_bar.gd but routes through
# the autoload instead of a standalone PartyDisplay.


class _FixedRng extends SpellRng:
	var _next: int = 0
	func _init(p_next: int = 0) -> void:
		super._init(null)
		_next = p_next
	func roll(_low: int, _high: int) -> int:
		return _next


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	GameState.guild = _saved_guild


func _human() -> RaceData:
	return load("res://data/races/human.tres") as RaceData


func _job(filename: String) -> JobData:
	return load("res://data/jobs/" + filename + ".tres") as JobData


func _make_priest(p_name: String, current_mp: int, current_hp: int, max_hp: int) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.race = _human()
	ch.job = _job("priest")
	ch.base_stats = {&"STR": 10, &"INT": 12, &"PIE": 12, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.current_hp = current_hp
	ch.max_hp = max_hp
	ch.current_mp = current_mp
	ch.max_mp = max(current_mp, 5)
	ch.known_spells = [&"heal"]
	return ch


func _make_fighter(p_name: String, current_hp: int, max_hp: int) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.race = _human()
	ch.job = _job("fighter")
	ch.base_stats = {&"STR": 10, &"INT": 10, &"PIE": 10, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.current_hp = current_hp
	ch.max_hp = max_hp
	ch.current_mp = 0
	ch.max_mp = 0
	return ch


func test_esc_menu_heal_refreshes_party_hud_panel():
	var priest := _make_priest("Bob", 5, 10, 10)
	var hurt := _make_fighter("Alice", 5, 12)
	var guild: Guild = GameState.guild
	guild.register(priest)
	guild.register(hurt)
	guild.assign_to_party(priest, 0, 0)
	guild.assign_to_party(hurt, 0, 1)

	# Bind PartyHud to the active party — the autoload's PartyDisplay now
	# owns the live panels.
	var hud := TestHelpers.get_party_hud()
	hud.bind_active_party()
	var pd: PartyDisplay = hud.get_party_display()
	assert_eq(pd._front_panels[1]._data.current_hp, 5, "Alice panel starts at 5")

	# Drive the spell flow exactly as the ESC menu would.
	var flow := SpellUseFlow.new()
	add_child_autofree(flow)
	flow.set_rng(_FixedRng.new(0))
	flow.setup([priest, hurt])
	# SELECT_CASTER → priest
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# SELECT_SPELL → heal (only known spell)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# SELECT_TARGET → move down to Alice (index 1) and accept
	flow.handle_input(TestHelpers.make_action_event(&"ui_down"))
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))

	# Heal applied: Alice 5 + 8 = 13 clamped to max 12.
	assert_eq(hurt.current_hp, 12, "spell effect should mutate Character HP")
	assert_eq(
		pd._front_panels[1]._data.current_hp,
		12,
		"PartyHud's PartyDisplay panel must refresh after ESC heal mutates Character HP",
	)
	assert_eq(pd._front_panels[0]._data.current_hp, 10, "Priest panel unchanged")
