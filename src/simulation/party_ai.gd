class_name PartyAi
extends RefCounted

# Stateless command-selection for PartyCombatant turns in simulation.


static func choose(
	member: PartyCombatant,
	ctx: PartyAiContext,
	config: PartyAiConfig,
	rng: RandomNumberGenerator,
) -> RefCounted:
	return null
