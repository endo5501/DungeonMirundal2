class_name SpellEffect
extends Resource


# Subclasses override this to compute outcomes per target. Default returns an empty
# SpellResolution so that calling .apply on a misconfigured spell is non-fatal.
func apply(_caster: CombatActor, _targets: Array, _spell_rng: SpellRng) -> SpellResolution:
	return SpellResolution.new()
