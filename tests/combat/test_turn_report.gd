extends GutTest


class _StubActor extends CombatActor:
	func _init(p_name: String) -> void:
		actor_name = p_name


func test_add_miss_appends_miss_action():
	var report := TurnReport.new()
	var attacker := _StubActor.new("Alice")
	var target := _StubActor.new("Slime A")
	report.add_miss(attacker, target)
	assert_eq(report.actions.size(), 1)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type", ""), "miss")
	assert_eq(a.get("attacker_name", ""), "Alice")
	assert_eq(a.get("target_name", ""), "Slime A")


func test_add_miss_handles_null_actors():
	var report := TurnReport.new()
	report.add_miss(null, null)
	assert_eq(report.actions.size(), 1)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type", ""), "miss")
	assert_eq(a.get("attacker_name", ""), "")
	assert_eq(a.get("target_name", ""), "")


# Existing add_attack shape stays intact: type=attack, with damage/defended/retargeted_from.
# Miss is recorded as a separate entry (no `hit: bool` field added to attack entries).
func test_add_attack_shape_unchanged():
	var report := TurnReport.new()
	var attacker := _StubActor.new("Alice")
	var target := _StubActor.new("Slime A")
	report.add_attack(attacker, target, 7, false, "")
	assert_eq(report.actions.size(), 1)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type", ""), "attack")
	assert_eq(a.get("attacker_name", ""), "Alice")
	assert_eq(a.get("target_name", ""), "Slime A")
	assert_eq(a.get("damage", -1), 7)
	assert_eq(a.get("defended", true), false)
	assert_eq(a.get("retargeted_from", "_"), "")
	# add_attack must NOT introduce a `hit` field.
	assert_false(a.has("hit"))
