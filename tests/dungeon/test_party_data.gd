extends GutTest

# --- PartyMemberData ---

func test_party_member_data_fields():
	var m = PartyMemberData.new("Warrior", 5, 120, 150, 30, 45)
	assert_eq(m.member_name, "Warrior")
	assert_eq(m.level, 5)
	assert_eq(m.current_hp, 120)
	assert_eq(m.max_hp, 150)
	assert_eq(m.current_mp, 30)
	assert_eq(m.max_mp, 45)

# --- PartyData ---

func test_party_with_full_rows():
	var front := [
		PartyMemberData.new("F1", 1, 10, 10, 5, 5),
		PartyMemberData.new("F2", 2, 20, 20, 10, 10),
		PartyMemberData.new("F3", 3, 30, 30, 15, 15),
	]
	var back := [
		PartyMemberData.new("B1", 1, 10, 10, 5, 5),
		PartyMemberData.new("B2", 2, 20, 20, 10, 10),
		PartyMemberData.new("B3", 3, 30, 30, 15, 15),
	]
	var pd = PartyData.new(front, back)
	assert_eq(pd.get_front_row().size(), 3)
	assert_eq(pd.get_back_row().size(), 3)
	assert_eq(pd.get_front_row()[0].member_name, "F1")
	assert_eq(pd.get_back_row()[2].member_name, "B3")

func test_party_with_partial_rows():
	var front := [
		PartyMemberData.new("F1", 1, 10, 10, 5, 5),
		PartyMemberData.new("F2", 2, 20, 20, 10, 10),
	]
	var back := [
		PartyMemberData.new("B1", 1, 10, 10, 5, 5),
	]
	var pd = PartyData.new(front, back)
	var fr = pd.get_front_row()
	var br = pd.get_back_row()
	assert_eq(fr.size(), 3)
	assert_eq(br.size(), 3)
	assert_eq(fr[0].member_name, "F1")
	assert_eq(fr[1].member_name, "F2")
	assert_null(fr[2])
	assert_eq(br[0].member_name, "B1")
	assert_null(br[1])
	assert_null(br[2])

func test_placeholder_has_six_members():
	var pd = PartyData.create_placeholder()
	var fr = pd.get_front_row()
	var br = pd.get_back_row()
	for i in range(3):
		assert_not_null(fr[i])
		assert_ne(fr[i].member_name, "")
		assert_gt(fr[i].max_hp, 0)
		assert_gt(fr[i].max_mp, 0)
	for i in range(3):
		assert_not_null(br[i])
		assert_ne(br[i].member_name, "")
		assert_gt(br[i].max_hp, 0)
		assert_gt(br[i].max_mp, 0)
