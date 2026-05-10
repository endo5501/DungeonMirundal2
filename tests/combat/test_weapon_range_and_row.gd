extends GutTest


func test_weapon_range_has_melee_and_ranged_constants():
	assert_eq(WeaponRange.MELEE, 0)
	assert_eq(WeaponRange.RANGED, 1)
	assert_ne(WeaponRange.MELEE, WeaponRange.RANGED)


func test_row_has_front_and_back_constants():
	assert_eq(Row.FRONT, 0)
	assert_eq(Row.BACK, 1)
	assert_ne(Row.FRONT, Row.BACK)
