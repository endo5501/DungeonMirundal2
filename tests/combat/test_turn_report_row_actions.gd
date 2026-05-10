extends GutTest


class _StubActor extends CombatActor:
	func _init(p_name: String) -> void:
		super()
		actor_name = p_name


func test_add_wait_appends_documented_entry():
	var report := TurnReport.new()
	var actor := _StubActor.new("Bat")
	report.add_wait(actor)
	assert_eq(report.actions.size(), 1)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type", ""), "wait")
	assert_eq(a.get("actor_name", ""), "Bat")


func test_add_wait_handles_null_actor():
	var report := TurnReport.new()
	report.add_wait(null)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type", ""), "wait")
	assert_eq(a.get("actor_name", ""), "")


func test_add_attack_unreachable_appends_documented_entry():
	var report := TurnReport.new()
	var attacker := _StubActor.new("Bob")
	var target := _StubActor.new("Witch")
	report.add_attack_unreachable(attacker, target)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type", ""), "attack_unreachable")
	assert_eq(a.get("attacker_name", ""), "Bob")
	assert_eq(a.get("target_name", ""), "Witch")
