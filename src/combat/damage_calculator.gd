class_name DamageCalculator
extends RefCounted

const SPREAD_MIN: int = 0
const SPREAD_MAX: int = 2

const BASE_HIT: float = 0.85
const AGI_K: float = 0.02
const AGI_CAP: float = 0.30
# BLIND_PENALTY is 0.0 in this change; a later change (add-status-effect-infrastructure)
# fills the real value via StatusData.
const BLIND_PENALTY: float = 0.0
const FINAL_HIT_MIN: float = 0.05
const FINAL_HIT_MAX: float = 0.99


static func apply_formula(attack: int, defense: int, spread: int) -> int:
	return maxi(1, attack - defense / 2 + spread)


static func calculate_by_stats(attack: int, defense: int, rng: RandomNumberGenerator) -> int:
	var spread := rng.randi_range(SPREAD_MIN, SPREAD_MAX)
	return apply_formula(attack, defense, spread)


static func hit_chance(attacker: CombatActor, target: CombatActor) -> float:
	if attacker == null or target == null:
		return 0.0
	var hit_mod: float = clampf(attacker.get_hit_modifier_total(), -CombatActor.MOD_CAP, CombatActor.MOD_CAP)
	var eva_mod: float = clampf(target.get_evasion_modifier_total(), -CombatActor.MOD_CAP, CombatActor.MOD_CAP)
	var agi_diff: int = attacker.get_agility() - target.get_agility()
	var agi_term: float = clampf(float(agi_diff) * AGI_K, -AGI_CAP, AGI_CAP)
	var blind_term: float = BLIND_PENALTY if attacker.has_blind_flag() else 0.0
	var raw: float = BASE_HIT + hit_mod - eva_mod + agi_term - blind_term
	return clampf(raw, FINAL_HIT_MIN, FINAL_HIT_MAX)


# Pure-roll helpers exposed for boundary testing without driving an RNG. The
# strict less-than rule for the hit roll is tied to `roll_hit` so test cases
# can verify it independent of any randomness source.
static func roll_hit(chance: float, randf_value: float) -> bool:
	return randf_value < chance


static func roll_damage(attacker: CombatActor, target: CombatActor, spread: int) -> int:
	if attacker == null or target == null:
		return 0
	return apply_formula(attacker.get_attack(), target.get_defense(), spread)


static func calculate(attacker: CombatActor, target: CombatActor, rng: RandomNumberGenerator) -> DamageResult:
	if attacker == null or target == null:
		return DamageResult.new(false, 0)
	var chance: float = hit_chance(attacker, target)
	var randf_value: float = rng.randf()
	if not roll_hit(chance, randf_value):
		return DamageResult.new(false, 0)
	var amount := calculate_by_stats(attacker.get_attack(), target.get_defense(), rng)
	return DamageResult.new(true, amount)
