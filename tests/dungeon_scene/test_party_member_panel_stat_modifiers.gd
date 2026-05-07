extends GutTest

# PartyMemberPanel renders one icon per StatModifierStack entry while bound to
# a CombatActor. Without a CombatActor binding, no icons are rendered even if
# persistent_statuses are present (the persistent_status row is its own thing).


class _StubActor extends CombatActor:
	func _init() -> void:
		super()


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


# --- API exists ---

func test_panel_exposes_stat_modifier_icons():
	var p := _make_panel()
	assert_true(p.has_method("get_stat_modifier_icons"))


# --- empty / unbound ---

func test_get_stat_modifier_icons_empty_when_unbound():
	var p := _make_panel()
	assert_eq(p.get_stat_modifier_icons().size(), 0)


func test_get_stat_modifier_icons_empty_when_actor_has_no_modifiers():
	var p := _make_panel()
	var a := _StubActor.new()
	p.bind_combat_actor(a)
	assert_eq(p.get_stat_modifier_icons().size(), 0)


# --- single buff / debuff ---

func test_buff_renders_one_icon_with_positive_label():
	var p := _make_panel()
	var a := _StubActor.new()
	a.modifier_stack.add(&"attack", 2, 3)
	p.bind_combat_actor(a)
	var icons: Array = p.get_stat_modifier_icons()
	assert_eq(icons.size(), 1)
	var icon: Dictionary = icons[0]
	assert_eq(icon["stat"], &"attack")
	assert_gt(int(icon["delta"]), 0)
	assert_eq(icon["label"], "A+")


func test_debuff_renders_one_icon_with_negative_label():
	var p := _make_panel()
	var a := _StubActor.new()
	a.modifier_stack.add(&"defense", -1, 2)
	p.bind_combat_actor(a)
	var icons: Array = p.get_stat_modifier_icons()
	assert_eq(icons.size(), 1)
	var icon: Dictionary = icons[0]
	assert_eq(icon["stat"], &"defense")
	assert_lt(int(icon["delta"]), 0)
	assert_eq(icon["label"], "D-")


# --- multiple entries ---

func test_multiple_modifiers_render_one_icon_each():
	var p := _make_panel()
	var a := _StubActor.new()
	a.modifier_stack.add(&"attack", 2, 3)
	a.modifier_stack.add(&"defense", -1, 2)
	a.modifier_stack.add(&"agility", 1, 4)
	p.bind_combat_actor(a)
	assert_eq(p.get_stat_modifier_icons().size(), 3)


# --- buff colors lean green, debuff lean red ---

func test_buff_color_is_greenish():
	var p := _make_panel()
	var a := _StubActor.new()
	a.modifier_stack.add(&"attack", 2, 3)
	p.bind_combat_actor(a)
	var icons: Array = p.get_stat_modifier_icons()
	var c: Color = icons[0]["color"]
	assert_gt(c.g, c.r, "buff icon color should lean green")


func test_debuff_color_is_reddish():
	var p := _make_panel()
	var a := _StubActor.new()
	a.modifier_stack.add(&"attack", -2, 3)
	p.bind_combat_actor(a)
	var icons: Array = p.get_stat_modifier_icons()
	var c: Color = icons[0]["color"]
	assert_gt(c.r, c.g, "debuff icon color should lean red")


func test_stat_modifier_icon_rects_do_not_overlap_hp_or_mp_bars():
	var p := _make_panel()
	var a := _StubActor.new()
	a.modifier_stack.add(&"attack", 2, 3)
	a.modifier_stack.add(&"defense", -1, 2)
	p.bind_combat_actor(a)
	if not p.has_method("get_stat_modifier_icon_rects"):
		fail_test("PartyMemberPanel should expose get_stat_modifier_icon_rects")
		return
	var rects: Array = p.get_stat_modifier_icon_rects(0)
	assert_gt(rects.size(), 0)
	for rect in rects:
		assert_false((rect as Rect2).intersects(p.get_hp_bar_rect()),
			"stat modifier icon should not overlap HP bar")
		assert_false((rect as Rect2).intersects(p.get_mp_bar_rect()),
			"stat modifier icon should not overlap MP bar")
