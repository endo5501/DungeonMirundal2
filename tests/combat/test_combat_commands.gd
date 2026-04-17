extends GutTest


class _StubActor extends CombatActor:
	var _hp: int = 10
	var _max: int = 10

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


# --- AttackCommand ---

func test_attack_command_is_refcounted():
	var cmd := AttackCommand.new(_StubActor.new())
	assert_is(cmd, RefCounted)


func test_attack_command_holds_target():
	var target := _StubActor.new()
	var cmd := AttackCommand.new(target)
	assert_eq(cmd.target, target)


func test_attack_command_target_is_nullable():
	var cmd := AttackCommand.new(null)
	assert_eq(cmd.target, null)


# --- DefendCommand ---

func test_defend_command_is_refcounted():
	var cmd := DefendCommand.new()
	assert_is(cmd, RefCounted)


func test_defend_command_applies_defend_to_actor():
	var actor := _StubActor.new()
	var cmd := DefendCommand.new()
	cmd.apply_to(actor)
	assert_true(actor.is_defending())


# --- EscapeCommand ---

func test_escape_command_is_refcounted():
	var cmd := EscapeCommand.new()
	assert_is(cmd, RefCounted)
