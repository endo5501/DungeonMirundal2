class_name CombatTestRng
extends RefCounted

# RNG factories for combat tests.
#
# Native methods on RandomNumberGenerator can't be overridden in script (the
# engine bypasses the override). To keep `DamageCalculator.calculate(rng)`'s
# behavior testable, these helpers calibrate a real RNG seed so that the
# next randf() consumed by the engine falls below or above the
# hit-chance clamps. Use them when a test needs to lock in a certain hit or
# miss without relying on the seeded sequence happening to cooperate.
#
# Most test scenarios share a single rng across TurnOrder (which calls
# randi_range once per combatant) and the per-attack hit rolls in
# DamageCalculator. The `extra_consumes` parameter lets the helper
# fast-forward past those tiebreak draws so the FIRST hit roll is the one
# guaranteed-hit/-miss randf.


# Returns an RNG whose hit-roll randf (after `extra_consumes`
# `randi_range(0, 999999)` calls used by TurnOrder for tiebreaks) is < 0.04.
# At the floor hit_chance of 0.05 this still rolls a hit.
static func make_certain_hit_rng(extra_consumes: int = 0) -> RandomNumberGenerator:
	for s in range(1, 5000):
		var r := RandomNumberGenerator.new()
		r.seed = s
		for i in range(extra_consumes):
			r.randi_range(0, 999999)
		if r.randf() < 0.04:
			var fresh := RandomNumberGenerator.new()
			fresh.seed = s
			return fresh
	push_error("CombatTestRng: no seed below 5000 produced a usable certain-hit roll for extra_consumes=%d" % extra_consumes)
	return null


# Returns an RNG whose hit-roll randf (after `extra_consumes`
# `randi_range(0, 999999)` calls used by TurnOrder for tiebreaks) is > 0.99.
# At the ceiling hit_chance of 0.99 this still rolls a miss because the hit
# comparison is strict less-than.
static func make_certain_miss_rng(extra_consumes: int = 0) -> RandomNumberGenerator:
	for s in range(1, 20000):
		var r := RandomNumberGenerator.new()
		r.seed = s
		for i in range(extra_consumes):
			r.randi_range(0, 999999)
		if r.randf() > 0.99:
			var fresh := RandomNumberGenerator.new()
			fresh.seed = s
			return fresh
	push_error("CombatTestRng: no seed below 20000 produced a usable certain-miss roll for extra_consumes=%d" % extra_consumes)
	return null
