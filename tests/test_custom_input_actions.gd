extends GutTest


# Smoke test: confirms project.godot defines the custom dungeon-input actions
# and that TestHelpers.make_action_event drives is_action_pressed for them.
# If any of these fail, the [input] section in project.godot is missing or
# misnamed, and downstream action-based input tests will not behave correctly.

func _assert_action(action: StringName) -> void:
	assert_true(InputMap.has_action(action),
		"InputMap should define %s" % action)
	var ev := TestHelpers.make_action_event(action)
	assert_true(ev.is_action_pressed(action),
		"make_action_event(%s) should be considered pressed for %s" % [action, action])


func test_move_forward_action_defined():
	_assert_action(&"move_forward")


func test_move_back_action_defined():
	_assert_action(&"move_back")


func test_strafe_left_action_defined():
	_assert_action(&"strafe_left")


func test_strafe_right_action_defined():
	_assert_action(&"strafe_right")


func test_turn_left_action_defined():
	_assert_action(&"turn_left")


func test_turn_right_action_defined():
	_assert_action(&"turn_right")


func test_toggle_full_map_action_defined():
	_assert_action(&"toggle_full_map")
