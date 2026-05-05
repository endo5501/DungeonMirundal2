extends GutTest


# Integration: StatModifierStack β rule applied through real spell .tres files.
#
# β rule (StatModifierStack.add):
#   - stronger     → replace delta + duration
#   - equal magnitude → keep delta, take max(duration)
#   - weaker       → no-op

class _StubActor extends CombatActor:
	var _hp: int = 30
	var _max: int = 30

	func _init() -> void:
		actor_name = "Stub"

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


# Different stats: porfic (DEF) and a separate ATK modifier coexist independently.
func test_different_stats_coexist_independently():
	var porfic := load("res://data/spells/porfic.tres") as SpellData
	var fighter := _StubActor.new()
	porfic.effect.apply(null, [fighter], null)
	# Add an attack modifier via a separately-configured StatModSpellEffect.
	var atk_eff := StatModSpellEffect.new()
	atk_eff.stat = &"attack"
	atk_eff.delta = 1
	atk_eff.turns = 5
	atk_eff.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"attack"), 1,
		"separate-stat modifier should be added without touching DEF")
	assert_eq(fighter.modifier_stack.sum(&"defense"), 2,
		"porfic's DEF +2 should still be active alongside the ATK modifier")


# Same stat, equal magnitude: keep delta, take max(duration). Two porfic casts
# of identical strength must not stack into +4 DEF.
func test_same_stat_equal_magnitude_keeps_max_duration():
	var porfic := load("res://data/spells/porfic.tres") as SpellData
	var fighter := _StubActor.new()
	porfic.effect.apply(null, [fighter], null)
	# Sanity: defense is +2 / 4 turns after first cast.
	assert_eq(fighter.modifier_stack.sum(&"defense"), 2)
	# Second porfic from "another caster" — same delta and turns. β rule keeps
	# the existing entry (delta stays at +2, duration unchanged at max(4,4)=4).
	porfic.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"defense"), 2,
		"equal-magnitude same-stat re-cast must not stack to +4")
	# After 4 ticks the entry should be gone, confirming duration was 4 (not 8).
	for i in range(4):
		fighter.modifier_stack.tick_battle_turn()
	assert_eq(fighter.modifier_stack.sum(&"defense"), 0,
		"duration must remain 4 (not refreshed beyond the original)")


# Same stat, stronger replaces both delta and duration. A +3/1 turn modifier
# added on top of porfic (+2/4 turns) replaces it entirely.
func test_same_stat_stronger_replaces_delta_and_duration():
	var porfic := load("res://data/spells/porfic.tres") as SpellData
	var fighter := _StubActor.new()
	porfic.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"defense"), 2)
	# Apply a stronger DEF buff (+3 / 1 turn).
	var stronger := StatModSpellEffect.new()
	stronger.stat = &"defense"
	stronger.delta = 3
	stronger.turns = 1
	stronger.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"defense"), 3,
		"stronger delta should replace the prior entry")
	# Duration was 1, so a single tick must drop the entry to 0.
	fighter.modifier_stack.tick_battle_turn()
	assert_eq(fighter.modifier_stack.sum(&"defense"), 0,
		"replacement also overrode the duration to 1")
