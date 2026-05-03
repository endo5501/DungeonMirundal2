extends GutTest


# --- helpers ---

func _make_sword() -> Item:
	var it := Item.new()
	it.item_id = &"long_sword"
	it.item_name = "Long Sword"
	it.category = Item.ItemCategory.WEAPON
	it.equip_slot = Item.EquipSlot.WEAPON
	it.allowed_jobs = [&"Fighter"]
	return it


func _human() -> RaceData:
	var r := RaceData.new()
	r.race_name = "Human"
	r.base_str = 8
	r.base_int = 8
	r.base_pie = 8
	r.base_vit = 8
	r.base_agi = 8
	r.base_luc = 8
	return r


func _fighter() -> JobData:
	var j := JobData.new()
	j.job_name = "Fighter"
	j.base_hp = 10
	j.has_magic = false
	j.base_mp = 0
	j.required_str = 0
	j.required_int = 0
	j.required_pie = 0
	j.required_vit = 0
	j.required_agi = 0
	j.required_luc = 0
	return j


func _make_fighter(p_name: String) -> Character:
	var alloc := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(p_name, _human(), _fighter(), alloc)


func _setup_one_fighter_with_sword() -> Array:
	# Returns [flow, fighter, sword_instance, inventory]
	var fighter := _make_fighter("Alice")
	var sword := _make_sword()
	var inst := ItemInstance.new(sword, true)
	var inv := Inventory.new()
	inv.add(inst)
	var flow := EquipmentFlow.new()
	add_child_autofree(flow)
	var party: Array[Character] = [fighter]
	flow.setup(party, inv)
	return [flow, fighter, inst, inv]


func _setup_two_fighters_with_swords() -> Array:
	# Returns [flow, alice, bob, alice_sword_inst, bob_sword_inst, inventory]
	var alice := _make_fighter("Alice")
	var bob := _make_fighter("Bob")
	var sword := _make_sword()
	var alice_inst := ItemInstance.new(sword, true)
	var bob_inst := ItemInstance.new(sword, true)
	var inv := Inventory.new()
	inv.add(alice_inst)
	inv.add(bob_inst)
	alice.equipment.equip(Item.EquipSlot.WEAPON, alice_inst, alice)
	bob.equipment.equip(Item.EquipSlot.WEAPON, bob_inst, bob)
	var flow := EquipmentFlow.new()
	add_child_autofree(flow)
	var party: Array[Character] = [alice, bob]
	flow.setup(party, inv)
	return [flow, alice, bob, alice_inst, bob_inst, inv]


func _accept() -> InputEventAction:
	return TestHelpers.make_action_event(&"ui_accept")


func _cancel() -> InputEventAction:
	return TestHelpers.make_action_event(&"ui_cancel")


# --- 2.1 character → slot → candidate ---

func test_setup_initializes_to_character():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	assert_eq(flow._sub_view, EquipmentFlow.SubView.CHARACTER)


func test_character_select_advances_to_slot():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	flow.handle_input(_accept())
	assert_eq(flow._sub_view, EquipmentFlow.SubView.SLOT)


func test_slot_select_advances_to_candidate():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	flow.handle_input(_accept())  # → SLOT
	flow.handle_input(_accept())  # → CANDIDATE (weapon slot)
	assert_eq(flow._sub_view, EquipmentFlow.SubView.CANDIDATE)


# --- 2.2 equip / unequip is called ---

func test_candidate_select_calls_equip():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	var fighter: Character = setup[1]
	var inst: ItemInstance = setup[2]
	flow.handle_input(_accept())  # → SLOT
	flow.handle_input(_accept())  # → CANDIDATE
	flow._candidate_index = 1  # 0 = はずす, 1 = first sword
	flow.handle_input(_accept())  # equip
	assert_eq(fighter.equipment.get_equipped(Item.EquipSlot.WEAPON), inst)
	assert_eq(flow._sub_view, EquipmentFlow.SubView.SLOT)


func test_candidate_unequip_clears_slot():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	var fighter: Character = setup[1]
	var inst: ItemInstance = setup[2]
	# Pre-equip the sword so we can unequip it.
	fighter.equipment.equip(Item.EquipSlot.WEAPON, inst, fighter)
	flow.handle_input(_accept())  # → SLOT
	flow.handle_input(_accept())  # → CANDIDATE
	flow._candidate_index = 0  # はずす
	flow.handle_input(_accept())
	assert_null(fighter.equipment.get_equipped(Item.EquipSlot.WEAPON))
	assert_eq(flow._sub_view, EquipmentFlow.SubView.SLOT)


# --- 2.3 swap from another character ---

func test_swap_takes_item_from_other_holder():
	var setup := _setup_two_fighters_with_swords()
	var flow: EquipmentFlow = setup[0]
	var alice: Character = setup[1]
	var bob: Character = setup[2]
	var alice_inst: ItemInstance = setup[3]
	var bob_inst: ItemInstance = setup[4]
	# Drive Alice (index 0) → WEAPON slot → CANDIDATE
	flow.handle_input(_accept())  # → SLOT for Alice
	flow.handle_input(_accept())  # → CANDIDATE for WEAPON
	# Find Bob's sword in candidate list
	var candidates := flow.get_equipment_candidates()
	var target_idx := -1
	for i in range(candidates.size()):
		if candidates[i] == bob_inst:
			target_idx = i
			break
	assert_gte(target_idx, 0, "bob's sword should appear in alice's candidates")
	flow._candidate_index = target_idx + 1  # +1 for [はずす]
	flow.handle_input(_accept())
	assert_eq(alice.equipment.get_equipped(Item.EquipSlot.WEAPON), bob_inst)
	assert_null(bob.equipment.get_equipped(Item.EquipSlot.WEAPON))


# --- 2.4 ui_cancel back transitions ---

func test_cancel_from_slot_returns_to_character():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	flow.handle_input(_accept())  # → SLOT
	flow.handle_input(_cancel())
	assert_eq(flow._sub_view, EquipmentFlow.SubView.CHARACTER)


func test_cancel_from_candidate_returns_to_slot():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	flow.handle_input(_accept())  # → SLOT
	flow.handle_input(_accept())  # → CANDIDATE
	flow.handle_input(_cancel())
	assert_eq(flow._sub_view, EquipmentFlow.SubView.SLOT)


# --- 2.5 CHARACTER ui_cancel emits flow_completed ---

func test_cancel_from_character_emits_flow_completed():
	var setup := _setup_one_fighter_with_sword()
	var flow: EquipmentFlow = setup[0]
	watch_signals(flow)
	flow.handle_input(_cancel())
	assert_signal_emitted(flow, "flow_completed")
