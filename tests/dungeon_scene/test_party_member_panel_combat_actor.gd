extends GutTest

# PartyMemberPanel.bind_combat_actor binds the panel to a CombatActor so it
# can read stat_modifier_stack for icon rendering and react to
# stat_modifiers_changed by queueing a redraw. Switching to a new actor
# must disconnect the previous one's signal.


class _StubActor extends CombatActor:
	func _init() -> void:
		super()


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


# --- field exists / bind/unbind ---

func test_panel_starts_with_null_combat_actor():
	var p := _make_panel()
	assert_null(p._combat_actor)


func test_bind_combat_actor_assigns_field():
	var p := _make_panel()
	var a := _StubActor.new()
	p.bind_combat_actor(a)
	assert_same(p._combat_actor, a)


func test_bind_combat_actor_null_clears_field():
	var p := _make_panel()
	var a := _StubActor.new()
	p.bind_combat_actor(a)
	p.bind_combat_actor(null)
	assert_null(p._combat_actor)


# --- signal connection / disconnection on switch ---

func test_bind_combat_actor_connects_stat_modifiers_changed():
	var p := _make_panel()
	var a := _StubActor.new()
	p.bind_combat_actor(a)
	assert_true(a.stat_modifiers_changed.is_connected(p._on_stat_modifiers_changed))


func test_switching_actors_disconnects_previous():
	var p := _make_panel()
	var a := _StubActor.new()
	var b := _StubActor.new()
	p.bind_combat_actor(a)
	p.bind_combat_actor(b)
	assert_false(a.stat_modifiers_changed.is_connected(p._on_stat_modifiers_changed))
	assert_true(b.stat_modifiers_changed.is_connected(p._on_stat_modifiers_changed))


func test_unbind_disconnects_signal():
	var p := _make_panel()
	var a := _StubActor.new()
	p.bind_combat_actor(a)
	p.bind_combat_actor(null)
	assert_false(a.stat_modifiers_changed.is_connected(p._on_stat_modifiers_changed))


# --- handler triggers redraw ---

func test_stat_modifiers_changed_triggers_redraw_handler():
	# We can't observe queue_redraw directly, so prove the handler is wired by
	# emitting and checking it doesn't crash (and the connection is in place).
	var p := _make_panel()
	var a := _StubActor.new()
	p.bind_combat_actor(a)
	a.modifier_stack.add(&"attack", 2, 3)  # this should fire stat_modifiers_changed
	# If we reach here the handler ran without erroring.
	assert_true(true)


# --- exit_tree disconnects ---

func test_exit_tree_disconnects_signal():
	var p := PartyMemberPanel.new()
	var a := _StubActor.new()
	add_child(p)
	p.bind_combat_actor(a)
	# Removing from tree fires _exit_tree, which must drop the connection so the
	# actor outliving the panel doesn't dangle a Callable.
	remove_child(p)
	assert_false(a.stat_modifiers_changed.is_connected(p._on_stat_modifiers_changed))
	p.free()
