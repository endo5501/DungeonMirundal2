class_name ExpeditionRunner
extends RefCounted

# Expedition loop (design D3): builds the party once through PartyFactory,
# then runs consecutive battles — PartyAi-selected commands through a fresh
# TurnEngine per battle, BattleResolver rewards and BetweenBattleHealer after
# each cleared battle — until the party wipes, max_battles battles have been
# entered, or a single battle exceeds the safety turn limit (STALLED).
#
# The SAME PartyCombatant instances are reused across battles: they proxy the
# persistent Characters, which is what makes HP/MP/status/exp carry over.
#
# Determinism (design D6): everything consumes the single injected rng, so an
# identical (config, run_index, rng seed) triple reproduces the expedition.

const DEFAULT_TURN_LIMIT: int = 100


# Runs one expedition and returns its ExpeditionResult, or null on fatal
# configuration problems (party factory errors, missing encounter table).
# `monster_repo` / `spell_repo` / `encounter_tables` are optional injection
# seams; the production path loads them through DataLoader when they are
# null / empty. A non-empty `encounter_tables` array REPLACES the disk set
# (no fallback), letting batch callers like the dashboard load the tables
# once instead of rescanning the directory every run.
static func run_expedition(
	config: ExpeditionConfig,
	run_index: int,
	rng: RandomNumberGenerator,
	turn_limit: int = DEFAULT_TURN_LIMIT,
	monster_repo: MonsterRepository = null,
	spell_repo: SpellRepository = null,
	encounter_tables: Array = [],
) -> ExpeditionResult:
	if config == null or rng == null:
		push_error("ExpeditionRunner: config and rng are required")
		return null
	var built := PartyFactory.build(config.party, rng)
	var factory_errors: Array = built["errors"]
	if not factory_errors.is_empty():
		for e in factory_errors:
			push_error("ExpeditionRunner: %s" % e)
		return null
	if monster_repo == null:
		monster_repo = MonsterRepository.new()
		monster_repo.register_all(DataLoader.new().load_all_monsters())
	if spell_repo == null:
		spell_repo = DataLoader.new().load_spell_repository()
	var status_repo := DataLoader.new().load_status_repository()
	var source := _build_encounter_source(config, monster_repo, encounter_tables)
	if source == null:
		return null
	var ai_config := _build_ai_config(config)
	var combatants: Array = built["combatants"]
	var characters: Array = built["characters"]

	var result := ExpeditionResult.new()
	result.characters = characters
	result.end_cause = "MAX_BATTLES"
	for battle_number in range(1, config.max_battles + 1):
		var monster_party := source.next(rng)
		if monster_party == null or monster_party.is_empty():
			# E.g. a fixed pattern whose species ids are all unknown. Running
			# instantly-CLEARED battles against nobody would silently corrupt
			# the metrics, so this is fatal — same contract as factory errors.
			push_error(
				"ExpeditionRunner: encounter source produced an empty encounter (battle %d, %s)"
				% [battle_number, source.describe()]
			)
			return null
		var engine := TurnEngine.new()
		engine.spell_repo = spell_repo
		engine.status_repo = status_repo
		engine.start_battle(combatants, _build_monster_combatants(monster_party))
		var turns := _run_battle(engine, ai_config, spell_repo, rng, turn_limit)
		var outcome_label := _outcome_label(engine)
		var hp_pct_before_heal: float
		if outcome_label == "CLEARED":
			# Rewards first: level-ups raise max (and current) HP/MP, and the
			# recorded pre-heal pct reflects that post-reward state.
			BattleResolver.resolve_rewards(engine, rng)
			hp_pct_before_heal = _party_hp_pct(characters)
			BetweenBattleHealer.heal_party(characters, spell_repo, rng)
		else:
			# WIPED / STALLED: no rewards and no healing, so the post-heal
			# columns record the same values as the pre-heal one.
			hp_pct_before_heal = _party_hp_pct(characters)
		result.battle_rows.append(_make_row(
			run_index, battle_number, source.describe(), turns,
			hp_pct_before_heal, characters, outcome_label,
		))
		_update_mp_exhaustion(result, characters, battle_number)
		if outcome_label != "CLEARED":
			result.end_cause = outcome_label
			break
	return result


# --- battle loop ---

# Runs one battle to completion (or to the turn limit) and returns the number
# of resolved turns. The engine stays in COMMAND_INPUT when the limit is hit.
static func _run_battle(
	engine: TurnEngine,
	ai_config: PartyAiConfig,
	spell_repo: SpellRepository,
	rng: RandomNumberGenerator,
	turn_limit: int,
) -> int:
	var turns := 0
	while engine.state == TurnEngine.State.COMMAND_INPUT and turns < turn_limit:
		var ctx := PartyAiContext.new(engine.party, engine.monsters, spell_repo, engine)
		for i in range(engine.party.size()):
			var member: PartyCombatant = engine.party[i]
			if member == null or not member.is_alive():
				continue
			engine.submit_command(i, PartyAi.choose(member, ctx, ai_config, rng))
		engine.resolve_turn(rng)
		turns += 1
	return turns


static func _build_monster_combatants(monster_party: MonsterParty) -> Array:
	var combatants: Array = []
	if monster_party == null:
		return combatants
	for m in monster_party.members:
		combatants.append(MonsterCombatant.new(m))
	return combatants


static func _outcome_label(engine: TurnEngine) -> String:
	if engine.state != TurnEngine.State.FINISHED:
		return "STALLED"
	var outcome := engine.outcome()
	if outcome != null and outcome.result == EncounterOutcome.Result.CLEARED:
		return "CLEARED"
	if outcome != null and outcome.result == EncounterOutcome.Result.WIPED:
		return "WIPED"
	# ESCAPED is unreachable (PartyAi never submits EscapeCommand); treat any
	# unexpected terminal state as STALLED so the expedition stops safely.
	return "STALLED"


# --- construction helpers ---

static func _build_encounter_source(
	config: ExpeditionConfig,
	monster_repo: MonsterRepository,
	encounter_tables: Array,
) -> EncounterSource:
	if config.encounter_mode == "fixed":
		return FixedPatternSource.new(config.encounter_patterns, monster_repo)
	if config.encounter_mode == "table":
		var table := _find_encounter_table(config.encounter_floor, encounter_tables)
		if table == null:
			push_error(
				"ExpeditionRunner: no encounter table for floor %d" % config.encounter_floor
			)
			return null
		return TableEncounterSource.new(table, monster_repo)
	push_error("ExpeditionRunner: unknown encounter mode '%s'" % config.encounter_mode)
	return null


# An empty `encounter_tables` means load-on-demand from disk (the pre-seam
# behavior); a non-empty array is authoritative, mirroring the monster_repo
# injection contract.
static func _find_encounter_table(floor_number: int, encounter_tables: Array) -> EncounterTableData:
	var tables := encounter_tables
	if tables.is_empty():
		tables = DataLoader.new().load_all_encounter_tables()
	for table in tables:
		if table is EncounterTableData and table.floor == floor_number:
			return table
	return null


static func _build_ai_config(config: ExpeditionConfig) -> PartyAiConfig:
	var ai_config := PartyAiConfig.new()
	ai_config.heal_hp_threshold = config.ai_heal_hp_threshold
	ai_config.attack_magic_min_enemies = config.ai_attack_magic_min_enemies
	ai_config.attack_magic_min_tier = config.ai_attack_magic_min_tier
	return ai_config


# --- metrics ---

static func _make_row(
	run_index: int,
	battle_number: int,
	encounter: String,
	turns: int,
	hp_pct_before_heal: float,
	characters: Array,
	outcome_label: String,
) -> Dictionary:
	return {
		"run": run_index,
		"battle": battle_number,
		"encounter": encounter,
		"turns": turns,
		"hp_pct_before_heal": hp_pct_before_heal,
		"party_hp_pct": _party_hp_pct(characters),
		"party_mp_pct": _party_mp_pct(characters),
		"deaths_cum": _count_dead(characters),
		"outcome": outcome_label,
	}


static func _party_hp_pct(characters: Array) -> float:
	var current := 0
	var maximum := 0
	for ch: Character in characters:
		current += ch.current_hp
		maximum += ch.max_hp
	if maximum <= 0:
		return 0.0
	return float(current) / float(maximum)


static func _party_mp_pct(characters: Array) -> float:
	var current := 0
	var maximum := 0
	for ch: Character in characters:
		current += ch.current_mp
		maximum += ch.max_mp
	if maximum <= 0:
		return 0.0
	return float(current) / float(maximum)


static func _count_dead(characters: Array) -> int:
	var dead := 0
	for ch: Character in characters:
		if ch.is_dead():
			dead += 1
	return dead


static func _update_mp_exhaustion(
	result: ExpeditionResult,
	characters: Array,
	battle_number: int,
) -> void:
	if result.mp_exhausted_battle != -1:
		return
	var current := 0
	var maximum := 0
	for ch: Character in characters:
		current += ch.current_mp
		maximum += ch.max_mp
	if maximum > 0 and current == 0:
		result.mp_exhausted_battle = battle_number
