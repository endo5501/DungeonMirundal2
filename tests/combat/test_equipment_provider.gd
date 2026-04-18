extends GutTest


func test_base_class_is_refcounted():
	var provider := EquipmentProvider.new()
	assert_is(provider, RefCounted)


func test_base_class_has_get_attack_method():
	var provider := EquipmentProvider.new()
	assert_true(provider.has_method("get_attack"))


func test_base_class_has_get_defense_method():
	var provider := EquipmentProvider.new()
	assert_true(provider.has_method("get_defense"))


func test_base_class_has_get_agility_method():
	var provider := EquipmentProvider.new()
	assert_true(provider.has_method("get_agility"))


func test_base_class_methods_return_zero_by_default():
	var provider := EquipmentProvider.new()
	var dummy: Character = null
	assert_eq(provider.get_attack(dummy), 0)
	assert_eq(provider.get_defense(dummy), 0)
	assert_eq(provider.get_agility(dummy), 0)
