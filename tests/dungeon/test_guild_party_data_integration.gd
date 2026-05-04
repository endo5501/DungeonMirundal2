extends GutTest

## Guild.get_party_data() が返す PartyData が
## 既存の PartyDisplay パイプラインと互換であることを確認する

func test_guild_party_data_is_compatible_with_party_display():
	var human := RaceData.new()
	human.race_name = "Human"
	human.base_str = 8
	human.base_int = 8
	human.base_pie = 8
	human.base_vit = 8
	human.base_agi = 8
	human.base_luc = 8

	var fighter := JobData.new()
	fighter.job_name = "Fighter"
	fighter.base_hp = 10
	fighter.mage_school = false
	fighter.priest_school = false
	fighter.base_mp = 0
	fighter.required_str = 0
	fighter.required_int = 0
	fighter.required_pie = 0
	fighter.required_vit = 0
	fighter.required_agi = 0
	fighter.required_luc = 0

	var guild := Guild.new()
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("TestHero", human, fighter, allocation)
	guild.register(ch)
	guild.assign_to_party(ch, 0, 0)

	var party_data := guild.get_party_data()

	# PartyData interface compatibility
	assert_true(party_data is PartyData)
	assert_eq(party_data.get_front_row().size(), 3)
	assert_eq(party_data.get_back_row().size(), 3)

	# First member has correct data
	var pmd: PartyMemberData = party_data.get_front_row()[0]
	assert_not_null(pmd)
	assert_eq(pmd.member_name, "TestHero")
	assert_eq(pmd.level, 1)
	assert_eq(pmd.max_hp, ch.max_hp)
	assert_eq(pmd.current_hp, ch.current_hp)

	# Other slots are null
	assert_null(party_data.get_front_row()[1])
	assert_null(party_data.get_front_row()[2])
