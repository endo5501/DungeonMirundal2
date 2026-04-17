class_name DamageCalculator
extends RefCounted

const SPREAD_MIN: int = 0
const SPREAD_MAX: int = 2


static func apply_formula(attack: int, defense: int, spread: int) -> int:
	return maxi(1, attack - defense / 2 + spread)


static func calculate_by_stats(attack: int, defense: int, rng: RandomNumberGenerator) -> int:
	var spread := rng.randi_range(SPREAD_MIN, SPREAD_MAX)
	return apply_formula(attack, defense, spread)


static func calculate(attacker: CombatActor, target: CombatActor, rng: RandomNumberGenerator) -> int:
	if attacker == null or target == null:
		return 0
	return calculate_by_stats(attacker.get_attack(), target.get_defense(), rng)
