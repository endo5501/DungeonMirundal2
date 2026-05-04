extends GutTest

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
	_fighter_job.mage_school = false
	_fighter_job.priest_school = false
	_fighter_job.base_mp = 0
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0

# --- Registration ---

func test_register_character():
	var ch := _make_character("Hero")
	_guild.register(ch)
	assert_eq(_guild.get_all_characters().size(), 1)

func test_register_multiple_characters():
	_guild.register(_make_character("A"))
	_guild.register(_make_character("B"))
	_guild.register(_make_character("C"))
	assert_eq(_guild.get_all_characters().size(), 3)

# --- Removal ---

func test_remove_unassigned_character():
	var ch := _make_character("Hero")
	_guild.register(ch)
	var result := _guild.remove(ch)
	assert_true(result)
	assert_eq(_guild.get_all_characters().size(), 0)

func test_cannot_remove_party_assigned_character():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)  # front row, pos 0
	var result := _guild.remove(ch)
	assert_false(result)
	assert_eq(_guild.get_all_characters().size(), 1)

# --- Unassigned list ---

func test_all_characters_unassigned_initially():
	_guild.register(_make_character("A"))
	_guild.register(_make_character("B"))
	_guild.register(_make_character("C"))
	assert_eq(_guild.get_unassigned().size(), 3)

func test_some_characters_assigned():
	var a := _make_character("A")
	var b := _make_character("B")
	var c := _make_character("C")
	_guild.register(a)
	_guild.register(b)
	_guild.register(c)
	_guild.assign_to_party(a, 0, 0)
	assert_eq(_guild.get_unassigned().size(), 2)

# --- Party assignment ---

func test_assign_to_front_row():
	var ch := _make_character("Fighter1")
	_guild.register(ch)
	var result := _guild.assign_to_party(ch, 0, 0)
	assert_true(result)
	var pd := _guild.get_party_data()
	assert_not_null(pd.get_front_row()[0])
	assert_eq(pd.get_front_row()[0].member_name, "Fighter1")

func test_assign_to_back_row():
	var ch := _make_character("Caster1")
	_guild.register(ch)
	var result := _guild.assign_to_party(ch, 1, 2)
	assert_true(result)
	var pd := _guild.get_party_data()
	assert_not_null(pd.get_back_row()[2])
	assert_eq(pd.get_back_row()[2].member_name, "Caster1")

func test_cannot_assign_to_occupied_slot():
	var a := _make_character("A")
	var b := _make_character("B")
	_guild.register(a)
	_guild.register(b)
	_guild.assign_to_party(a, 0, 0)
	var result := _guild.assign_to_party(b, 0, 0)
	assert_false(result)

func test_cannot_assign_character_already_in_party():
	var ch := _make_character("A")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	var result := _guild.assign_to_party(ch, 0, 1)
	assert_false(result)

# --- Party removal ---

func test_remove_from_party_slot():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 1)
	_guild.remove_from_party(0, 1)
	var pd := _guild.get_party_data()
	assert_null(pd.get_front_row()[1])
	assert_eq(_guild.get_unassigned().size(), 1)

func test_remove_from_empty_slot_no_error():
	_guild.remove_from_party(0, 0)
	# Should not crash
	assert_true(true)

# --- PartyData generation ---

func test_full_party():
	var chars: Array[Character] = []
	for i in range(6):
		var ch := _make_character("Member%d" % i)
		_guild.register(ch)
		chars.append(ch)
	for i in range(3):
		_guild.assign_to_party(chars[i], 0, i)
	for i in range(3):
		_guild.assign_to_party(chars[i + 3], 1, i)
	var pd := _guild.get_party_data()
	for i in range(3):
		assert_not_null(pd.get_front_row()[i])
		assert_not_null(pd.get_back_row()[i])

func test_partial_party():
	var a := _make_character("A")
	var b := _make_character("B")
	_guild.register(a)
	_guild.register(b)
	_guild.assign_to_party(a, 0, 0)
	_guild.assign_to_party(b, 1, 1)
	var pd := _guild.get_party_data()
	assert_not_null(pd.get_front_row()[0])
	assert_null(pd.get_front_row()[1])
	assert_null(pd.get_front_row()[2])
	assert_null(pd.get_back_row()[0])
	assert_not_null(pd.get_back_row()[1])
	assert_null(pd.get_back_row()[2])

func test_empty_party():
	var pd := _guild.get_party_data()
	for i in range(3):
		assert_null(pd.get_front_row()[i])
		assert_null(pd.get_back_row()[i])


# --- combat-system: get_party_characters ---

func test_get_party_characters_returns_two_rows():
	var rows: Array = _guild.get_party_characters()
	assert_eq(rows.size(), 2)


func test_get_party_characters_rows_have_three_slots_each():
	var rows: Array = _guild.get_party_characters()
	assert_eq(rows[0].size(), 3)
	assert_eq(rows[1].size(), 3)


func test_get_party_characters_contains_assigned_members_and_nulls():
	var a := _make_character("A")
	var b := _make_character("B")
	_guild.register(a)
	_guild.register(b)
	_guild.assign_to_party(a, 0, 0)
	_guild.assign_to_party(b, 1, 1)
	var rows: Array = _guild.get_party_characters()
	assert_eq(rows[0][0], a)
	assert_null(rows[0][1])
	assert_null(rows[0][2])
	assert_null(rows[1][0])
	assert_eq(rows[1][1], b)
	assert_null(rows[1][2])


func test_get_party_characters_returns_duplicate_not_live_reference():
	var a := _make_character("A")
	_guild.register(a)
	_guild.assign_to_party(a, 0, 0)
	var rows: Array = _guild.get_party_characters()
	rows[0][0] = null
	# Original guild state unchanged
	assert_eq(_guild.get_character_at(0, 0), a)
