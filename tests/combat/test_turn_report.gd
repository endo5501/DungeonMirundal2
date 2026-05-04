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


# --- add-status-effect-infrastructure: new entry types ---

func test_add_tick_damage():
	var report := TurnReport.new()
	var actor := _StubActor.new("Alice")
	report.add_tick_damage(actor, &"poison", 2, false)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "tick_damage")
	assert_eq(a.get("actor_name"), "Alice")
	assert_eq(a.get("status_id"), &"poison")
	assert_eq(a.get("amount"), 2)
	assert_false(a.get("killed_by_tick"))


func test_add_tick_damage_with_killed_by_tick():
	var report := TurnReport.new()
	var actor := _StubActor.new("Alice")
	report.add_tick_damage(actor, &"poison", 5, true)
	var a: Dictionary = report.actions[0]
	assert_true(a.get("killed_by_tick"))


func test_add_wake():
	var report := TurnReport.new()
	var actor := _StubActor.new("Alice")
	report.add_wake(actor, &"sleep")
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "wake")
	assert_eq(a.get("actor_name"), "Alice")
	assert_eq(a.get("status_id"), &"sleep")


func test_add_inflict():
	var report := TurnReport.new()
	var target := _StubActor.new("Slime A")
	report.add_inflict(target, &"poison", true)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "inflict")
	assert_eq(a.get("target_name"), "Slime A")
	assert_eq(a.get("status_id"), &"poison")
	assert_true(a.get("success"))


func test_add_cure():
	var report := TurnReport.new()
	var actor := _StubActor.new("Alice")
	report.add_cure(actor, &"poison")
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "cure")
	assert_eq(a.get("actor_name"), "Alice")
	assert_eq(a.get("status_id"), &"poison")


func test_add_resist():
	var report := TurnReport.new()
	var target := _StubActor.new("Slime A")
	report.add_resist(target, &"sleep")
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "resist")
	assert_eq(a.get("target_name"), "Slime A")
	assert_eq(a.get("status_id"), &"sleep")


func test_add_stat_mod():
	var report := TurnReport.new()
	var target := _StubActor.new("Bob")
	report.add_stat_mod(target, &"attack", 2, 3)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "stat_mod")
	assert_eq(a.get("target_name"), "Bob")
	assert_eq(a.get("stat"), &"attack")
	assert_eq(a.get("delta"), 2)
	assert_eq(a.get("turns"), 3)


func test_add_action_locked():
	var report := TurnReport.new()
	var actor := _StubActor.new("Alice")
	report.add_action_locked(actor)
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "action_locked")
	assert_eq(a.get("actor_name"), "Alice")


func test_add_cast_silenced():
	var report := TurnReport.new()
	var caster := _StubActor.new("Mage")
	report.add_cast_silenced(caster, &"fire")
	var a: Dictionary = report.actions[0]
	assert_eq(a.get("type"), "cast_silenced")
	assert_eq(a.get("caster_name"), "Mage")
	assert_eq(a.get("spell_id"), &"fire")
