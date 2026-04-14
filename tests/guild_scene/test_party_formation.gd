extends GutTest

var _formation
var _guild: Guild
var _human: RaceData
var _fighter_job: JobData

func _make_character(char_name: String) -> Character:
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, _fighter_job, allocation)

func before_each():
	_guild = Guild.new()

	_human = RaceData.new()
	_human.race_name = "Human"
	_human.base_str = 8
	_human.base_int = 8
	_human.base_pie = 8
	_human.base_vit = 8
	_human.base_agi = 8
	_human.base_luc = 8

	_fighter_job = JobData.new()
	_fighter_job.job_name = "Fighter"
	_fighter_job.base_hp = 10
	_fighter_job.has_magic = false
	_fighter_job.base_mp = 0
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0

	_formation = PartyFormation.new()
	_formation.setup(_guild)
	add_child_autofree(_formation)

# --- Signals ---

func test_has_back_requested_signal():
	assert_has_signal(_formation, "back_requested")

# --- Party grid ---

func test_get_party_slots_returns_6():
	var slots = _formation.get_party_slots()
	assert_eq(slots.size(), 6)

func test_empty_party_all_null():
	var slots = _formation.get_party_slots()
	for slot in slots:
		assert_null(slot)

func test_party_slot_shows_assigned_character():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_not_null(slots[0])
	assert_eq(slots[0].character_name, "Hero")

# --- Waiting list ---

func test_get_waiting_characters_empty():
	assert_eq(_formation.get_waiting_characters().size(), 0)

func test_get_waiting_characters_with_unassigned():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_formation.refresh()
	assert_eq(_formation.get_waiting_characters().size(), 1)

# --- Add to party ---

func test_add_character_to_slot():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_formation.refresh()
	_formation.add_to_slot(0, 0, 0)  # row, position, waiting list index
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_not_null(slots[0])
	assert_eq(slots[0].character_name, "Hero")
	assert_eq(_formation.get_waiting_characters().size(), 0)

# --- Remove from party ---

func test_remove_from_slot():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	_formation.refresh()
	_formation.remove_from_slot(0, 0)
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_null(slots[0])
	assert_eq(_formation.get_waiting_characters().size(), 1)

# --- Party name ---

func test_default_party_name():
	assert_eq(_formation.get_party_name(), "")

func test_set_party_name():
	_formation.set_party_name("勇者たち")
	assert_eq(_formation.get_party_name(), "勇者たち")

# --- Back ---

# --- Party name persisted in Guild ---

func test_party_name_persists_across_instances():
	_formation.set_party_name("勇者たち")
	# Create a new PartyFormation with the same guild
	var formation2 = PartyFormation.new()
	formation2.setup(_guild)
	add_child_autofree(formation2)
	assert_eq(formation2.get_party_name(), "勇者たち")

# --- Back ---

func test_go_back_emits_signal():
	watch_signals(_formation)
	_formation.go_back()
	assert_signal_emitted(_formation, "back_requested")
