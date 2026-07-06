class_name DashboardRunner
extends RefCounted

# Pure orchestration for the balance dashboard (design D6).
# Red-phase stub: not implemented yet.

const HEATMAP_COLUMNS: PackedStringArray = []
const SWEEP_COLUMNS: PackedStringArray = []


static func sample_knob_values(_from_value: float, _to_value: float, _steps: int) -> Array:
	return []


static func apply_knob(_balance: Dictionary, _knob: String, _value: float) -> Dictionary:
	return {}


static func summarize_cell(_run_stats: Array) -> Dictionary:
	return {}


static func format_cells(_rows: Array, _columns: PackedStringArray) -> Array:
	return []


static func run_heatmap(
	_config: DashboardConfig,
	_monster_repo: MonsterRepository,
	_spell_repo: SpellRepository,
) -> Dictionary:
	return {}


static func run_sweep(
	_config: DashboardConfig,
	_balance: Dictionary,
	_base_monsters: Array,
	_spell_repo: SpellRepository,
) -> Dictionary:
	return {}
