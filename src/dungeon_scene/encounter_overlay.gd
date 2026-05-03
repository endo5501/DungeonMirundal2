class_name EncounterOverlay
extends CanvasLayer

# Abstract base for encounter overlays. Concrete UI lives in subclasses
# (SimpleEncounterOverlay, CombatOverlay).

signal encounter_resolved(outcome: EncounterOutcome)

var _is_active: bool = false


func _init() -> void:
	layer = 10


func start_encounter(_party: MonsterParty) -> void:
	push_error("EncounterOverlay.start_encounter must be overridden")


func resolve() -> void:
	if not _is_active:
		return
	_is_active = false
	visible = false
	encounter_resolved.emit(EncounterOutcome.new(EncounterOutcome.Result.CLEARED))


func is_active() -> bool:
	return _is_active
