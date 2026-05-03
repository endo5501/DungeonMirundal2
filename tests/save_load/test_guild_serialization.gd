extends GutTest

func _make_character(name: String, race_id: String = "human", job_id: String = "fighter") -> Character:
	var race := load("res://data/races/" + race_id + ".tres") as RaceData
	var job := load("res://data/jobs/" + job_id + ".tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	return Character.create(name, race, job, allocation)

func test_to_dict_empty_guild():
	var guild := Guild.new()
	var d := guild.to_dict()
	assert_eq(d["characters"].size(), 0)
	assert_eq(d["party_name"], "")

func test_to_dict_with_characters():
	var guild := Guild.new()
	guild.register(_make_character("Alice"))
	guild.register(_make_character("Bob"))
	var d := guild.to_dict()
	assert_eq(d["characters"].size(), 2)
	assert_eq(d["characters"][0]["character_name"], "Alice")
	assert_eq(d["characters"][1]["character_name"], "Bob")

func test_to_dict_party_formation():
	var guild := Guild.new()
	var ch1 := _make_character("前衛1")
	var ch2 := _make_character("前衛2")
	guild.register(ch1)
	guild.register(ch2)
	guild.assign_to_party(ch1, 0, 0)
	guild.assign_to_party(ch2, 1, 2)
	var d := guild.to_dict()
	assert_eq(d["front_row"][0], 0)
	assert_eq(d["front_row"][1], null)
	assert_eq(d["front_row"][2], null)
	assert_eq(d["back_row"][0], null)
	assert_eq(d["back_row"][1], null)
	assert_eq(d["back_row"][2], 1)

func test_from_dict_empty():
	var d := {"characters": [], "front_row": [null, null, null], "back_row": [null, null, null], "party_name": ""}
	var guild := Guild.from_dict(d)
	assert_eq(guild.get_all_characters().size(), 0)
	assert_false(guild.has_party_members())

func test_from_dict_with_characters_and_party():
	var guild := Guild.new()
	var ch1 := _make_character("Alice")
	var ch2 := _make_character("Bob")
	guild.register(ch1)
	guild.register(ch2)
	guild.assign_to_party(ch1, 0, 1)
	var d := guild.to_dict()
	var restored := Guild.from_dict(d)
	assert_eq(restored.get_all_characters().size(), 2)
	assert_eq(restored.get_all_characters()[0].character_name, "Alice")
	assert_true(restored.has_party_members())
	assert_not_null(restored.get_character_at(0, 1))
	assert_eq(restored.get_character_at(0, 1).character_name, "Alice")

func test_roundtrip_preserves_party_name():
	var guild := Guild.new()
	guild.party_name = "勇者の一行"
	guild.register(_make_character("Hero"))
	var restored := Guild.from_dict(guild.to_dict())
	assert_eq(restored.party_name, "勇者の一行")

func test_from_dict_skips_broken_character_keeps_others():
	var alice := _make_character("Alice")
	var carol := _make_character("Carol")
	var d := {
		"characters": [
			alice.to_dict(),
			{"character_name": "Broken", "race_id": "bogus_race_xyz", "job_id": "fighter"},
			carol.to_dict(),
		],
		"front_row": [null, null, null],
		"back_row": [null, null, null],
		"party_name": "",
	}
	var restored := Guild.from_dict(d)
	# Skipped index produces no Character entry
	assert_eq(restored.get_all_characters().size(), 2)
	assert_eq(restored.get_all_characters()[0].character_name, "Alice")
	assert_eq(restored.get_all_characters()[1].character_name, "Carol")
	assert_push_warning("Broken character")

func test_from_dict_party_position_pointing_to_broken_character_is_left_empty():
	var alice := _make_character("Alice")
	var carol := _make_character("Carol")
	# Index 1 is broken; front_row[0] points at the broken index, front_row[1]
	# at Carol (index 2). Expect: front_row[0] empty, front_row[1] = Carol.
	var d := {
		"characters": [
			alice.to_dict(),
			{"character_name": "Broken", "race_id": "bogus_race_xyz", "job_id": "fighter"},
			carol.to_dict(),
		],
		"front_row": [1, 2, null],
		"back_row": [0, null, null],
		"party_name": "",
	}
	var restored := Guild.from_dict(d)
	# Position pointing at broken index stays null
	assert_null(restored.get_character_at(0, 0))
	# Position pointing at Carol resolves correctly
	assert_not_null(restored.get_character_at(0, 1))
	assert_eq(restored.get_character_at(0, 1).character_name, "Carol")
	# Back row: alice at index 0
	assert_not_null(restored.get_character_at(1, 0))
	assert_eq(restored.get_character_at(1, 0).character_name, "Alice")
	assert_push_warning("Broken character")

func test_from_dict_all_broken_returns_empty_guild():
	var d := {
		"characters": [
			{"character_name": "A", "race_id": "bogus_race_xyz", "job_id": "fighter"},
			{"character_name": "B", "race_id": "bogus_race_xyz", "job_id": "fighter"},
		],
		"front_row": [0, 1, null],
		"back_row": [null, null, null],
		"party_name": "",
	}
	var restored := Guild.from_dict(d)
	assert_eq(restored.get_all_characters().size(), 0)
	assert_false(restored.has_party_members())
