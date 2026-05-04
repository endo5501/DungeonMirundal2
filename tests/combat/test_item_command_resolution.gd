extends GutTest


class _StubActor:
	extends CombatActor
	var hp: int = 40
	var max: int = 40
	var agi: int = 10
	var alive: bool = true

	func _init(name: String, p_hp: int = 40, p_max: int = 40, p_agi: int = 10) -> void:
		actor_name = name
		hp = p_hp
		max = p_max
		agi = p_agi

	func _read_current_hp() -> int:
		return hp
	func _write_current_hp(v: int) -> void:
		hp = maxi(0, v)
	func _read_max_hp() -> int:
		return max
	func get_agility() -> int:
		return agi
	func get_attack() -> int:
		return 1
	func get_defense() -> int:
		return 0


func _make_potion(power: int = 20) -> Item:
	var it := Item.new()
	it.item_id = &"potion"
	it.item_name = "ポーション"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	var e := HealHpEffect.new()
	e.power = power
	it.effect = e
	var tc: Array[TargetCondition] = [AliveOnly.new(), NotFullHp.new()]
	it.target_conditions = tc
	return it


func _make_emergency_scroll() -> Item:
	var it := Item.new()
	it.item_id = &"emergency_escape_scroll"
	it.item_name = "緊急脱出の巻物"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	it.effect = EscapeToTownEffect.new()
	return it


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return rng


# --- cancellation when actor dies ---

func test_item_command_is_cancelled_when_actor_dies_before_turn():
	var attacker := _StubActor.new("A", 40, 40, 20)  # fast
	var user := _StubActor.new("U", 1, 40, 5)  # slow, nearly dead
	var potion := _make_potion(20)
	var inst := ItemInstance.new(potion, true)
	var inv := Inventory.new()
	inv.add(inst)
	var engine := TurnEngine.new()
	engine.inventory = inv
	engine.start_battle([user], [attacker])
	engine.submit_command(0, ItemCommand.new(user, inst, user))
	var report := engine.resolve_turn(_make_rng())
	# User should be dead from the attacker before their turn
	# Verify instance was NOT removed (cancelled)
	assert_true(inv.contains(inst))


# --- successful heal consumes instance ---

func test_item_command_heals_target_and_removes_instance():
	var user := _StubActor.new("U", 40, 40, 15)
	var user_target := _StubActor.new("T", 10, 40, 10)
	var dead_monster := _StubActor.new("M", 0, 40, 1)  # dead, won't act
	var potion := _make_potion(20)
	var inst := ItemInstance.new(potion, true)
	var inv := Inventory.new()
	inv.add(inst)
	var engine := TurnEngine.new()
	engine.inventory = inv
	engine.start_battle([user, user_target], [dead_monster])
	engine.submit_command(0, ItemCommand.new(user, inst, user_target))
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(user_target.hp, 30)
	assert_false(inv.contains(inst))


# --- emergency escape ---

func test_emergency_scroll_in_combat_triggers_escaped_outcome():
	var user := _StubActor.new("U", 40, 40, 10)
	var monster := _StubActor.new("M", 40, 40, 5)
	var scroll := _make_emergency_scroll()
	var inst := ItemInstance.new(scroll, true)
	var inv := Inventory.new()
	inv.add(inst)
	var engine := TurnEngine.new()
	engine.inventory = inv
	engine.start_battle([user], [monster])
	engine.submit_command(0, ItemCommand.new(user, inst, null))
	engine.resolve_turn(_make_rng())
	var outcome := engine.outcome()
	assert_not_null(outcome)
	assert_eq(outcome.result, EncounterOutcome.Result.ESCAPED)
	assert_true(outcome.request_town_return)
	assert_false(inv.contains(inst))


func test_emergency_scroll_in_combat_gives_no_exp_or_gold():
	var user := _StubActor.new("U", 40, 40, 10)
	var monster := _StubActor.new("M", 40, 40, 5)
	var scroll := _make_emergency_scroll()
	var inst := ItemInstance.new(scroll, true)
	var inv := Inventory.new()
	inv.add(inst)
	var engine := TurnEngine.new()
	engine.inventory = inv
	engine.start_battle([user], [monster])
	engine.submit_command(0, ItemCommand.new(user, inst, null))
	engine.resolve_turn(_make_rng())
	var outcome := engine.outcome()
	assert_eq(outcome.gained_experience, 0)
	assert_eq(outcome.gained_gold, 0)


# --- command menu includes item option ---

func test_command_menu_base_option_ids_include_item():
	# base_option_ids() exposes the static contract: which options are always
	# present for any party actor regardless of job. We verify ITEM is in there
	# and the list has exactly the 4 base options (no magic-class additions).
	var ids := CombatCommandMenu.base_option_ids()
	assert_eq(ids.size(), 4)
	assert_true(CombatCommandMenu.OPT_ITEM in ids, "OPT_ITEM must be in base options")


func test_command_menu_item_is_at_opt_item_index():
	assert_eq(CombatCommandMenu.OPT_ITEM, 2)
	assert_eq(CombatCommandMenu.OPTION_LABELS[CombatCommandMenu.OPT_ITEM], "アイテム")
	assert_eq(CombatCommandMenu.OPT_ESCAPE, 3)


# --- atomicity: duplicate ItemCommand for same instance ---

func test_two_commands_sharing_one_instance_only_apply_once():
	var user_a := _StubActor.new("A", 40, 40, 20)
	var user_b := _StubActor.new("B", 40, 40, 15)
	var target := _StubActor.new("T", 10, 40, 10)
	var dead_monster := _StubActor.new("M", 0, 40, 1)
	var potion := _make_potion(20)
	var inst := ItemInstance.new(potion, true)
	var inv := Inventory.new()
	inv.add(inst)
	var engine := TurnEngine.new()
	engine.inventory = inv
	engine.start_battle([user_a, user_b, target], [dead_monster])
	engine.submit_command(0, ItemCommand.new(user_a, inst, target))
	engine.submit_command(1, ItemCommand.new(user_b, inst, target))
	engine.submit_command(2, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	# First use heals +20 (10 -> 30). Second use must NOT apply again.
	assert_eq(target.hp, 30)
	assert_false(inv.contains(inst))


# --- atomicity: target no longer alive at resolution ---

func test_item_is_not_consumed_when_target_is_dead_at_resolution():
	var target := _StubActor.new("T", 0, 40, 10)  # already dead
	var healer := _StubActor.new("H", 40, 40, 15)
	var dead_monster := _StubActor.new("M", 0, 40, 1)
	var potion := _make_potion(20)
	var inst := ItemInstance.new(potion, true)
	var inv := Inventory.new()
	inv.add(inst)
	var engine := TurnEngine.new()
	engine.inventory = inv
	engine.start_battle([healer, target], [dead_monster])
	engine.submit_command(0, ItemCommand.new(healer, inst, target))
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	# AliveOnly rechecked at resolution: target dead → instance not consumed, no "revive" heal.
	assert_true(inv.contains(inst))
	assert_eq(target.hp, 0)
