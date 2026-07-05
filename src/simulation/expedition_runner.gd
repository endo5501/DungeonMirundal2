class_name ExpeditionRunner
extends RefCounted

# Expedition loop (design D3). Stub — implemented in task 5.3.

const DEFAULT_TURN_LIMIT: int = 100


@warning_ignore("unused_parameter")
static func run_expedition(
	config: ExpeditionConfig,
	run_index: int,
	rng: RandomNumberGenerator,
	turn_limit: int = DEFAULT_TURN_LIMIT,
	monster_repo: MonsterRepository = null,
	spell_repo: SpellRepository = null,
) -> ExpeditionResult:
	return ExpeditionResult.new()
