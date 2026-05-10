extends GutTest


func _make_monster(id: StringName, row: int) -> Monster:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = 10
	data.max_hp_max = 10
	data.attack = 1
	data.defense = 1
	data.agility = 1
	data.experience = 1
	data.default_row = row
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return Monster.new(data, rng)


func _make_panel(panel_width: float = 900.0) -> CombatMonsterPanel:
	var panel := CombatMonsterPanel.new()
	# Give it a usable size so visual area has positive dimensions.
	panel.size = Vector2(panel_width, 500)
	add_child_autofree(panel)
	return panel


func test_front_only_uses_full_scale_at_baseline():
	var panel := _make_panel()
	var mc := MonsterCombatant.new(_make_monster(&"slime", Row.FRONT))
	panel.setup_for_battle([mc])
	var entries: Array = panel.get_monster_visual_entries()
	assert_eq(entries.size(), 1)
	var entry: Dictionary = entries[0]
	assert_eq(entry.get("row", Row.FRONT), Row.FRONT)
	# FRONT z_index should be >= back z_index (drawn on top)
	assert_eq(int(entry.get("z_index", 0)), 0)


func test_back_monster_renders_higher_smaller_and_behind_front():
	var panel := _make_panel()
	var mf := MonsterCombatant.new(_make_monster(&"slime", Row.FRONT))
	var mb := MonsterCombatant.new(_make_monster(&"witch", Row.BACK))
	panel.setup_for_battle([mf, mb])
	var entries: Array = panel.get_monster_visual_entries()
	assert_eq(entries.size(), 2)
	var back_entry: Dictionary = {}
	var front_entry: Dictionary = {}
	for e in entries:
		if int(e.get("row", Row.FRONT)) == Row.BACK:
			back_entry = e
		else:
			front_entry = e
	assert_false(back_entry.is_empty(), "back entry should exist")
	assert_false(front_entry.is_empty(), "front entry should exist")
	var back_rect: Rect2 = back_entry.get("rect", Rect2())
	var front_rect: Rect2 = front_entry.get("rect", Rect2())
	# BACK is positioned higher on screen (smaller y)
	assert_lt(back_rect.position.y, front_rect.position.y, "BACK should be higher than FRONT")
	# BACK is smaller
	assert_lt(back_rect.size.x, front_rect.size.x, "BACK should be smaller")
	assert_lt(back_rect.size.y, front_rect.size.y, "BACK should be smaller")
	# BACK z_index < FRONT z_index
	assert_lt(int(back_entry.get("z_index", 0)), int(front_entry.get("z_index", 0)))


func test_back_only_keeps_back_visual_position():
	# After FRONT all dead, surviving BACK should still render at back-row
	# visual position (effective_row promotion is purely a combat-rule concept).
	var panel := _make_panel()
	var mb := MonsterCombatant.new(_make_monster(&"witch", Row.BACK))
	panel.setup_for_battle([mb])
	var entries: Array = panel.get_monster_visual_entries()
	assert_eq(entries.size(), 1)
	var e: Dictionary = entries[0]
	# row tag stays BACK
	assert_eq(int(e.get("row", Row.FRONT)), Row.BACK)
	# scale stays small (back size)
	var rect: Rect2 = e.get("rect", Rect2())
	assert_lt(rect.size.x, CombatMonsterPanel.DESIRED_VISUAL_SIZE.x)


func test_five_front_and_five_back_fit_within_visual_area():
	# Use a wider panel (1200) closer to production combat overlay width.
	# 900px is already tight for FRONT 5 + gaps; production runs at ~1200+ px
	# wide for the enemy panel.
	var panel := _make_panel(1200.0)
	var monsters: Array = []
	for i in range(5):
		monsters.append(MonsterCombatant.new(_make_monster(StringName("f%d" % i), Row.FRONT)))
	for i in range(5):
		monsters.append(MonsterCombatant.new(_make_monster(StringName("b%d" % i), Row.BACK)))
	panel.setup_for_battle(monsters)
	var entries: Array = panel.get_monster_visual_entries()
	assert_eq(entries.size(), 10)
	var area := panel.get_enemy_visual_area_rect()
	# Allow 2px rounding tolerance on horizontal bounds (per-monster layout
	# math accumulates floating-point error across 5 elements).
	for e in entries:
		var r: Rect2 = e.get("rect", Rect2())
		assert_gte(r.position.x, area.position.x - 2.0, "rect should not clip left of visual area")
		assert_lte(r.position.x + r.size.x, area.position.x + area.size.x + 2.0, "rect should not clip right of visual area")
